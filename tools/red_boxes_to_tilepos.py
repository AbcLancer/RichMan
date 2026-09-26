# -*- coding: utf-8 -*-
"""
red_boxes_to_tilepos.py —— 用原版编辑器贴图里的 **50 个红框** 校准棋盘的「步距 / 格数」。

背景
----
`ditu2_1024.tga` 是**编辑器版**棋盘贴图（与游戏实际用的 `ditu.tga` **不是同一张图**，
与 `ditu_noshadow.tga` 同框），上面用纯红矩形标出 **50 个地产槽位**。

实测：红框中心间距中位 **≈30.0 px**（36 个间距落在 28.6~33.0 px，非常一致）。
而我们的 `aiji_tilepos.json` 是等弧长重采样，步距 **25.0 px**、共 **111 格**、
环长 **2769.5 px**。两者环长几乎相同（说明走的是同一条路），
但**我们明显偏密**：按红框步距折算，环上应只有 **≈92 格**；
`.r6m` 街区表给的地产格数 ΣA = **94**（不含起点/事件点等非地产格）。

本脚本**不改生产数据**，只产出候选：
    game/data/maps/aiji_tilepos_red.json   ← 候选棋盘坐标（不覆盖 aiji_tilepos.json）
    docs/orig-scene/aiji_red_boxes.{json,md,png}

用法
----
  python tools/red_boxes_to_tilepos.py                 # N 自动 = 环长 / 红框步距
  python tools/red_boxes_to_tilepos.py --n 94
"""

import argparse
import json
import os
import sys

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
MAPDIR = os.path.join(ROOT, "game", "data", "maps")
DOCS = os.path.join(ROOT, "docs", "orig-scene")
TGA = os.path.join(ROOT, "samples", "scene", "aiji", "ditu2_1024.tga")
R6M_SUM_A = 94          # docs/orig-logic/aiji/r6m_blocks.json：20 个街区的 A 值之和


# ------------------------------------------------------------------ 载入

def load_plots(mapname="aiji"):
    """50 个红框中心：u,v 是**中心**的归一化贴图坐标（v 已翻正）。"""
    doc = json.load(open(os.path.join(MAPDIR, mapname + "_plots_uv.json"), encoding="utf-8"))
    W, H = doc["_image_size"]
    pts = [{"j": k, "u": q["u"], "v": q["v"], "w": q["w"], "h": q["h"],
            "px": q["u"] * W, "py": (1.0 - q["v"]) * H}
           for k, q in enumerate(doc["plots"])]
    return doc, np.array([[q["px"], q["py"]] for q in pts], dtype=np.float64), pts


def load_tiles(mapname="aiji"):
    doc = json.load(open(os.path.join(MAPDIR, mapname + "_tilepos.json"), encoding="utf-8"))
    T = np.array([[t["px"], t["py"]] for t in doc["tiles"]], dtype=np.float64)
    return doc, T


def fit_px_to_board(tdoc, T):
    X = np.array([t["x"] for t in tdoc["tiles"]], dtype=np.float64)
    Z = np.array([t["z"] for t in tdoc["tiles"]], dtype=np.float64)
    ax, bx = np.polyfit(T[:, 0], X, 1)
    az, bz = np.polyfit(T[:, 1], Z, 1)
    rx = float(np.abs(X - (ax * T[:, 0] + bx)).max())
    rz = float(np.abs(Z - (az * T[:, 1] + bz)).max())
    return (ax, bx), (az, bz), rx, rz


# ------------------------------------------------------------------ 几何

def closed_segments(P):
    return P, np.roll(P, -1, axis=0)


def poly_len(P):
    A, B = closed_segments(P)
    return float(np.linalg.norm(B - A, axis=1).sum())


def spacing_stats(P):
    A, B = closed_segments(P)
    seg = np.linalg.norm(B - A, axis=1)
    return {"min": float(seg.min()), "max": float(seg.max()), "mean": float(seg.mean()),
            "median": float(np.median(seg)), "total": float(seg.sum())}


def project_s(P, Q):
    """把 Q 里每个点投到闭环折线 P 上，返回 (弧长参数 s, 距离 d, 总长)。"""
    A, B = closed_segments(P)
    seg = np.linalg.norm(B - A, axis=1)
    cum = np.concatenate([[0.0], np.cumsum(seg)])
    s = np.zeros(len(Q))
    d = np.full(len(Q), 1e18)
    for i in range(len(A)):
        ab = B[i] - A[i]
        t = np.clip(((Q - A[i]) @ ab) / max(float(ab @ ab), 1e-12), 0.0, 1.0)
        dd = np.linalg.norm(Q - (A[i] + t[:, None] * ab), axis=1)
        upd = dd < d
        s[upd] = cum[i] + t[upd] * seg[i]
        d[upd] = dd[upd]
    return s, d, float(cum[-1])


def resample_closed(P, n):
    A, B = closed_segments(P)
    seg = np.linalg.norm(B - A, axis=1)
    cum = np.concatenate([[0.0], np.cumsum(seg)])
    total = float(cum[-1])
    out = np.zeros((n, 2))
    for k, s in enumerate(np.linspace(0.0, total, n, endpoint=False)):
        i = max(0, min(int(np.searchsorted(cum, s, side="right") - 1), len(seg) - 1))
        f = (s - cum[i]) / max(seg[i], 1e-12)
        out[k] = A[i] + f * (B[i] - A[i])
    return out, total


# ------------------------------------------------------------------ 主流程

def run(mapname, n=None):
    pdoc, P, plots = load_plots(mapname)
    tdoc, T = load_tiles(mapname)
    (ax, bx), (az, bz), rx, rz = fit_px_to_board(tdoc, T)

    st_T, st_P = spacing_stats(T), spacing_stats(P)
    sP, dP, _ = project_s(T, P)              # 红框投到生产环线上 → 得到沿环顺序
    Po = P[np.argsort(sP, kind="stable")]
    gaps = np.linalg.norm(np.roll(Po, -1, axis=0) - Po, axis=1)
    med = float(np.median(gaps))
    # 红框分 10 组（组之间有断口），组内间距才是「一格」
    within = gaps[gaps <= 3.0 * med]
    n_groups = int((gaps > 3.0 * med).sum()) + 1 if len(gaps) else 0

    print("[red] 生产棋盘 %d 格 · 步距 中位 %.2f px · 环长 %.1f px"
          % (len(T), st_T["median"], st_T["total"]))
    print("[red] 原版红框 %d 框 · **组内间距** 中位 %.2f px（%d 个，范围 %.1f~%.1f）· %d 组"
          % (len(P), med, len(within), within.min(), within.max(), n_groups))
    print("[red] px→棋盘 映射 x=%.6f*px%+.3f（残差 %.4f）| z=%.6f*py%+.3f（残差 %.4f）"
          % (ax, bx, rx, az, bz, rz))
    print("[red] 三个「环上应有多少格」的估计：")
    print("        · 生产环长 / 红框间距 = %.1f / %.2f = **%.1f 格**"
          % (st_T["total"], med, st_T["total"] / med))
    print("        · 红框组内总长 / 红框间距 = %.1f / %.2f = **%.1f 格**"
          % (within.sum(), med, within.sum() / med))
    print("        · `.r6m` 街区表 ΣA（只算地产格）= **%d 格**" % R6M_SUM_A)

    if n is None:
        n = int(round(st_T["total"] / med))
    print("[red] 采用 N = %d 格（--n 可覆盖）" % n)

    TA, total_A = resample_closed(T, n)
    print("[red] 候选：环长 %.1f px · 步距 %.2f px（原步距 %.2f）"
          % (total_A, total_A / n, st_T["median"]))

    # 候选格 与 50 红框 的最近距离
    dbox = np.linalg.norm(P[:, None, :] - TA[None, :, :], axis=2).min(1)
    print("[red] 红框 → 最近候选格：中位 %.2f / 90%% %.2f / 最大 %.2f px（= %.2f 格 中位）"
          % (np.median(dbox), np.quantile(dbox, 0.9), dbox.max(),
             float(np.median(dbox)) / st_T["median"]))

    return {"map": mapname, "n": n, "T": T, "TA": TA, "P": P, "plots": plots,
            "px2x": [float(ax), float(bx)], "py2z": [float(az), float(bz)],
            "st_T": st_T, "st_P": st_P, "gap_med": med, "gap_within_n": int(len(within)),
            "gap_within_sum": float(within.sum()), "n_groups": n_groups,
            "n_est_prod": float(st_T["total"] / med),
            "n_est_within": float(within.sum() / med),
            "n_est_r6m": R6M_SUM_A, "total_A": total_A,
            "box_fit": [float(np.median(dbox)), float(np.quantile(dbox, 0.9)), float(dbox.max())]}


# ------------------------------------------------------------------ 输出

def write_candidate(F):
    n, (ax, bx), (az, bz) = F["n"], F["px2x"], F["py2z"]
    tiles = [{"i": i, "px": round(float(px), 1), "py": round(float(py), 1),
              "u": round(float(px) / 1024.0, 6), "v": round(1.0 - float(py) / 1024.0, 6),
              "x": round(float(ax * px + bx), 4), "z": round(float(az * py + bz), 4)}
             for i, (px, py) in enumerate(F["TA"])]
    out = {
        "_comment": "【候选·未启用】用原版 50 个红框校准步距/格数后的棋盘坐标",
        "_generated_by": "tools/red_boxes_to_tilepos.py",
        "_why": ("原版红框的**组内间距**中位 %.2f px，而生产 aiji_tilepos.json 是 25.0 px / "
                 "111 格。两者环长几乎相同（%.0f vs %.0f px），说明走同一条路但**我们偏密**。"
                 % (F["gap_med"], F["st_T"]["total"], F["st_P"]["total"])),
        "_method": ("沿**已验证的生产环线**等弧长重采样成 %d 格（形状不变，只改密度）；"
                    "px→棋盘坐标沿用生产数据的线性映射 x=%.6f*px%+.3f、z=%.6f*py%+.3f。"
                    % (n, ax, bx, az, bz)),
        "_evidence": {
            "red_box_count": len(F["plots"]),
            "red_box_gap_median_px": round(F["gap_med"], 2),
            "red_box_gap_within_count": F["gap_within_n"],
            "red_box_chain_within_len_px": round(F["gap_within_sum"], 1),
            "n_estimate_by_prod_len": round(F["n_est_prod"], 1),
            "n_estimate_by_within_len": round(F["n_est_within"], 1),
            "n_estimate_by_r6m_sum_A": F["n_est_r6m"],
            "prod_tiles": len(F["T"]),
            "prod_step_px": round(F["st_T"]["median"], 2),
            "prod_loop_len_px": round(F["st_T"]["total"], 1),
        },
        "_note": ("⚠️ 候选文件，游戏加载路径仍指向 aiji_tilepos.json。"
                  "「原版到底几格」三个估计值为 %.0f / %.0f / %d，**需老板拍板**"
                  "（docs/decision-log.md 议题 34-A）。改格数会同时影响每格坐标、"
                  "建筑落点与绕一圈的步数（游戏时长）。"
                  % (F["n_est_prod"], F["n_est_within"], F["n_est_r6m"])),
        "_image_size": [1024, 1024], "_board_size": 200.0,
        "count": n, "tiles": tiles,
    }
    p = os.path.join(MAPDIR, F["map"] + "_tilepos_red.json")
    json.dump(out, open(p, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print("[red] → %s" % p)


def write_report(F):
    m, n = F["map"], F["n"]
    sT, sP = F["st_T"], F["st_P"]
    bf = F["box_fit"]
    os.makedirs(DOCS, exist_ok=True)
    json.dump({k: v for k, v in F.items() if k not in ("T", "TA", "P", "plots")},
              open(os.path.join(DOCS, m + "_red_boxes.json"), "w", encoding="utf-8"),
              ensure_ascii=False, indent=1)
    L = ["# aiji —— 用原版红框校准棋盘「步距 / 格数」（候选）", "",
         "## 一句话", "",
         ("原版编辑器贴图 `ditu2_1024.tga` 上 50 个红框的**组内间距**中位 **%.2f px**，"
          "而我们的棋盘步距 **%.2f px**（环长 **%.0f px**）"
          "—— **走的是同一条路，但我们的格子偏密**。"
          % (F["gap_med"], sT["median"], sT["total"])), "",
         "## 两套数据对照", "",
         "| 量 | 生产 `aiji_tilepos.json` | 原版红框 |", "|---|---|---|",
         "| 数量 | **%d 格** | **%d 框** |" % (len(F["T"]), len(F["plots"])),
         "| 步距 / 组内间距 中位 | **%.2f px** | **%.2f px**（组内 %d 个） |"
         % (sT["median"], F["gap_med"], F["gap_within_n"]),
         "| 环长 | **%.0f px** | 红框组内合计 %.0f px（另有组间断口不计） |"
         % (sT["total"], F["gap_within_sum"]),
         "| 分组 | 1 个闭环 | %d 组（组间有断口） |" % F["n_groups"], "",
         "## 「原版到底几格」—— 三个独立估计", "",
         "| 估计方法 | 值 |", "|---|---|",
         "| 生产环长 ÷ 红框间距 | **%.1f 格** |" % F["n_est_prod"],
         "| `.r6m` 街区表 ΣA（**只算地产格**） | **%d 格** |" % F["n_est_r6m"],
         "| （参考）红框组内总长 ÷ 红框间距 | %.1f 格（只覆盖有框的段落，不作总数） |"
         % F["n_est_within"], "",
         ("**关键两个数落在 %.1f ~ %d。** ΣA 只算「地产」格，不含起点 / 事件点 / 医院 / 新闻等，"
          "所以**真实总格数应当 ≥ %d**；红框给的 %.1f 略低 —— 说明红框间距略大于真实一格，"
          "或生产环长略被低估。**这个区间需要老板拍板（议题 34-A）。**"
          % (F["n_est_prod"], F["n_est_r6m"], F["n_est_r6m"], F["n_est_prod"])), "",
         "## 候选怎么造的", "",
         ("沿**已验证的平滑环线**（生产 %d 格折线；它已被 `.r6s` 相似变换拟合验证——"
          "θ=1.00°、中位残差 0.73 格）**等弧长重采样成 %d 格**：形状一个点都不改，只把密度调稀。"
          % (len(F["T"]), n)), "",
         "## 候选格 与 50 个红框 的贴合度", "",
         "| 口径 | 中位 | 90 分位 | 最大 |", "|---|---|---|---|",
         "| 红框中心 → 最近候选格 | %.2f px | %.2f px | %.2f px |" % tuple(bf),
         "| 折算成格 | **%.2f 格** | %.2f 格 | %.2f 格 |"
         % (bf[0] / sT["median"], bf[1] / sT["median"], bf[2] / sT["median"]), "",
         ("（红框是**槽位标注**、候选格是**路线采样点**，两者本来就不会一一重合 —— "
          "红框画在槽位中心、格点走在路上，中位 %.2f px 属正常。）" % bf[0]), "",
         "## 产物", "",
         "| 文件 | 内容 |", "|---|---|",
         "| `game/data/maps/%s_tilepos_red.json` | %d 格候选坐标（`i/px/py/u/v/x/z`） |" % (m, n),
         "| `docs/orig-scene/%s_red_boxes.json` | 机器可读版 |" % m,
         "| `docs/orig-scene/%s_red_boxes.png` | 叠在 `ditu2_1024.tga` 上的可视化 |" % m, "",
         "> 生成脚本：`tools/red_boxes_to_tilepos.py`（可重跑覆盖）。",
         "> ⚠️ 本报告**只做验证与对照**，没有改动 `%s_tilepos.json`（仍 %d 格）。" % (m, len(F["T"])),
         "> ⚠️ 判断「路在哪」请用 `ditu.tga`，**不要用 `ditu2_1024`**（见附录 C）。", ""]
    open(os.path.join(DOCS, m + "_red_boxes.md"), "w", encoding="utf-8", newline="").write("\n".join(L))
    print("[red] → %s" % os.path.join(DOCS, m + "_red_boxes.md"))


def write_overlay_png(F):
    try:
        from PIL import Image, ImageDraw
    except Exception as e:                                        # pragma: no cover
        print("[red] 跳过 PNG（%s）" % e)
        return
    src = TGA if os.path.exists(TGA) else os.path.join(ROOT, "samples", "scene", "aiji", "ditu2.tga")
    im = Image.open(src).convert("RGB").resize((1024, 1024), Image.BILINEAR)
    dr = ImageDraw.Draw(im)
    for q in F["T"]:                                              # 生产 111 格：浅蓝细圈
        dr.ellipse([q[0] - 3, q[1] - 3, q[0] + 3, q[1] + 3], outline=(130, 190, 255), width=1)
    for q in F["TA"]:                                             # 候选 N 格：深蓝实心
        dr.ellipse([q[0] - 5, q[1] - 5, q[0] + 5, q[1] + 5], outline=(15, 70, 220), width=3)
    for q in F["plots"]:                                          # 红框
        dr.rectangle([q["px"] - q["w"] * 512, q["py"] - q["h"] * 512,
                      q["px"] + q["w"] * 512, q["py"] + q["h"] * 512], outline=(255, 0, 0), width=2)
    p = os.path.join(DOCS, F["map"] + "_red_boxes.png")
    im.save(p)
    print("[red] → %s" % p)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--map", default="aiji")
    ap.add_argument("--n", type=int, default=None)
    a = ap.parse_args()
    F = run(a.map, n=a.n)
    write_candidate(F)
    write_report(F)
    write_overlay_png(F)


if __name__ == "__main__":
    main()
