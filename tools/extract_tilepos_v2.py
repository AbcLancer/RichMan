# -*- coding: utf-8 -*-
"""
extract_tilepos_v2.py —— 从原版棋盘美术 ditu.tga 反推地块坐标（不依赖 .r6m 未解字段）

思路（2026-09-26）：
  棋盘美术里「碎石路（石子带）」就是路线，玩家沿它走。所以地块坐标应当落在石子带的
  中轴线上。上一版用「红框锚点 + 样条 + 等弧重采样」，在锚点缺失处会漂移（实测偏 40px+）。

  本版改为：
    1. 用「局部标准差高 + 亮度低」把石子带抠出来（石子带纹理粗糙、比沙地暗）；
    2. 形态学闭运算 + 只保留最大连通域 → 得到一个闭合环带；
    3. 形态学骨架化 → 中轴线（1px 曲线）；
    4. 剪掉短毛刺，取最长路径，首尾相连成闭合环；
    5. 沿环等弧长放 N 个地块（N 取自原版 aiji.json / .r6m，埃及 111）。

用法：
    python tools/extract_tilepos_v2.py --map aiji --count 111 [--out game/data/maps/aiji_tilepos.json]
    python tools/extract_tilepos_v2.py --map aiji --count 111 --debug   # 只出叠加图，不写 json
"""

import argparse
import json
import os
import sys
from collections import deque

import numpy as np
from PIL import Image, ImageDraw


# ----------------------------------------------------------------- 基础算子

def integral(x):
    s = np.zeros((x.shape[0] + 1, x.shape[1] + 1), dtype=np.float64)
    s[1:, 1:] = np.cumsum(np.cumsum(x, 0), 1)
    return s


def boxsum(s, k):
    return s[k:, k:] - s[:-k, k:] - s[k:, :-k] + s[:-k, :-k]


def pad_to(v, h, w, k):
    hh, ww = k // 2, k // 2
    return np.pad(v, ((hh, h - v.shape[0] - hh), (ww, w - v.shape[1] - ww)), mode="edge")


def locstat(img, k):
    h, w = img.shape[0], img.shape[1]
    s1 = integral(img)
    s2 = integral(img * img)
    n = float(k * k)
    m = pad_to(boxsum(s1, k) / n, h, w, k)
    v = pad_to(boxsum(s2, k) / n, h, w, k) - m * m
    return m, np.sqrt(np.maximum(v, 0.0))


def dilate(b, k):
    """二值膨胀（k x k 结构元）"""
    h, w = b.shape
    s = integral(b.astype(np.float64))
    out = pad_to(boxsum(s, k), h, w, k)
    return out > 0


def erode(b, k):
    """二值腐蚀"""
    h, w = b.shape
    s = integral(b.astype(np.float64))
    out = pad_to(boxsum(s, k), h, w, k)
    return out >= (k * k - 1e-6)


def label(mask):
    """4/8 邻域连通域标记，返回 (labels, sizes)，纯 python BFS（骨架像素少，够用）"""
    h, w = mask.shape
    lab = np.zeros((h, w), dtype=np.int32)
    ys, xs = np.nonzero(mask)
    todo = set(zip(ys.tolist(), xs.tolist()))
    sizes = [0]
    cur = 0
    NB = ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (1, -1), (-1, 1), (-1, -1))
    while todo:
        cur += 1
        seed = todo.pop()
        q = deque([seed])
        lab[seed] = cur
        cnt = 1
        while q:
            y, x = q.popleft()
            for dy, dx in NB:
                p = (y + dy, x + dx)
                if p in todo:
                    todo.discard(p)
                    lab[p] = cur
                    cnt += 1
                    q.append(p)
        sizes.append(cnt)
    return lab, sizes


# ----------------------------------------------------------------- 石子带

def road_mask(rgb, std_k=11, std_th=25.0, mean_th=185.0, close_k=9):
    lum = rgb.mean(axis=2)
    m, sd = locstat(lum, std_k)
    bm = (sd > std_th) & (m < mean_th)
    bm = dilate(bm, close_k)                       # 闭运算：先膨胀
    bm = erode(bm, close_k) | bm
    lab, sizes = label(bm)
    if len(sizes) <= 1:
        return bm
    big = int(np.argmax(sizes[1:])) + 1
    return lab == big


def thin(mask, max_iter=120):
    """形态学骨架"""
    img = mask.copy()
    skel = np.zeros_like(mask)
    for _ in range(max_iter):
        er = erode(img, 3)
        if not er.any():
            break
        op = dilate(er, 3)
        skel |= img & (~op)
        img = er
    return skel


# ----------------------------------------------------------------- 骨架 → 有序环

def neighbors(y, x, S):
    out = []
    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (1, -1), (-1, 1), (-1, -1)):
        p = (y + dy, x + dx)
        if 0 <= p[0] < S.shape[0] and 0 <= p[1] < S.shape[1] and S[p]:
            out.append(p)
    return out


def prune(S, rounds=12):
    """反复删掉度<=1 的端点，剪掉毛刺"""
    S = S.copy()
    for _ in range(rounds):
        ys, xs = np.nonzero(S)
        ends = [(y, x) for y, x in zip(ys.tolist(), xs.tolist()) if len(neighbors(y, x, S)) <= 1]
        if not ends:
            break
        for p in ends:
            S[p] = False
    return S


def longest_path(S):
    """在骨架图上两遍 BFS 求最长路径（近似直径），返回像素点序"""
    ys, xs = np.nonzero(S)
    pts = list(zip(ys.tolist(), xs.tolist()))
    if not pts:
        return []
    pset = S

    def bfs(src):
        dist = {src: 0}
        par = {src: None}
        q = deque([src])
        far = src
        while q:
            cur = q.popleft()
            for nb in neighbors(cur[0], cur[1], pset):
                if nb not in dist:
                    dist[nb] = dist[cur] + 1
                    par[nb] = cur
                    if dist[nb] > dist[far]:
                        far = nb
                    q.append(nb)
        return far, par

    a, _ = bfs(pts[0])
    b, par = bfs(a)
    path = []
    cur = b
    while cur is not None:
        path.append(cur)
        cur = par[cur]
    path.reverse()
    return path


def order_loop(S, min_gap=6.0):
    """把骨架点排成闭合环（返回 [(y,x), ...]）"""
    path = longest_path(S)
    if len(path) < 5:
        return []
    return path


def resample(path, n):
    """沿折线等弧长取 n 个点（闭合）"""
    if len(path) < 2:
        return []
    pts = np.array([(p[1], p[0]) for p in path], dtype=np.float64)   # (x,y)
    seg = np.linalg.norm(np.diff(np.vstack([pts, pts[:1]]), axis=0), axis=1)
    total = seg.sum()
    if total <= 0:
        return []
    cum = np.concatenate([[0.0], np.cumsum(seg)])
    out = []
    for i in range(n):
        d = total * i / n
        k = int(np.searchsorted(cum, d, side="right") - 1)
        k = max(0, min(k, len(seg) - 1))
        t = (d - cum[k]) / max(seg[k], 1e-9)
        a = pts[k]
        b = pts[(k + 1) % len(pts)]
        out.append(a + (b - a) * t)
    return out


# ----------------------------------------------------------------- 主流程

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--map", default="aiji")
    ap.add_argument("--img", default=None, help="棋盘底图（png），默认 .workbuddy/tex/<map>.png")
    ap.add_argument("--count", type=int, default=111)
    ap.add_argument("--out", default=None)
    ap.add_argument("--board", type=float, default=200.0)
    ap.add_argument("--debug", action="store_true")
    ap.add_argument("--std-th", type=float, default=25.0)
    ap.add_argument("--mean-th", type=float, default=185.0)
    args = ap.parse_args()

    img_path = args.img or (".workbuddy/tex/%s.png" % args.map)
    im = Image.open(img_path).convert("RGB")
    rgb = np.asarray(im).astype(np.float64)
    H, W = rgb.shape[0], rgb.shape[1]
    print("图 %s  %dx%d" % (img_path, W, H))

    rm = road_mask(rgb, std_th=args.std_th, mean_th=args.mean_th)
    lab, sizes = label(rm)
    print("石子带最大连通域像素: %d" % int(rm.sum()))
    Image.fromarray((rm * 255).astype(np.uint8)).save(".workbuddy/tex/_v2_road.png")

    sk = thin(rm)
    print("骨架像素: %d" % int(sk.sum()))
    sk2 = prune(sk, rounds=10)
    print("剪枝后: %d" % int(sk2.sum()))
    Image.fromarray((sk2 * 255).astype(np.uint8)).save(".workbuddy/tex/_v2_skel.png")

    path = order_loop(sk2)
    print("环长(px): %d" % len(path))
    if len(path) < 10:
        print("!! 骨架太短，失败")
        return 1

    pts = resample(path, args.count)

    ov = im.convert("RGBA").copy()
    dr = ImageDraw.Draw(ov)
    for i, (x, y) in enumerate(pts):
        r = 6
        dr.ellipse([x - r, y - r, x + r, y + r], fill=(0, 255, 90, 230), outline=(0, 0, 0, 255))
    for i in range(0, len(path), 4):
        y, x = path[i]
        dr.point((x, y), fill=(255, 0, 0, 255))
    ov.convert("RGB").save(".workbuddy/tex/_v2_check.png")

    tiles = []
    for i, (px, py) in enumerate(pts):
        u = px / W
        v = 1.0 - py / H
        tiles.append({
            "i": i,
            "px": round(px, 1), "py": round(py, 1),
            "u": round(u, 6), "v": round(v, 6),
            "x": round((u - 0.5) * args.board, 4),
            "z": round((0.5 - v) * args.board, 4),
        })

    # 统计格距
    import math
    ds = []
    for i in range(len(tiles)):
        a = tiles[i]
        b = tiles[(i + 1) % len(tiles)]
        ds.append(math.hypot(a["x"] - b["x"], a["z"] - b["z"]))
    print("格距 world: min %.2f max %.2f mean %.2f" % (min(ds), max(ds), sum(ds) / len(ds)))

    if args.debug:
        print("--debug：不写 json")
        return 0

    out = args.out or ("game/data/maps/%s_tilepos.json" % args.map)
    doc = {
        "_comment": "由棋盘美术里的石子带（路线）骨架 + 等弧长采样重建的棋盘坐标",
        "_source": "%s（骨架提取）" % img_path.replace("\\", "/"),
        "_image_size": [W, H],
        "_board_size": args.board,
        "count": args.count,
        "tiles": tiles,
    }
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w", encoding="utf-8") as f:
        json.dump(doc, f, ensure_ascii=False, indent=1)
    print("-> %s" % out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
