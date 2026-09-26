# -*- coding: utf-8 -*-
"""
route_from_walkway.py —— 用原版【石子路步道】重建棋盘格点，并按原版格数重采样。

为什么要换一套坐标
------------------
旧的生产坐标 `game/data/maps/aiji_tilepos.json`（111 格）来源写在它自己的 `_comment` 里：

    原版小地图路线(拓扑) + 美术内地块方块锚点(精确位置) 分段相似变换对齐后等弧采样

也就是说它**不是从石子路量出来的**：小地图 `m_aiji.tga` 只有 256×128、还是 2:1 压扁的
示意图，仿射拟合到 `ditu.tga` 只能到 ≈16 px（半个格距）。后果（`tools/walkway_mask.py`
实测，源图 `ditu.tga` = 游戏真身）：

    格点 → 步道掩码（任一点）     中位  6.9 px
    格点 → 步道【中心线】(骨架)   中位 20.3 px / 90% 43.2 px / 最大 65.2 px

步道带宽只有 30~40 px（半宽 15~20 px）→ 「到掩码 6.9 px」只说明**还踩在路面上**，
而**没有走在路中线**上。近景相机只离角色 3.9 格，半格错位就是一屏都是沙地。

原版到底几格
------------
  ① `aiji.r6m` 里 20 个街区各自声明「宽 A 格」，**ΣA = 94**（原版自己的数据）
  ② 编辑器贴图 `ditu2_1024.tga` 上 50 个红槽位框的**组内间距中位 29.98 px**；
     本环线长 2769.5 px → 2769.5 / 29.98 = **92.4 格**
  ③ 本环线 2769.5 px ÷ 94 = **29.46 px**，与 ② 的 29.98 px 只差 1.7%  ✔ 自洽
  （旧的 111 格 → 25.00 px/格，比原版密 1/6，这就是「越走越偏」的第二个来源）
三个数都落在 92~94，本工具取 **94**。

做法
----
  1. 复用 `walkway_mask` 的步道掩码 + 骨架（不重新调参，保证口径一致）；
  2. 把已验证拓扑的旧环线**等弧重采样**成 N 格；
  3. 迭代**吸附**：先拉进步道带内，再沿路径法线把格点**居中到带中线**，每轮环形平滑；
     搜索半径限制在 0.72 格距内 —— 防止在中间「8 字」交叉处跳到另一条支路；
  4. 输出新 `aiji_tilepos.json` + 叠图 + 新旧指标对照。

用法
----
  python tools/route_from_walkway.py                 # 默认 N=94，写生产
  python tools/route_from_walkway.py --n 94 --dry-run # 只看指标，不动生产
  python tools/route_from_walkway.py --restore        # 回滚成归档的 111 格
"""

import argparse
import json
import os
import shutil
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy.spatial import cKDTree

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))

from walkway_mask import build, clean, thin_zhang_suen   # noqa: E402

MAP = "aiji"
MAPDIR = os.path.join(ROOT, "game", "data", "maps")
DOCS = os.path.join(ROOT, "docs", "orig-scene")
SCENE = os.path.join(ROOT, "samples", "scene")
ARCHIVE = os.path.join(DOCS, "aiji_tilepos_111_spline.json")   # 旧 111 格（证据）
PROD = os.path.join(MAPDIR, "aiji_tilepos.json")
BOARD_SIZE = 200.0
IMG = 1024.0
N_DEFAULT = 94


# ------------------------------------------------------------------ 基础

def px_to_board(px, py):
    """像素 → 棋盘世界坐标（与 `board_view.gd` 的 UV 约定严格一致）。

    `u = x / S + 0.5`、`v = z / S + 0.5`（⚠️ 不是 `0.5 - z/S`，那是 Z 镜像，见铁律 #22），
    S = `board_size` = 200；整张 1024² 铺满棋盘。
    """
    x = (px / IMG - 0.5) * BOARD_SIZE
    z = (py / IMG - 0.5) * BOARD_SIZE
    return x, z


def loop_length(P):
    return float(np.linalg.norm(np.roll(P, -1, axis=0) - P, axis=1).sum())


def resample_loop(P, n):
    """把闭合折线 P 等弧长重采样成 n 个点（线性插值，首点对齐原首点）。"""
    d = np.linalg.norm(np.roll(P, -1, axis=0) - P, axis=1)
    s = np.concatenate([[0.0], np.cumsum(d)])
    L = s[-1]
    t = np.linspace(0.0, L, n, endpoint=False)
    Q = np.vstack([P, P[:1]])
    x = np.interp(t, s, Q[:, 0])
    y = np.interp(t, s, Q[:, 1])
    return np.stack([x, y], 1)


def smooth_loop(P, w=3, passes=1):
    """环形移动平均平滑（w 为奇数窗口）。"""
    for _ in range(passes):
        acc = np.zeros_like(P)
        half = w // 2
        for k in range(-half, half + 1):
            acc += np.roll(P, k, axis=0)
        P = acc / float(w)
    return P


def spacing_stats(P):
    d = np.linalg.norm(np.roll(P, -1, axis=0) - P, axis=1)
    return float(np.median(d)), float(d.min()), float(d.max())


# ------------------------------------------------------------------ 吸附

def snap_to_walkway(P, mask_tree, mask_pts, sk_tree, pitch,
                    iters=60, alpha=0.55, R_frac=0.72, verbose=True, lateral=0.0,
                    mode="interior", dt_in=None, clamp_frac=0.9):
    """把格点吸附到步道带中线上。

    每轮：
      ① 切线 t = 归一化(下一个 - 上一个)；法线 n = perp(t)；
      ② 在半径 R = R_frac × 格距 内取步道像素，求出「这一横截面的带中线」；
      ③ 半径内一个步道像素都没有（说明点在带外）→ 朝最近步道点挪 alpha；
      ④ 环形平滑，压掉逐点抖动。
    半径限制在 0.72 格距是**关键**：中间「8 字」交叉处两条步道相距约 1~2 格距，
    半径再大会把格点吸到对侧支路上。

    第 ② 步有两种口径（`mode`）：
      - `"quantile"`（旧）：取球内像素法向投影的 5%~95% 分位中点。
        ❌ **有系统偏差**：球半径 19 px 常常盖不满 30~40 px 宽的带，
          截断后中点偏向「球能盖到的那半边」→ 实测格点会骑在步道**内侧边缘**上
          （不是坏了，但近景一眼能看出「地毯没压在路上」）。
      - `"interior"`（新，默认）：取球内**离背景最远**的像素（步道掩码的距离变换
        的脊线就是带中线）→ 只沿法向朝它挪。这是真正的中线，且不受球截断影响。

    `lateral` > 0 时，最后整体沿法线**偏移**这么多像素（正方向 = 朝棋盘重心一侧）。
    原版美术里「建筑地块的方块」画在步道内侧约 1 格处（编辑器红框就是标它们），
    如果老板想让地毯压在那些方块上而不是压在路上，用这个参数即可。
    """
    R = R_frac * pitch
    hist = []
    for it in range(iters):
        t = np.roll(P, -1, axis=0) - np.roll(P, 1, axis=0)
        t = t / np.maximum(np.linalg.norm(t, axis=1, keepdims=True), 1e-9)
        nv = np.stack([-t[:, 1], t[:, 0]], 1)

        newP = P.copy()
        moved = 0.0
        for i in range(len(P)):
            idx = mask_tree.query_ball_point(P[i], R)
            if len(idx) >= 6:
                if mode == "interior" and dt_in is not None:
                    vals = dt_in[mask_pts[idx, 1].astype(int),
                                 mask_pts[idx, 0].astype(int)]
                    # 只考虑「同一横截面」的候选（切向偏移 < 0.3 格距），
                    # 免得沿带方向飘到别的格子上
                    q = mask_pts[idx] - P[i]
                    tang = np.abs(q @ t[i])
                    ok = tang < 0.30 * pitch
                    if ok.sum() >= 3:
                        jj = int(np.argmax(np.where(ok, vals, -1.0)))
                    else:
                        jj = int(np.argmax(vals))
                    s = float((mask_pts[idx][jj] - P[i]) @ nv[i])
                    s = float(np.clip(s, -clamp_frac * pitch, clamp_frac * pitch))
                    newP[i] = P[i] + nv[i] * s * alpha
                else:
                    q = mask_pts[idx] - P[i]
                    s = q @ nv[i]
                    lo, hi = np.quantile(s, 0.05), np.quantile(s, 0.95)
                    c = 0.5 * (lo + hi)
                    c = float(np.clip(c, -clamp_frac * pitch, clamp_frac * pitch))
                    newP[i] = P[i] + nv[i] * c * alpha
            else:
                dd, j = mask_tree.query(P[i], k=1)
                if dd <= 3.0 * pitch:
                    newP[i] = P[i] + (mask_pts[j] - P[i]) * alpha
            moved += float(np.linalg.norm(newP[i] - P[i]))
        P = smooth_loop(newP, w=3, passes=1)
        ds, _ = sk_tree.query(P)
        hist.append((float(np.median(ds)), float(np.quantile(ds, 0.9)), float(ds.max())))
        if verbose and (it % 10 == 0 or it == iters - 1):
            print("[snap] 第 %2d 轮：到中心线 中位 %5.2f / 90%% %5.2f / 最大 %5.2f px"
                  % (it + 1, hist[-1][0], hist[-1][1], hist[-1][2]))
        if moved / len(P) < 0.02:
            break
    if abs(lateral) > 1e-6:
        t = np.roll(P, -1, axis=0) - np.roll(P, 1, axis=0)
        t = t / np.maximum(np.linalg.norm(t, axis=1, keepdims=True), 1e-9)
        nv = np.stack([-t[:, 1], t[:, 0]], 1)
        cen = P.mean(0)
        # 法线朝棋盘重心的一侧为正
        sign = np.sign(((cen - P) * nv).sum(1))
        sign[sign == 0] = 1.0
        P = P + nv * (sign[:, None] * lateral)
    return P, hist


def compute(n=N_DEFAULT, tex="ditu", verbose=True, lateral=0.0, mode="interior"):
    """跑完整条管线，返回新旧坐标与度量（供 main / 其它脚本复用）。"""
    P_old = load_old()
    m, sk, mask_pts, mask_tree, sk_pts, sk_tree, info, dt_in = make_mask(tex)
    d_sk_old, _ = sk_tree.query(P_old)
    P0 = resample_loop(P_old, n)

    # 交替「吸附 ↔ 等弧重采样」：吸附会在弯道处把点拉拢、把步距搞不匀，
    # 每轮吸附后再等弧重采样一次能把间距拉回均匀，如此收敛。
    P_cur, hist = P0, []
    steps = []
    for r in range(6):
        P_cur, h = snap_to_walkway(P_cur, mask_tree, mask_pts, sk_tree,
                                  loop_length(P_cur) / n,
                                  iters=10, alpha=0.70, R_frac=0.72, verbose=False,
                                  mode=mode, dt_in=dt_in)
        P_cur = resample_loop(smooth_loop(P_cur, 3, 1), n)
        ds, _ = sk_tree.query(P_cur)
        steps.append((float(np.median(ds)), float(np.quantile(ds, 0.9)),
                      spacing_stats(P_cur)[0]))
        hist += h
    P_new, h = snap_to_walkway(P_cur, mask_tree, mask_pts, sk_tree,
                              loop_length(P_cur) / n,
                              iters=10, alpha=0.70, R_frac=0.72, verbose=verbose,
                              lateral=lateral, mode=mode, dt_in=dt_in)
    hist += h
    return {"P_old": P_old, "P0": P0, "P_new": P_new, "mask": m, "sk": sk,
            "mask_pts": mask_pts, "mask_tree": mask_tree, "sk_tree": sk_tree,
            "info": info, "d_sk_old": d_sk_old, "hist": hist, "steps": steps,
            "dt_in": dt_in}


# ------------------------------------------------------------------ 主流程

def load_old():
    with open(ARCHIVE, encoding="utf-8") as f:
        d = json.load(f)
    return np.array([[e["px"], e["py"]] for e in d["tiles"]], dtype=np.float64)


def make_mask(tex="ditu"):
    import scipy.ndimage as ndi
    a, raw, sd = build(MAP, tex)
    m, info, lab, ncomp = clean(raw)
    sk = thin_zhang_suen(ndi.binary_closing(m, np.ones((3, 3)), iterations=8))
    ys, xs = np.nonzero(m)
    mask_pts = np.stack([xs, ys], 1).astype(np.float64)
    ys, xs = np.nonzero(sk)
    sk_pts = np.stack([xs, ys], 1).astype(np.float64)
    # 距离变换：掩码内每个像素「离背景多远」→ 它的脊线就是带中线
    dt_in = ndi.distance_transform_edt(m)
    return m, sk, mask_pts, cKDTree(mask_pts), sk_pts, cKDTree(sk_pts), info, dt_in



def write_tilepos(P, path):
    tiles = []
    for i, (px, py) in enumerate(P):
        x, z = px_to_board(float(px), float(py))
        tiles.append({"i": i,
                      "px": round(float(px), 1), "py": round(float(py), 1),
                      "u": round(x / BOARD_SIZE + 0.5, 6),
                      "v": round(z / BOARD_SIZE + 0.5, 6),
                      "x": round(x, 4), "z": round(z, 4)})
    doc = {
        "_comment": "按原版石子路步道中心线重建 + 等弧重采样 %d 格"
                    "（tools/route_from_walkway.py）" % len(P),
        "_source": "samples/scene/aiji/ditu.tga 的步道掩码/骨架"
                   " + docs/orig-scene/%s（旧 111 格，仅取拓扑）" % os.path.basename(ARCHIVE),
        "_tile_count_authority": ("aiji.r6m 20 街区 ΣA = 94；"
                                  "编辑器红框组内间距 29.98 px ÷ 环长 → 92.4；本环 2769.5/94 = 29.46 px"),
        "_image_size": [1024, 1024],
        "_board_size": BOARD_SIZE,
        "count": len(P),
        "tiles": tiles,
    }
    with open(path, "w", encoding="utf-8") as f:
        json.dump(doc, f, ensure_ascii=False, indent=1)
    return doc


def write_overlay(P_old, P_new, ds_old, ds_new, m, out_png):
    base = Image.open(os.path.join(SCENE, MAP, "ditu.tga")).convert("RGB")
    dr = ImageDraw.Draw(base)
    # 旧路线（灰）
    for p1, p2 in zip(P_old, np.roll(P_old, -1, axis=0)):
        dr.line([*p1, *p2], fill=(150, 150, 150), width=1)
    # 新路线（蓝）
    for p1, p2 in zip(P_new, np.roll(P_new, -1, axis=0)):
        dr.line([*p1, *p2], fill=(0, 120, 255), width=2)
    for i, c in enumerate(P_new):
        col = (255, 40, 40) if ds_new[i] > 25 else (255, 235, 0)
        dr.ellipse([c[0] - 4, c[1] - 4, c[0] + 4, c[1] + 4], fill=col)
        if i % 10 == 0:
            dr.text((c[0] + 6, c[1] - 15), str(i), fill=(255, 0, 255))
    base.save(out_png)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--n", type=int, default=N_DEFAULT)
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--restore", action="store_true")
    ap.add_argument("--tex", default="ditu")
    ap.add_argument("--lateral", type=float, default=0.0,
                    help="整体沿路径法线偏移多少像素（正=朝棋盘内侧）；0=地毯压在路上")
    ap.add_argument("--mode", default="interior", choices=["interior", "quantile"],
                    help="横截面取中线的口径；interior=按掩码距离变换的脊线（默认，无系统偏差）")
    a = ap.parse_args()

    if a.restore:
        shutil.copyfile(ARCHIVE, PROD)
        print("[route] 已回滚 %s ← %s" % (PROD, ARCHIVE))
        return

    P_old = load_old()
    L = loop_length(P_old)
    print("[route] 旧环线 %d 格，环长 %.1f px，步距中位 %.2f px" % (len(P_old), L, spacing_stats(P_old)[0]))

    r = compute(a.n, a.tex, verbose=True, lateral=a.lateral, mode=a.mode)
    P_new, P0, d_sk_old, info = r["P_new"], r["P0"], r["d_sk_old"], r["info"]
    m, sk, mask_tree, sk_tree = r["mask"], r["sk"], r["mask_tree"], r["sk_tree"]
    print("[route] 步道掩码 %d px / 骨架 %d px（连通域前 6：%s）"
          % (m.sum(), sk.sum(), ", ".join("%d%s" % (it["px"], "*" if it["kept"] else "")
                                          for it in info[:6])))
    print("[route] 旧 %d 格 → 中心线：中位 %.1f / 90%% %.1f / 最大 %.1f px"
          % (len(P_old), np.median(d_sk_old), np.quantile(d_sk_old, 0.9), d_sk_old.max()))
    print("[route] 重采样 %d 格 → 步距 %.2f px（原版红框实测 29.98 px）"
          % (a.n, loop_length(P0) / a.n))
    for i, (md_, q90, sp) in enumerate(r["steps"]):
        print("[route] 外层第 %d 轮：到中心线 中位 %5.2f px / 90%% %5.2f ｜ 步距 %5.2f px"
              % (i + 1, md_, q90, sp))

    d_m_new, _ = mask_tree.query(P_new)
    d_sk_new, _ = sk_tree.query(P_new)
    med, lo, hi = spacing_stats(P_new)
    print("[route] 新 %d 格 → 步道掩码：中位 %.2f px" % (a.n, np.median(d_m_new)))
    print("[route] 新 %d 格 → 中心线  ：中位 %.2f / 90%% %.2f / 最大 %.2f px"
          % (a.n, np.median(d_sk_new), np.quantile(d_sk_new, 0.9), d_sk_new.max()))
    print("[route] 新步距：中位 %.2f / 最小 %.2f / 最大 %.2f px" % (med, lo, hi))
    print("[route] 离中心线 > 25 px 的格：%d / %d（旧 %d / %d）"
          % (int((d_sk_new > 25).sum()), a.n, int((d_sk_old > 25).sum()), len(P_old)))

    # 指标报告
    rep = {
        "_comment": "步道吸附前后对照（tools/route_from_walkway.py）",
        "tile_count": {"old": int(len(P_old)), "new": int(a.n),
                       "r6m_sum_A": 94, "redbox_pitch_estimate": 92.4,
                       "pitch_check_at_old_loop": round(loop_length(P0) / a.n, 2)},
        "pitch_px": {"old_median": round(spacing_stats(P_old)[0], 2),
                     "redbox_median": 29.98, "new_median": round(med, 2),
                     "new_min": round(lo, 2), "new_max": round(hi, 2)},
        "to_centerline_px": {
            "old": [round(float(np.median(d_sk_old)), 2), round(float(np.quantile(d_sk_old, 0.9)), 2),
                    round(float(d_sk_old.max()), 2)],
            "new": [round(float(np.median(d_sk_new)), 2), round(float(np.quantile(d_sk_new, 0.9)), 2),
                    round(float(d_sk_new.max()), 2)]},
        "to_mask_px": {"new": [round(float(np.median(d_m_new)), 2),
                               round(float(np.quantile(d_m_new, 0.9)), 2),
                               round(float(d_m_new.max()), 2)]},
        "off_gt25px": {"old": int((d_sk_old > 25).sum()), "new": int((d_sk_new > 25).sum())},
        "convergence": [[round(x, 2) for x in h] for h in r["hist"]],
        "worst_new": [{"i": int(i), "d_skel": round(float(d_sk_new[i]), 1)}
                      for i in np.argsort(d_sk_new)[::-1][:12]],
    }
    os.makedirs(DOCS, exist_ok=True)
    with open(os.path.join(DOCS, "aiji_route_walkway.json"), "w", encoding="utf-8") as f:
        json.dump(rep, f, ensure_ascii=False, indent=1)

    png = os.path.join(DOCS, "aiji_route_walkway.png")
    write_overlay(P_old, P_new, d_sk_old, d_sk_new, m, png)
    print("[route] → %s（灰=旧 111 格，蓝=新 %d 格，黄点=贴合，红点=离中线>25px）" % (png, a.n))

    if not a.dry_run:
        write_tilepos(P_new, PROD)
        print("[route] → %s（已写生产，%d 格）" % (PROD, a.n))
    else:
        print("[route] --dry-run：未写生产文件")


if __name__ == "__main__":
    main()
