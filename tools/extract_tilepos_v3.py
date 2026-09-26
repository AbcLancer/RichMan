# -*- coding: utf-8 -*-
"""
extract_tilepos_v3.py —— 从原版地图素材反推棋盘地块坐标（v3，最终版）

为什么不用 .r6m：`aiji.r6m` 偏移 576 之后那张疑似地块表的字段语义仍未解出
（见 docs/original-visual-reference.md 附录 A），拿不到逐格坐标。

v3 的思路（2026-09-26）：
  原版提供了两份"路线"美术，互补使用 ——

  ① `uitex/subc/m_<map>.tga`（256×128 原版小地图）：
     里面**把整条棋盘路线画成一条深褐色闭合曲线**，拓扑 100% 可信。
     → 抠出深色曲线 → Zhang-Suen 细化成 1px → 追踪成有序闭合环。

  ② `scene/<map>/ditu.tga`（1024² 棋盘俯视美术，仅埃及有）：
     里面**把路线画成一条碎石带**，是游戏里实际看到的地面。
     → 小地图曲线经仿射变换套到 ditu 上，再按"碎石带密度"网格搜索最优 (sx,sy,ox,oy)。

  最后沿拟合后的曲线**等弧长**放 N 个地块（N 取自原版 aiji.json）。

用法：
    python tools/extract_tilepos_v3.py --map aiji --count 111
    python tools/extract_tilepos_v3.py --map aiji --count 111 --debug
"""

import argparse
import json
import math
import os
import sys
from collections import deque

import numpy as np
from PIL import Image, ImageDraw


# ------------------------------------------------------------- 形态学 / 细化

def zhang_suen(img):
    """Zhang-Suen 细化：把任意二值图变成 1px 骨架（真正的中心线，无洋葱环）"""
    P = np.pad(img.astype(np.uint8), 1)
    changed = True
    for _ in range(200):
        if not changed:
            break
        changed = False
        for step in (0, 1):
            p2 = P[0:-2, 1:-1]; p3 = P[0:-2, 2:]; p4 = P[1:-1, 2:]
            p5 = P[2:, 2:]; p6 = P[2:, 1:-1]; p7 = P[2:, 0:-2]
            p8 = P[1:-1, 0:-2]; p9 = P[0:-2, 0:-2]
            B = p2 + p3 + p4 + p5 + p6 + p7 + p8 + p9
            seq = (p2, p3, p4, p5, p6, p7, p8, p9, p2)
            A = np.zeros_like(B)
            for i in range(8):
                A += ((seq[i] == 0) & (seq[i + 1] == 1)).astype(np.uint8)
            if step == 0:
                c1 = (p2 * p4 * p6 == 0); c2 = (p4 * p6 * p8 == 0)
            else:
                c1 = (p2 * p4 * p8 == 0); c2 = (p2 * p6 * p8 == 0)
            m = (P[1:-1, 1:-1] == 1) & (B >= 2) & (B <= 6) & (A == 1) & c1 & c2
            if m.any():
                P[1:-1, 1:-1][m] = 0
                changed = True
    return P[1:-1, 1:-1].astype(bool)


def prune_ends(S, rounds=6):
    S = S.copy()
    NB = ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (1, -1), (-1, 1), (-1, -1))
    for _ in range(rounds):
        ys, xs = np.nonzero(S)
        ends = []
        for y, x in zip(ys.tolist(), xs.tolist()):
            cnt = 0
            for dy, dx in NB:
                yy, xx = y + dy, x + dx
                if 0 <= yy < S.shape[0] and 0 <= xx < S.shape[1] and S[yy, xx]:
                    cnt += 1
            if cnt <= 1:
                ends.append((y, x))
        if not ends:
            break
        for p in ends:
            S[p] = False
    return S


def trace_loop(S):
    """沿 1px 骨架追踪出一条有序闭合环。返回 [(x,y), ...]"""
    pts = set(zip(*[a.tolist() for a in np.nonzero(S)]))     # (y,x)
    if not pts:
        return []
    NB = ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (1, -1), (-1, 1), (-1, -1))

    def nb(p):
        y, x = p
        return [(y + dy, x + dx) for dy, dx in NB if (y + dy, x + dx) in pts]

    # 选一个端点/任意点起头，用"优先直行"策略走
    start = next(iter(pts))
    for p in pts:
        if len(nb(p)) == 1:
            start = p
            break
    order = [start]
    seen = {start}
    cur = start
    prev_dir = None
    while True:
        cands = [q for q in nb(cur) if q not in seen]
        if not cands:
            break
        if prev_dir is None:
            nxt = cands[0]
        else:
            def score(q):
                d = (q[0] - cur[0], q[1] - cur[1])
                return -(d[0] * prev_dir[0] + d[1] * prev_dir[1])
            nxt = min(cands, key=score)
        prev_dir = (nxt[0] - cur[0], nxt[1] - cur[1])
        order.append(nxt)
        seen.add(nxt)
        cur = nxt
    if len(order) < 8:
        return []
    return [(p[1], p[0]) for p in order]


def resample_closed(pts, step):
    """把闭合折线按等弧长重采样，返回 (n,2) 数组"""
    P = np.asarray(pts, dtype=np.float64)
    seg = np.linalg.norm(np.diff(np.vstack([P, P[:1]]), axis=0), axis=1)
    cum = np.concatenate([[0.0], np.cumsum(seg)])
    tot = cum[-1]
    n = max(4, int(round(tot / step)))
    out = []
    for i in range(n):
        s = tot * i / n
        k = min(max(int(np.searchsorted(cum, s, "right") - 1), 0), len(seg) - 1)
        t = (s - cum[k]) / max(seg[k], 1e-9)
        out.append(P[k] + (P[(k + 1) % len(P)] - P[k]) * t)
    return np.asarray(out)


def smooth_closed(P, k=6, rounds=3):
    out = P.copy()
    n = len(out)
    for _ in range(rounds):
        nxt = out.copy()
        for i in range(n):
            idx = [(i + j) % n for j in range(-k, k + 1)]
            nxt[i] = out[idx].mean(0)
        out = nxt
    return out


# ------------------------------------------------------------- 小地图路线

def minimap_path(mm_rgb):
    """从小地图里抠出深褐色路线并追踪成有序环（小地图坐标）"""
    r = mm_rgb[:, :, 0].astype(np.int16)
    g = mm_rgb[:, :, 1].astype(np.int16)
    b = mm_rgb[:, :, 2].astype(np.int16)
    m = (r < 120) & (g < 100) & (b < 90)
    if m.sum() < 30:
        # 兜底：取最暗 8%
        lum = mm_rgb.mean(2)
        m = lum < np.percentile(lum, 8)
    # 只保留最大连通域
    lab = np.zeros(m.shape, np.int32)
    ys, xs = np.nonzero(m)
    todo = set(zip(ys.tolist(), xs.tolist()))
    NB = ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (1, -1), (-1, 1), (-1, -1))
    comps = []
    while todo:
        s = todo.pop(); q = deque([s]); comp = [s]; lab[s] = len(comps) + 1
        while q:
            y, x = q.popleft()
            for dy, dx in NB:
                p = (y + dy, x + dx)
                if p in todo:
                    todo.discard(p); lab[p] = len(comps) + 1; comp.append(p); q.append(p)
        comps.append(comp)
    big = max(comps, key=len)
    mask = np.zeros(m.shape, bool)
    for y, x in big:
        mask[y, x] = True
    sk = zhang_suen(mask)
    sk = prune_ends(sk, rounds=4)
    return trace_loop(sk), mask


# ------------------------------------------------------- ditu 碎石带密度场

def band_density(rgb, k_stat=13, std_th=20.0, mean_th=200.0, k_dens=17):
    H, W = rgb.shape[0], rgb.shape[1]
    lum = rgb.mean(2)

    def integ(x):
        s = np.zeros((x.shape[0] + 1, x.shape[1] + 1))
        s[1:, 1:] = np.cumsum(np.cumsum(x, 0), 1)
        return s

    def box(a, k):
        return a[k:, k:] - a[:-k, k:] - a[k:, :-k] + a[:-k, :-k]

    def pad(v, k):
        h = k // 2
        return np.pad(v, ((h, H - v.shape[0] - h), (h, W - v.shape[1] - h)), mode="edge")

    n = float(k_stat * k_stat)
    mean = pad(box(integ(lum), k_stat) / n, k_stat)
    var = pad(box(integ(lum * lum), k_stat) / n, k_stat) - mean * mean
    std = np.sqrt(np.maximum(var, 0.0))
    green = rgb[:, :, 1] > rgb[:, :, 0] + 6          # 植被：G 明显大于 R
    band = ((std > std_th) & (mean < mean_th) & (~green)).astype(np.float64)
    nd = float(k_dens * k_dens)
    return pad(box(integ(band), k_dens) / nd, k_dens), band, std, mean


def fit_affine(path, dens, W, H, sx_rng, sy_rng, ox_rng, oy_rng):
    def evalf(sx, sy, ox, oy):
        X = path[:, 0] * sx + ox
        Y = path[:, 1] * sy + oy
        xi = np.clip(np.round(X).astype(int), 0, W - 1)
        yi = np.clip(np.round(Y).astype(int), 0, H - 1)
        return float(dens[yi, xi].mean())

    best = None
    for sx in sx_rng:
        for sy in sy_rng:
            for ox in ox_rng:
                for oy in oy_rng:
                    v = evalf(sx, sy, ox, oy)
                    if best is None or v > best[0]:
                        best = (v, sx, sy, ox, oy)
    v, sx, sy, ox, oy = best
    for _ in range(10):                     # 坐标下降细化
        improved = False
        for dsx in (-0.03, 0, 0.03):
            for dsy in (-0.03, 0, 0.03):
                for dox in (-2, 0, 2):
                    for doy in (-2, 0, 2):
                        vv = evalf(sx + dsx, sy + dsy, ox + dox, oy + doy)
                        if vv > v:
                            v, sx, sy, ox, oy = vv, sx + dsx, sy + dsy, ox + dox, oy + doy
                            improved = True
        if not improved:
            break
    return v, sx, sy, ox, oy


# ------------------------------------------------------------------- 主流程

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--map", default="aiji")
    ap.add_argument("--count", type=int, default=111)
    ap.add_argument("--mm", default=None, help="小地图 tga/png")
    ap.add_argument("--terrain", default=None, help="棋盘俯视美术 tga/png")
    ap.add_argument("--out", default=None)
    ap.add_argument("--board", type=float, default=200.0)
    ap.add_argument("--step", type=float, default=4.0, help="中轴线重采样步长(px)")
    ap.add_argument("--debug", action="store_true")
    args = ap.parse_args()

    mm_path = args.mm or ("samples/uitex/subc/m_%s.tga" % args.map)
    te_path = args.terrain or (".workbuddy/tex/%s.png" % args.map)
    if not os.path.exists(te_path):
        print("找不到棋盘美术 %s" % te_path)
        return 1

    mm = np.asarray(Image.open(mm_path).convert("RGB"))
    ter = np.asarray(Image.open(te_path).convert("RGB")).astype(np.float64)
    H, W = ter.shape[0], ter.shape[1]
    print("小地图 %s %s" % (mm_path, tuple(mm.shape[1::-1])))
    print("棋盘美术 %s %dx%d" % (te_path, W, H))

    sk_pts, mm_mask = minimap_path(mm)
    print("小地图路线点: %d" % len(sk_pts))
    if len(sk_pts) < 30:
        print("!! 小地图路线太短")
        return 1

    # 画一下小地图上的提取结果，便于人工确认
    dbg = Image.open(mm_path).convert("RGB").resize((mm.shape[1] * 3, mm.shape[0] * 3), Image.NEAREST)
    d2 = ImageDraw.Draw(dbg)
    d2.line([(x * 3, y * 3) for x, y in sk_pts], fill=(255, 0, 0), width=2)
    dbg.save(".workbuddy/tex/_v3_mm.png")

    dens, band, std, mean = band_density(ter)
    Image.fromarray((band * 255).astype(np.uint8)).save(".workbuddy/tex/_v3_band.png")

    P = np.asarray(sk_pts, dtype=np.float64)
    v, sx, sy, ox, oy = fit_affine(
        P, dens, W, H,
        sx_rng=np.arange(3.4, 4.75, 0.05),
        sy_rng=np.arange(7.0, 9.05, 0.05),
        ox_rng=np.arange(-70, 71, 6),
        oy_rng=np.arange(-80, 81, 6),
    )
    print("拟合: 密度 %.4f  sx=%.3f sy=%.3f ox=%.1f oy=%.1f" % (v, sx, sy, ox, oy))

    Q = np.stack([P[:, 0] * sx + ox, P[:, 1] * sy + oy], 1)
    Q = resample_closed(Q, args.step)
    Q = smooth_closed(Q, k=6, rounds=3)

    N = args.count
    tiles = []
    seg = np.linalg.norm(np.diff(np.vstack([Q, Q[:1]]), axis=0), axis=1)
    cum = np.concatenate([[0.0], np.cumsum(seg)])
    tot = cum[-1]
    for i in range(N):
        s = tot * i / N
        k = min(max(int(np.searchsorted(cum, s, "right") - 1), 0), len(seg) - 1)
        t = (s - cum[k]) / max(seg[k], 1e-9)
        q = Q[k] + (Q[(k + 1) % len(Q)] - Q[k]) * t
        px, py = float(q[0]), float(q[1])
        u = px / W
        vv = 1.0 - py / H
        tiles.append({
            "i": i, "px": round(px, 1), "py": round(py, 1),
            "u": round(u, 6), "v": round(vv, 6),
            "x": round((u - 0.5) * args.board, 4),
            "z": round((0.5 - vv) * args.board, 4),
        })
    ds = [math.hypot(tiles[i]["x"] - tiles[(i + 1) % N]["x"],
                     tiles[i]["z"] - tiles[(i + 1) % N]["z"]) for i in range(N)]
    print("格距(world): min %.2f  max %.2f  mean %.2f" % (min(ds), max(ds), sum(ds) / len(ds)))

    base = Image.open(te_path).convert("RGB")
    dr = ImageDraw.Draw(base)
    line = [(t["px"], t["py"]) for t in tiles] + [(tiles[0]["px"], tiles[0]["py"])]
    dr.line(line, fill=(255, 255, 0), width=2)
    for t in tiles:
        dr.ellipse([t["px"] - 4, t["py"] - 4, t["px"] + 4, t["py"] + 4],
                   fill=(255, 0, 0), outline=(0, 0, 0))
    base.save(".workbuddy/tex/_v3_check.png")
    print("-> .workbuddy/tex/_v3_check.png")

    if args.debug:
        return 0

    out = args.out or ("game/data/maps/%s_tilepos.json" % args.map)
    doc = {
        "_comment": "由原版小地图路线 + 线性拟合到 ditu 碎石带 + 等弧长采样重建（逆向，非原版原始路径数据）",
        "_source": "%s + %s" % (mm_path.replace("\\", "/"), te_path.replace("\\", "/")),
        "_image_size": [int(W), int(H)],
        "_board_size": args.board,
        "count": N,
        "_fit": {"sx": float(round(sx, 3)), "sy": float(round(sy, 3)),
                 "ox": float(round(ox, 1)), "oy": float(round(oy, 1)), "score": float(round(v, 4))},
        "path_total_px": float(round(tot, 1)),
        "tiles": tiles,
    }
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w", encoding="utf-8") as f:
        json.dump(doc, f, ensure_ascii=False, indent=1)
    print("-> %s" % out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
