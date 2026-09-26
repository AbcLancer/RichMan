# -*- coding: utf-8 -*-
"""
fit_board_from_r6s.py —— 把**原版街区几何**对齐到**我们棋盘的格坐标**，量化「贴近原版」到什么程度。

数据来源（都可溯源）
--------------------
  1. 原版《地图制作的要求》（`samples/scene/japan/场景.txt`）：
     `R6_Bblock_AxB_i` 平面宽 = A×100、长 = B×100，**1 格 = 100 世界单位**，路线过地产格中心。
  2. `docs/orig-scene/<map>.json`（`tools/r6s_nodes.py`）：每块的 4×4 变换矩阵 + 世界平移。
  3. `docs/orig-logic/<map>/r6m_blocks.json`（`tools/r6m_blocks.py`）：`.r6m` 里的同一张表
     （含 A/B/序号），与 `.r6s` 逐一核对一致。
  4. `game/data/maps/<map>_tilepos.json`：我们棋盘 111 格的坐标（**美术空间**，
     当初由「小地图路线 + 美术锚点 + 样条重建」推得，不是原版原始路径）。

方法
----
  未知量是「世界 xz → 棋盘 xz」的**相似变换**（镜像 / 旋转 θ / 缩放 s / 平移 t）。
  对应关系未知（街区是 3 格纵深的平面，可走格只占其中一排），所以不用点对点配准，改用
  **引导曲线**：把 20 个街区心连成闭环折线（它贴着路线走，是路线的粗采样），
  目标函数 = 111 个棋盘格到这条折线距离的**截尾均值**（丢掉最差 10%，抗离群），
  在 (镜像 × θ × s) 上穷举 + 平移用质心对齐再局部精修。

⚠️ 已知的固有偏差（不是算法问题，是几何事实）
  - 街区心在路**两侧交替**（街区心折线是锯齿），所以它到路线的距离天然有
    约 `B/2×100` 世界单位 ≈ 1 格 —— 残差的**下界就是 1 格左右**。
  - 因此本工具的结论句式是「**偏差 ≈ x 格**」，不是「完美重合」。

产物
----
  docs/orig-scene/<map>_fit.json / .md / .svg
  game/data/maps/<map>_blocks_board.json
        每个街区在**棋盘坐标**下的四角 + 朝向角（以后摆地毯 / 定建筑朝向可直接用）

用法
----
  python tools/fit_board_from_r6s.py --map aiji
  python tools/fit_board_from_r6s.py --map aiji --fast
"""

import argparse
import json
import math
import os
import sys

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CELL = 100.0            # 1 格 = 100 世界单位（原版规范）
TRIM = 0.10             # 截尾比例


# ------------------------------------------------------------------ 载入

def load_blocks(path):
    doc = json.load(open(path, encoding="utf-8"))
    out = []
    for b in doc["blocks"]:
        if not b.get("matrix_found") or not b.get("matrix"):
            continue
        m = b["matrix"]
        rows = sorted((abs(m[r][1]), r) for r in range(3))     # |y| 最小的两行 = 水平轴
        h = sorted(r for _, r in rows[:2])
        out.append({
            "name": b["name"], "A": b["A"], "B": b["B"], "index": b["index"],
            "center": np.array([m[3][0], m[3][2]], dtype=np.float64),
            "axA": np.array([m[h[0]][0], m[h[0]][2]], dtype=np.float64),
            "axB": np.array([m[h[1]][0], m[h[1]][2]], dtype=np.float64),
            "hrows": h,
        })
    return doc, out


def build_cloud(blocks, swap=False):
    """A×B 全部格中心（世界 xz）。swap=True 交换 A/B 的轴归属。"""
    pts, meta = [], []
    for b in blocks:
        axA, axB = (b["axB"], b["axA"]) if swap else (b["axA"], b["axB"])
        A, B = b["A"], b["B"]
        for k in range(A):
            for j in range(B):
                p = (b["center"] + axA * ((k - (A - 1) / 2.0) * CELL)
                     + axB * ((j - (B - 1) / 2.0) * CELL))
                pts.append(p)
                meta.append({"block": b["name"], "k": k, "j": j, "A": A, "B": B})
    return np.asarray(pts, dtype=np.float64), meta


def load_tiles(path):
    doc = json.load(open(path, encoding="utf-8"))
    return doc, np.array([[t["x"], t["z"]] for t in doc["tiles"]], dtype=np.float64)


# ------------------------------------------------------------------ 几何

def rot(deg):
    a = math.radians(deg)
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, -s], [s, c]], dtype=np.float64)


def pt_poly_dist(P, Poly):
    """P:(n,2) 到闭环折线 Poly 的最短距离。"""
    A, B = Poly, np.roll(Poly, -1, axis=0)
    best = np.full(len(P), 1e18)
    for i in range(len(A)):
        ab = B[i] - A[i]
        t = np.clip(((P - A[i]) @ ab) / max(ab @ ab, 1e-12), 0.0, 1.0)
        best = np.minimum(best, np.linalg.norm(P - (A[i] + t[:, None] * ab), axis=1))
    return best


def trimmed(d, frac=TRIM):
    d = np.sort(d)
    n = max(1, int(len(d) * (1.0 - frac)))
    return float(d[:n].mean())


def score(T, guide, s, deg, mirror, t):
    Q = guide.copy()
    if mirror:
        Q = Q * np.array([-1.0, 1.0])
    Q = s * (Q @ rot(deg).T) + t
    return trimmed(pt_poly_dist(T, Q))


# ------------------------------------------------------------------ 主流程

def fit(mapname, fast=False):
    ndoc, blocks = load_blocks(os.path.join(ROOT, "docs", "orig-scene", mapname + ".json"))
    tdoc, T = load_tiles(os.path.join(ROOT, "game", "data", "maps", mapname + "_tilepos.json"))
    step = float(np.mean([np.linalg.norm(T[i + 1] - T[i]) for i in range(len(T) - 1)]))

    guide = np.array([b["center"] for b in blocks])
    grg = math.sqrt(float(((guide - guide.mean(0)) ** 2).sum(1).mean()))
    trg = math.sqrt(float(((T - T.mean(0)) ** 2).sum(1).mean()))
    s0 = trg / grg
    print("[fit] %s：街区 %d，引导折线长 %.0f，棋盘 %d 格（步距 %.3f），Rg 比 s0=%.5f"
          % (mapname, len(blocks), sum(np.linalg.norm(np.roll(guide, -1, axis=0)[i] - guide[i])
                                       for i in range(len(guide))), len(T), step, s0))

    # ---- 1) 粗搜 (镜像 × θ × s)，平移先用质心对齐 ----
    s_list = np.linspace(s0 * 0.75, s0 * 1.35, 9 if fast else 31)
    th_list = np.arange(0.0, 360.0, 10.0 if fast else 2.0)
    t0base = T.mean(0) - (guide.mean(0) * s0)
    best = None
    for mirror in (False, True):
        for deg in th_list:
            R = rot(deg)
            for s in s_list:
                Qg = guide * np.array([-1.0, 1.0]) if mirror else guide
                Q = s * (Qg @ R.T)
                t = T.mean(0) - Q.mean(0)
                v = score(T, guide, s, deg, mirror, t)
                if best is None or v < best[0]:
                    best = (v, mirror, float(deg), float(s), t)
    v, mirror, deg, s, t = best
    print("[fit] 粗搜: 截尾均值 %.3f 棋盘单位 = %.3f 格  (θ=%.1f° s=%.5f 镜像=%s)"
          % (v, v / step, deg, s, "是" if mirror else "否"))

    # ---- 2) 平移局部精修 + θ/s 细搜 ----
    step_t = step * 0.5
    for _ in range(2):
        improved = True
        while improved:
            improved = False
            for dx in (-step_t, 0.0, step_t):
                for dz in (-step_t, 0.0, step_t):
                    tt = t + np.array([dx, dz])
                    vv = score(T, guide, s, deg, mirror, tt)
                    if vv < v - 1e-6:
                        v, t, improved = vv, tt, True
        for dd in (-2.0, -1.0, -0.5, 0.5, 1.0, 2.0):
            vv = score(T, guide, s, deg + dd, mirror, t)
            if vv < v - 1e-6:
                v, deg = vv, deg + dd
        for k in (0.99, 0.995, 1.005, 1.01):
            vv = score(T, guide, s * k, deg, mirror, t)
            if vv < v - 1e-6:
                v, s = vv, s * k
        step_t *= 0.5
    print("[fit] 精修: 截尾均值 %.3f = %.3f 格  (θ=%.2f° s=%.6f t=(%.2f,%.2f))"
          % (v, v / step, deg, s, t[0], t[1]))

    # ---- 3) 残差与逐格明细 ----
    S_all, meta = build_cloud(blocks)
    Qg = S_all * np.array([-1.0, 1.0]) if mirror else S_all
    S2 = s * (Qg @ rot(deg).T) + t
    Qguide = guide.copy()
    if mirror:
        Qguide = Qguide * np.array([-1.0, 1.0])
    G2 = s * (Qguide @ rot(deg).T) + t

    d = pt_poly_dist(T, G2)
    # 靶点 → 最近原版格中心（另一种可读口径）
    dn = np.linalg.norm(T[:, None, :] - S2[None, :, :], axis=2)
    jn = dn.argmin(1)
    dnn = dn[np.arange(len(T)), jn]

    blocks_board = []
    for b in blocks:
        axA = b["axA"] * (-1.0 if mirror else 1.0)
        axB = b["axB"] * (-1.0 if mirror else 1.0)
        c = s * (rot(deg) @ b["center"]) + t
        wa = s * (rot(deg) @ axA) * (b["A"] * CELL * 0.5)
        wb = s * (rot(deg) @ axB) * (b["B"] * CELL * 0.5)
        corners = [c - wa - wb, c + wa - wb, c + wa + wb, c - wa + wb]
        blocks_board.append({
            "name": b["name"], "A": b["A"], "B": b["B"],
            "center": [round(float(c[0]), 3), round(float(c[1]), 3)],
            "corners": [[round(float(p[0]), 3), round(float(p[1]), 3)] for p in corners],
            "facing_deg": round(math.degrees(math.atan2(float(wa[1]), float(wa[0]))) % 180.0, 2),
            "half": [round(float(np.linalg.norm(wa)), 3), round(float(np.linalg.norm(wb)), 3)],
        })

    return {
        "map": mapname, "mirror": mirror, "theta_deg": deg, "s": s,
        "t": [float(t[0]), float(t[1])], "step": step,
        "world_per_tile": step / s,
        "resid_trim": v, "resid_trim_tiles": v / step,
        "resid_median_tiles": float(np.median(d) / step),
        "resid_p90_tiles": float(np.quantile(d, 0.9) / step),
        "resid_max_tiles": float(d.max() / step),
        "nn_median_tiles": float(np.median(dnn) / step),
        "nn_p90_tiles": float(np.quantile(dnn, 0.9) / step),
        "n_tiles": len(T), "n_blocks": len(blocks), "n_cells": len(S_all),
        "blocks_board": blocks_board,
        "per_tile": [{"i": i, "d_guide": round(float(d[i] / step), 3),
                      "d_cell": round(float(dnn[i] / step), 3),
                      "block": meta[jn[i]]["block"]} for i in range(len(T))],
        "_S2": S2, "_T": T, "_G2": G2,
    }


# ------------------------------------------------------------------ 输出

def write_blocks_board(F):
    out = {
        "_comment": "原版地产块在**棋盘坐标**下的位置（由 tools/fit_board_from_r6s.py 拟合而来）",
        "_method": "世界 xz → 棋盘 xz 相似变换（镜像/旋转/缩放/平移），见 <map>_fit.json",
        "_fit": {"mirror": F["mirror"], "theta_deg": F["theta_deg"], "s": F["s"],
                 "t": F["t"]},
        "_note": "用于对照：街区几格宽、朝哪边、压在哪几格上；未接入游戏逻辑。",
        "map": F["map"], "blocks": F["blocks_board"],
    }
    p = os.path.join(ROOT, "game", "data", "maps", F["map"] + "_blocks_board.json")
    json.dump(out, open(p, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print("[fit] → %s" % p)


def write_report(F, outdir):
    m = F["map"]
    dump = {k: v for k, v in F.items() if not k.startswith("_")}
    json.dump(dump, open(os.path.join(outdir, m + "_fit.json"), "w", encoding="utf-8"),
              ensure_ascii=False, indent=1)
    L = ["# %s —— 「原版几何 ↔ 棋盘坐标」对齐报告" % m, "",
         "把 `docs/orig-scene/%s.json`（`.r6s` 的 %d 个地产块，1 格 = 100 世界单位）"
         "经**相似变换**投到" % (m, F["n_blocks"]),
         "`game/data/maps/%s_tilepos.json`（棋盘 %d 格，美术空间）上，"
         "用「棋盘格 → 街区心折线」的**截尾均值**做目标。" % (m, F["n_tiles"]), "",
         "## 拟合结果", "",
         "| 项 | 值 |", "|---|---|",
         "| 镜像 | %s |" % ("是" if F["mirror"] else "否"),
         "| 旋转 θ | %.2f° |" % F["theta_deg"],
         "| 缩放 s | %.6f（棋盘单位 / 世界单位） |" % F["s"],
         "| 平移 t | (%.2f, %.2f) |" % tuple(F["t"]),
         "| **反推的原版格距** | 棋盘一格 %.3f ↔ **%.0f 世界单位**（规范里 1 格 = 100） |"
         % (F["step"], F["world_per_tile"]),
         "", "## 残差（单位：棋盘格距 %.3f）" % F["step"], "",
         "| 口径 | 中位 | 90 分位 | 最大 |", "|---|---|---|---|",
         "| 棋盘格 → 街区心折线 | %.2f 格 | %.2f 格 | %.2f 格 |"
         % (F["resid_median_tiles"], F["resid_p90_tiles"], F["resid_max_tiles"]),
         "| 棋盘格 → 最近原版格中心 | %.2f 格 | %.2f 格 | — |"
         % (F["nn_median_tiles"], F["nn_p90_tiles"]), "",
         "> **怎么读**：街区心本来就偏离路线约 `B/2×100` 世界单位（≈1 格），",
         "> 所以「中位 ~1 格」= **形状基本吻合、无明显系统性错位**；",
         "> 90 分位/最大值反映美术（小地图/`ditu`）与原版 3D 局部的出入。", "",
         "## 残差最大的 12 格（可以拿来逐格微调）", "",
         "| 格号 | 到折线(格) | 到最近原版格(格) | 最近街区 |", "|---|---|---|---|"]
    for r in sorted(F["per_tile"], key=lambda r: -r["d_guide"])[:12]:
        L.append("| %d | %.2f | %.2f | `%s` |"
                 % (r["i"], r["d_guide"], r["d_cell"], r["block"]))
    L += ["", "## 原版街区在棋盘坐标下的位置", "",
          "| 街区 | A×B | 中心 | 朝向° | 半宽/半长 |", "|---|---|---|---|---|"]
    for b in F["blocks_board"]:
        L.append("| `%s` | %dx%d | (%.1f, %.1f) | %.1f | %.2f / %.2f |"
                 % (b["name"], b["A"], b["B"], b["center"][0], b["center"][1],
                    b["facing_deg"], b["half"][0], b["half"][1]))
    L += ["", "> 生成脚本：`tools/fit_board_from_r6s.py`（可重跑覆盖）。",
          "> ⚠️ 本报告**只做验证与对照**，没有改动 `%s_tilepos.json`。" % m, ""]
    open(os.path.join(outdir, m + "_fit.md"), "w", encoding="utf-8", newline="").write("\n".join(L))
    print("[fit] → %s" % os.path.join(outdir, m + "_fit.md"))


def write_svg(F, outdir):
    step = F["step"]
    pal = ["#d64545", "#2f6fd0", "#2f9e5e", "#8a5cd6", "#c98a1b", "#0f9ba8"]
    pts = np.vstack([F["_S2"], F["_T"]])
    lo, hi = pts.min(0), pts.max(0)
    pad = 0.06 * float((hi - lo).max())
    lo, hi = lo - pad, hi + pad
    W = 880
    sc = (W - 40) / float((hi - lo).max())
    H = int((hi[1] - lo[1]) * sc) + 52

    def px(p):
        return (20 + (p[0] - lo[0]) * sc, 30 + (p[1] - lo[1]) * sc)

    o = ["<svg xmlns='http://www.w3.org/2000/svg' width='%d' height='%d' viewBox='0 0 %d %d'"
         " font-family='Segoe UI,Microsoft YaHei,sans-serif'>" % (W, H, W, H),
         "<rect width='%d' height='%d' fill='#f7f8fa'/>" % (W, H)]
    for bi, b in enumerate(F["blocks_board"]):
        c = [(px(p)[0], px(p)[1]) for p in b["corners"]]
        d = "M" + " L".join("%.1f,%.1f" % q for q in c) + " Z"
        o.append("<path d='%s' fill='none' stroke='%s' stroke-width='1.2' stroke-opacity='0.75'/>"
                 % (d, pal[bi % len(pal)]))
    for p in F["_S2"]:
        x, y = px(p)
        o.append("<circle cx='%.1f' cy='%.1f' r='1.9' fill='#e08b8b' fill-opacity='0.8'/>" % (x, y))
    Tr = np.vstack([F["_T"], F["_T"][:1]])
    o.append("<path d='M" + " L".join("%.1f,%.1f" % px(p) for p in Tr)
             + "' fill='none' stroke='#1b5fc4' stroke-width='2.2'/>")
    for i, p in enumerate(F["_T"]):
        x, y = px(p)
        o.append("<circle cx='%.1f' cy='%.1f' r='3.0' fill='#1b5fc4'/>" % (x, y))
    o.append("<text x='20' y='18' font-size='12.5' fill='#222'>"
             "蓝线+蓝点 = 我们棋盘 %d 格 ｜ 红点 = 原版街区格中心 %d 个 ｜ "
             "彩框 = 20 个街区（棋盘坐标） ｜ s=%.5f θ=%.2f° 镜像=%s ｜ "
             "残差 中位 %.2f 格 / 90%% %.2f 格</text>"
             % (F["n_tiles"], F["n_cells"], F["s"], F["theta_deg"],
                "是" if F["mirror"] else "否", F["resid_median_tiles"], F["resid_p90_tiles"]))
    o.append("</svg>")
    p = os.path.join(outdir, F["map"] + "_fit.svg")
    open(p, "w", encoding="utf-8", newline="").write("\n".join(o))
    print("[fit] → %s" % p)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--map", default="aiji")
    ap.add_argument("--out", default=os.path.join(ROOT, "docs", "orig-scene"))
    ap.add_argument("--fast", action="store_true")
    a = ap.parse_args()
    F = fit(a.map, fast=a.fast)
    outdir = os.path.abspath(a.out)
    os.makedirs(outdir, exist_ok=True)
    write_report(F, outdir)
    write_svg(F, outdir)
    write_blocks_board(F)


if __name__ == "__main__":
    main()
