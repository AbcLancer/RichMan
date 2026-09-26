# -*- coding: utf-8 -*-
"""
walkway_mask.py —— 从原版棋盘贴图里分出**步道**，给「画面对齐」一个客观指标。

三张贴图的关系（2026-09-25 实测，互相关 NCC）
--------------------------------------------
| 文件 | 尺寸 | 内容 | 与 `ditu2_1024` 的关系 |
|---|---|---|---|
| `ditu.tga` | 1024² | **游戏实际用的棋盘贴图**：沙子地面 + 石子镶边的步道 + 灰色石板 + 建筑/棕榈阴影；中央是**干涸的沙质河床**（不是蓝水） | NCC 0.089 → **完全不同的取景** |
| `ditu_noshadow.tga` | 1024² | 同上但**去掉阴影/石板/水**，只剩地形 + 石子步道 | 偏移 (0,0)，NCC **0.632** → **同框** |
| `ditu2_1024.tga` | 1024² | 编辑器版 = `ditu_noshadow` + **蓝色水面** + **50 个红框**（地产槽位标注） | 基准 |

→ 所以：**看对齐要用 `ditu.tga`；做分割/量坐标用 `ditu_noshadow` 或 `ditu2_1024`**（同框，
红框坐标可比）。之前把 `ditu2_1024` 的水面当成「真河」，误判了「中段过河没有路」。

步道怎么分
----------
步道 = 铺满**碎石子**的带子：局部纹理强度高、灰度偏暗、饱和度低于沙地。
判据：`sd(局部标准差) > 9` 且 `非沙地` 且 `非水` 且 `非壁画红` 且 `gray` 且 `L < 232`；
再做**闭运算补洞 + 开口去除细轮廓**（河岸线、岩石边缘这些细线会被滤掉），
最后只保留两个主连通域（左右两个环）。

产物
----
  docs/orig-scene/<map>_walkway.{json,md,png}
  .workbuddy/walkway_mask.png

用法
----
  python tools/walkway_mask.py                       # 默认 ditu_noshadow
  python tools/walkway_mask.py --tex ditu2_1024
"""

import argparse
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage
from scipy.spatial import cKDTree

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MAPDIR = os.path.join(ROOT, "game", "data", "maps")
DOCS = os.path.join(ROOT, "docs", "orig-scene")
WB = os.path.join(ROOT, ".workbuddy")
SCENE = os.path.join(ROOT, "samples", "scene")


# ------------------------------------------------------------------ 掩码

def box_mean(A, r):
    P = np.pad(A, ((1, 0), (1, 0)))
    I = P.cumsum(0).cumsum(1)
    H, W = A.shape
    y0 = np.clip(np.arange(H) - r, 0, H)
    y1 = np.clip(np.arange(H) + r + 1, 0, H)
    x0 = np.clip(np.arange(W) - r, 0, W)
    x1 = np.clip(np.arange(W) + r + 1, 0, W)
    S = I[np.ix_(y1, x1)] - I[np.ix_(y0, x1)] - I[np.ix_(y1, x0)] + I[np.ix_(y0, x0)]
    N = ((y1 - y0)[:, None] * (x1 - x0)[None, :]).astype(np.float64)
    return S / np.maximum(N, 1.0)


def build(mapname="aiji", tex="ditu"):
    p = os.path.join(SCENE, mapname, tex + ".tga")
    if not os.path.exists(p):
        p = os.path.join(SCENE, mapname, tex + ".tga".replace(".tga", ""))
    a = np.asarray(Image.open(p).convert("RGB")).astype(np.float64)
    R, G, B = a[:, :, 0], a[:, :, 1], a[:, :, 2]
    L = 0.299 * R + 0.587 * G + 0.114 * B
    mu = box_mean(L, 3)
    sd = np.sqrt(np.clip(box_mean(L * L, 3) - mu * mu, 0.0, None))
    sand = (R - G > 28) & (G - B > 45) & (R > 200)
    water = (B - G > 10) & (B > 150)
    art = (R - G > 55) & (R < 200)
    gray = (R - G < 42) & (R - B < 80)
    raw = (sd > 9.0) & (~sand) & (~water) & (~art) & gray & (L < 232)
    return a, raw, sd


def clean(raw, close_it=3, open_it=5, n_keep=2, min_px=1500):
    m = ndimage.binary_closing(raw, np.ones((3, 3)), iterations=close_it)
    m = ndimage.binary_opening(m, np.ones((3, 3)), iterations=open_it)
    lab, n = ndimage.label(m, np.ones((3, 3)))
    if n == 0:
        return m, [], lab, n
    sz = np.array(ndimage.sum(np.ones_like(lab), lab, range(1, n + 1)))
    order = np.argsort(sz)[::-1]
    keep = [int(order[k]) + 1 for k in range(min(n_keep, n)) if sz[order[k]] >= min_px]
    m2 = np.isin(lab, keep)
    info = []
    for k in order[:6]:
        b = lab == (k + 1)
        yy, xx = np.nonzero(b)
        info.append({"px": int(sz[k]), "bbox": [int(xx.min()), int(yy.min()), int(xx.max()), int(yy.max())],
                     "kept": (k + 1) in keep})
    return m2, info, lab, n


def thin_zhang_suen(img, max_it=200):
    I = img.copy()

    def nb(I):
        P = np.pad(I, 1)
        return (P[0:-2, 1:-1], P[0:-2, 2:], P[1:-1, 2:], P[2:, 2:],
                P[2:, 1:-1], P[2:, 0:-2], P[1:-1, 0:-2], P[0:-2, 0:-2])

    ch, it = True, 0
    while ch and it < max_it:
        ch, it = False, it + 1
        for step in (0, 1):
            p2, p3, p4, p5, p6, p7, p8, p9 = nb(I)
            B = sum(x.astype(np.uint8) for x in (p2, p3, p4, p5, p6, p7, p8, p9))
            seq = [p2, p3, p4, p5, p6, p7, p8, p9, p2]
            A = np.zeros_like(B)
            for k in range(8):
                A += ((~seq[k].astype(bool)) & (seq[k + 1].astype(bool))).astype(np.uint8)
            c1 = ~(p2 & p4 & p6) if step == 0 else ~(p2 & p4 & p8)
            c2 = ~(p4 & p6 & p8) if step == 0 else ~(p2 & p6 & p8)
            rm = I & (B >= 2) & (B <= 6) & (A == 1) & c1 & c2
            if rm.any():
                I = I & (~rm)
                ch = True
    return I


def deg_map(sk):
    P = np.pad(sk, 1).astype(np.uint8)
    s = np.zeros(sk.shape, np.int16)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            if dy or dx:
                s += P[1 + dy:1 + dy + sk.shape[0], 1 + dx:1 + dx + sk.shape[1]]
    return np.where(sk, s, 0)


# ------------------------------------------------------------------ 主流程

def run(mapname="aiji", tex="ditu"):
    a, raw, sd = build(mapname, tex)
    m, info, lab, ncomp = clean(raw)
    print("[walk] %s.tga：原始掩码 %d px（%.2f%%）→ 清理后 %d px；连通域前 6："
          % (tex, raw.sum(), 100.0 * raw.sum() / raw.size, m.sum()))
    for it in info:
        print("[walk]   %6d px bbox %s%s" % (it["px"], it["bbox"], "  ← 采用" if it["kept"] else ""))

    # 步道中心线（骨架）
    sk = thin_zhang_suen(ndimage.binary_closing(m, np.ones((3, 3)), iterations=8))
    d = deg_map(sk)
    print("[walk] 步道掩码 → 骨架 %d px（端点 %d · 交叉点 %d）"
          % (sk.sum(), int((sk & (d == 1)).sum()), int((sk & (d >= 3)).sum())))

    ys, xs = np.nonzero(m)
    mask_pts = np.stack([xs, ys], 1).astype(np.float64)
    mask_tree = cKDTree(mask_pts)
    ys, xs = np.nonzero(sk)
    sk_pts = np.stack([xs, ys], 1).astype(np.float64)
    sk_tree = cKDTree(sk_pts) if len(sk_pts) else None

    # 生产棋盘格点
    sys.path.insert(0, os.path.join(ROOT, "tools"))
    from red_boxes_to_tilepos import load_tiles, load_plots
    tdoc, T = load_tiles(mapname)
    pdoc, P, plots = load_plots(mapname)
    dm, _ = mask_tree.query(T)
    ds, _ = sk_tree.query(T) if sk_tree else (np.zeros(len(T)), None)
    print("[walk] 生产 %d 格 → 步道掩码：中位 %.1f / 90%% %.1f / 最大 %.1f px"
          % (len(T), np.median(dm), np.quantile(dm, 0.9), dm.max()))
    print("[walk] 生产 %d 格 → 步道中心线：中位 %.1f / 90%% %.1f / 最大 %.1f px"
          % (len(T), np.median(ds), np.quantile(ds, 0.9), ds.max()))
    off = int((ds > 25).sum())
    print("[walk] 其中离中心线 > 25 px 的格数：%d / %d" % (off, len(T)))
    print("[walk] 偏差最大的 10 格：" + ", ".join(
        "%d(%.0fpx)" % (i, ds[i]) for i in np.argsort(ds)[::-1][:10]))

    worst = [{"i": int(i), "d_mask": round(float(dm[i]), 1), "d_skel": round(float(ds[i]), 1)}
             for i in np.argsort(ds)[::-1][:20]]

    # 可视化（画在真身 ditu.tga 上）
    disp = os.path.join(SCENE, mapname, "ditu.tga")
    base = Image.open(disp if os.path.exists(disp) else
                      os.path.join(SCENE, mapname, tex + ".tga")).convert("RGB")
    dr = ImageDraw.Draw(base)
    for i, (p1, p2) in enumerate(zip(T, np.roll(T, -1, axis=0))):
        dr.line([*p1, *p2], fill=(0, 150, 255), width=2)
    for i, c in enumerate(T):
        col = (255, 40, 40) if ds[i] > 25 else (255, 235, 0)
        dr.ellipse([c[0] - 4, c[1] - 4, c[0] + 4, c[1] + 4], fill=col)
        if i % 10 == 0:
            dr.text((c[0] + 6, c[1] - 15), str(i), fill=(255, 0, 255))
    os.makedirs(DOCS, exist_ok=True)
    p = os.path.join(DOCS, mapname + "_walkway.png")
    base.save(p)
    print("[walk] → %s（蓝线=生产路线；黄点=贴合；红点=离中心线 > 25 px）" % p)

    # 掩码本身
    vis = np.zeros((m.shape[0], m.shape[1], 3), np.uint8)
    vis[m] = (95, 70, 60)
    vis[sk] = (255, 220, 60)
    Image.fromarray(vis).save(os.path.join(WB, "walkway_mask.png"))

    out = {"_comment": "步道掩码 / 对齐度量（tools/walkway_mask.py）",
           "_texture": tex + ".tga",
           "_texture_note": "看对齐用 ditu.tga（游戏真身）；做分割用 ditu_noshadow（同框于 ditu2_1024）",
           "_mask_px": int(m.sum()), "_skeleton_px": int(sk.sum()),
           "_components": info,
           "tiles": len(T),
           "tile_to_mask_px": [round(float(np.median(dm)), 2),
                               round(float(np.quantile(dm, 0.9)), 2), round(float(dm.max()), 2)],
           "tile_to_centerline_px": [round(float(np.median(ds)), 2),
                                     round(float(np.quantile(ds, 0.9)), 2), round(float(ds.max()), 2)],
           "tiles_off_centerline_gt25px": off,
           "worst_tiles": worst}
    json.dump(out, open(os.path.join(DOCS, mapname + "_walkway.json"), "w", encoding="utf-8"),
              ensure_ascii=False, indent=1)

    L = ["# aiji —— 步道掩码 与 棋盘对齐度量", "",
         "## 三张棋盘贴图的关系（互相关 NCC 实测）", "",
         "| 文件 | 内容 | 与 `ditu2_1024` 的关系 |", "|---|---|---|",
         "| `ditu.tga` | **游戏实际用的棋盘贴图**：沙地 + 石子镶边的步道 + 灰色石板 + 建筑/棕榈阴影；中央是**干涸的沙质河床**（不是蓝水） | NCC 0.089 → **完全不同的取景** |",
         "| `ditu_noshadow.tga` | 去掉阴影/石板/水，只剩地形 + 石子步道 | 偏移 (0,0)，NCC **0.632** → **同框** |",
         "| `ditu2_1024.tga` | 编辑器版 = `ditu_noshadow` + 蓝色水面 + **50 个红框** | 基准 |", "",
         "> ⚠️ **教训**：先前把 `ditu2_1024` 的蓝水当成「真河」，据此判断「我们中段过河没有路」——",
         "> 但 `ditu.tga` 里那里是**干涸河床**，路线本来就从上面过。",
         "> **看对齐必须用 `ditu.tga`；做分割/量坐标才用 `ditu_noshadow`（与红框同框）。**", "",
         "## 步道掩码", "",
         "| 项 | 值 |", "|---|---|",
         "| 源贴图 | `%s.tga` |" % tex,
         "| 原始掩码 | %d px（%.2f%%） |" % (raw.sum(), 100.0 * raw.sum() / raw.size),
         "| 清理后（闭运算+开口+保留 2 个主连通域） | %d px |" % m.sum(),
         "| 骨架（步道中心线） | %d px |" % sk.sum(), "",
         "## 生产 %d 格 与 步道 的距离" % len(T), "",
         "| 口径 | 中位 | 90 分位 | 最大 |", "|---|---|---|---|",
         "| 格点 → 步道掩码（任一点） | %.1f px | %.1f px | %.1f px |"
         % (np.median(dm), np.quantile(dm, 0.9), dm.max()),
         "| 格点 → 步道**中心线**（骨架） | %.1f px | %.1f px | %.1f px |"
         % (np.median(ds), np.quantile(ds, 0.9), ds.max()), "",
         "> 离中心线 > 25 px 的格：**%d / %d**（可视化里画成红点）。" % (off, len(T)), "",
         "> 生成脚本：`tools/walkway_mask.py`（可重跑覆盖）。", ""]
    open(os.path.join(DOCS, mapname + "_walkway.md"), "w", encoding="utf-8", newline="").write("\n".join(L))
    print("[walk] → %s" % os.path.join(DOCS, mapname + "_walkway.md"))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--map", default="aiji")
    # ⚠️ 默认必须是 `ditu`（游戏真身）。`ditu_noshadow` / `ditu2_1024` 与它
    #    **不是同一个取景**（NCC 0.089），拿它们量「我们棋盘对不对得上」会得到
    #    假数字（实测中位 16 px / 57 格偏出，而 ditu 只有 0.4 px / 1 格）。
    ap.add_argument("--tex", default="ditu")
    a = ap.parse_args()
    os.makedirs(WB, exist_ok=True)
    run(a.map, a.tex)


if __name__ == "__main__":
    main()
