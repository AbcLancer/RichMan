# -*- coding: utf-8 -*-
"""
minimap_route.py —— 从原版小地图 `m_aiji.tga` 提取**原版路线拓扑**并排序成闭环。

为什么值得解
------------
小地图上那条深棕色线是原版棋盘行走路线的**线条画**（比大图 `ditu.tga` 的碎石纹理好提取得多）。
它明确给出两件事：
  1. 路线**不是椭圆**，而是「左环 + 右环」在中段汇合的形状；
  2. 两个环的接合处有两个**红点**（起点标记），路线在那里断开。

流程
----
  深棕线掩码 → 细化成 1px 骨架 → 补齐两个断点 → **动量行走**排成有序闭环
  （动量：优先「最顺着当前方向」的像素，先窄方向锥小半径，走不动了再放宽）

与生产的对照（2026-09-25 实测）
------------------------------
  把小地图路线按**仿射**（小地图是 256×128 的 2:1 面板，被纵向压扁）拟合到 `ditu.tga`
  的步道掩码上，只能到**截尾 chamfer ≈16 px**（≈ 半个格距），**精度不够**用来产格坐标。
  所以本工具**只输出「拓扑/形状」**，不产 `tilepos`。
  → 想拿精确格坐标，仍以 `aiji_tilepos.json`（步道对齐中位 6.9 px）为准。

产物
----
  docs/orig-scene/aiji_minimap_route.json   有序路线点（小地图像素坐标）+ 闭环长度
  .workbuddy/mini_walk.png                  彩虹着色的行走顺序（人工核对用）

用法
----
  python tools/minimap_route.py
  python tools/minimap_route.py --map china
"""

import argparse
import json
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from walkway_mask import thin_zhang_suen                      # noqa: E402

DOCS = os.path.join(ROOT, "docs", "orig-scene")
WB = os.path.join(ROOT, ".workbuddy")
TGA = os.path.join(ROOT, "samples", "uitex", "subc", "m_%s.tga")


# ------------------------------------------------------------------ 掩码

def route_mask(mapname="aiji"):
    p = TGA % mapname
    im = Image.open(p).convert("RGB")
    a = np.asarray(im).astype(np.int16)
    R, G, B = a[:, :, 0], a[:, :, 1], a[:, :, 2]
    m = (R < 150) & (G < 130) & (B < 95) & (R >= G) & (G >= B)   # 深棕路线
    lab, n = ndimage.label(m, np.ones((3, 3)))
    if n == 0:
        return a, m
    sz = ndimage.sum(np.ones_like(lab), lab, range(1, n + 1))
    return a, (lab == int(np.argmax(sz)) + 1)


def skeleton(m):
    sk = thin_zhang_suen(m)
    lab, n = ndimage.label(sk, np.ones((3, 3)))
    if n > 1:
        sz = ndimage.sum(np.ones_like(lab), lab, range(1, n + 1))
        sk = lab == int(np.argmax(sz)) + 1
    return sk


def degrees(sk):
    P = np.pad(sk, 1).astype(np.uint8)
    s = np.zeros(sk.shape, np.int16)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            if dy or dx:
                s += P[1 + dy:1 + dy + sk.shape[0], 1 + dx:1 + dx + sk.shape[1]]
    return np.where(sk, s, 0)


def close_tips(sk, rad=14):
    """把两个断点（原版红点处）用直线连起来，让路线成闭环。"""
    d = degrees(sk)
    tips = np.argwhere(sk & (d <= 1))
    if len(tips) < 2:
        return sk, []
    pts = tips.astype(np.float64)
    best, bi, bj = 1e18, 0, 1
    for i in range(len(pts)):
        dd = np.linalg.norm(pts - pts[i], axis=1)
        dd[i] = 1e18
        j = int(np.argmin(dd))
        if dd[j] < best:
            best, bi, bj = dd[j], i, j
    if best > rad * 4:
        return sk, []
    a, b = tips[bi], tips[bj]
    add = [(int(round(a[0] + (b[0] - a[0]) * k / (best + 2))),
            int(round(a[1] + (b[1] - a[1]) * k / (best + 2)))) for k in range(1, int(best) + 2)]
    out = sk.copy()
    for (y, x) in add:
        out[y, x] = True
    return out, add


def order_walk(sk, step=2.0):
    """动量行走：优先「最顺着当前方向」的未访问像素；方向锥逐步放宽、最后放大半径。"""
    pts = np.argwhere(sk).astype(np.float64)
    if len(pts) == 0:
        return []
    used = np.zeros(len(pts), dtype=bool)
    si = int(np.argmin(pts[:, 1] * 1.0 + pts[:, 0] * 0.6))
    order = [si]
    used[si] = True
    d = np.array([1.0, 0.0])
    for _ in range(len(pts) * 6):
        cur = pts[order[-1]]
        rel = pts - cur
        dist = np.linalg.norm(rel, axis=1)
        cand = np.nonzero((~used) & (dist > 1e-9))[0]
        if len(cand) == 0:
            break
        u = rel[cand] / dist[cand][:, None]
        dot = u @ d
        pick = None
        for rad, cone in ((step, 0.25), (step, -0.45), (step * 2, -0.75),
                          (step * 3.5, -0.95), (step * 6, -1.01)):
            sel = (dist[cand] <= rad) & (dot >= cone)
            if sel.any():
                ii = cand[sel]
                score = dot[sel] + 0.30 * (1.0 - dist[ii] / max(rad, 1e-9))
                pick = int(ii[int(np.argmax(score))])
                break
        if pick is None:
            break
        nd = pts[pick] - cur
        nd = nd / max(np.linalg.norm(nd), 1e-9)
        d = 0.55 * d + 0.45 * nd
        d = d / max(np.linalg.norm(d), 1e-9)
        order.append(pick)
        used[pick] = True
    return pts[order]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--map", default="aiji")
    a = ap.parse_args()
    m = a.map

    _, mask = route_mask(m)
    sk = skeleton(mask)
    d = degrees(sk)
    print("[mini] %s：掩码 %d px · 骨架 %d px · 断点(度<=1) %d"
          % (m, mask.sum(), sk.sum(), int((sk & (d <= 1)).sum())))
    skC, add = close_tips(sk)
    path = order_walk(skC)
    cov = 100.0 * len(path) / max(1, int(skC.sum()))
    P = np.asarray(path, dtype=float)                     # (y,x)
    seg = np.linalg.norm(np.diff(P, axis=0), axis=1) if len(P) > 1 else np.array([0.0])
    print("[mini] 闭环补点 %d · 行走 %d 点（覆盖 %.1f%%）· 路径长 %.1f px（段长中位 %.2f）"
          % (len(add), len(path), cov, seg.sum(), float(np.median(seg))))

    os.makedirs(DOCS, exist_ok=True)
    out = {
        "_comment": "原版小地图 m_%s.tga 里画出来的**路线**（有序闭环，小地图像素坐标）" % m,
        "_generated_by": "tools/minimap_route.py",
        "_why": "小地图路线是线条画，明确给出「左环+右环在中段汇合、接合处有两个红点」的拓扑。",
        "_accuracy_warning": ("⚠️ 小地图是 256×128 的 **2:1 压扁示意图**，把它仿射拟合到 "
                              "ditu.tga 的步道掩码只能到 ≈16 px（≈半个格距）——**精度不够产格坐标**。"
                              "所以这里只给拓扑/形状；格坐标仍以 game/data/maps/aiji_tilepos.json 为准"
                              "（它到步道的对齐中位 6.9 px）。"),
        "_traversal_coverage_pct": round(cov, 1),
        "_closed_len_px": round(float(seg.sum()), 2),
        "_note": "坐标是 (x, y) = (列, 行)，图像 y 向下。",
        "count": len(P),
        "points": [[round(float(x), 1), round(float(y), 1)] for y, x in P],
    }
    pj = os.path.join(DOCS, m + "_minimap_route.json")
    json.dump(out, open(pj, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print("[mini] → %s" % pj)

    vis = np.zeros((mask.shape[0], mask.shape[1], 3), np.uint8)
    vis[mask] = (60, 45, 30)
    n = max(len(P) - 1, 1)
    for k, (y, x) in enumerate(P):
        t = k / n
        vis[int(y), int(x)] = (int(255 * t), int(120 * (1 - abs(2 * t - 1))), int(255 * (1 - t)))
    for y, x in add:
        vis[y, x] = (255, 255, 255)
    Image.fromarray(vis).resize((mask.shape[1] * 4, mask.shape[0] * 4), Image.NEAREST) \
        .save(os.path.join(WB, "mini_walk.png"))
    print("[mini] → %s" % os.path.join(WB, "mini_walk.png"))


if __name__ == "__main__":
    main()
