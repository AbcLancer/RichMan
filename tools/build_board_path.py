# -*- coding: utf-8 -*-
"""
从原版地形贴图重建棋盘路径（地块顺序坐标）。

原版把整张棋盘画进 1024×1024 的 `ditu2_1024.tga`，并用红框标出每个地块槽位。
本工具：
  1. 检出红框（纯红连通域），把相邻框粘连形成的长条按标准框宽切分开
  2. 用「最近邻 + 方向连续性」把地块串成一条路径（棋盘是环）
  3. 输出 game/data/maps/<map>_board.json：每个格子的贴图坐标 (u,v)
  4. 画出连线图供人工核对 -> .workbuddy/tex/_board_check.png

注意：这是**逆向重建**，不是原版原始数据。原版真实路径在 `.r6m` 里，
尚未完全解出（见 docs/decision-log.md）。
"""
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

SCENE = r"D:\Projects\RichMan\samples\scene"
OUT = r"D:\Projects\RichMan\game\data\maps"
CHK = r"D:\Projects\RichMan\.workbuddy\tex"

# 各地图总格数（tools/build_map.py 产出）
TILES = {"aiji": 111, "china": 96, "island": 56, "japan": 71, "paris": 96, "train": 51}


def red_mask(arr):
    r = arr[:, :, 0].astype(np.int16)
    g = arr[:, :, 1].astype(np.int16)
    b = arr[:, :, 2].astype(np.int16)
    return (r > 150) & (g < 70) & (b < 70) & (r - g > 90) & (r - b > 90)


def components(mask):
    """返回连通域列表 [(minx,miny,maxx,maxy,pixels)]（4 邻域，迭代式洪泛）。"""
    h, w = mask.shape
    seen = np.zeros_like(mask, dtype=bool)
    out = []
    ys, xs = np.nonzero(mask)
    for sy, sx in zip(ys, xs):
        if seen[sy, sx]:
            continue
        stack = [(sy, sx)]
        seen[sy, sx] = True
        minx = maxx = sx
        miny = maxy = sy
        px = []
        while stack:
            y, x = stack.pop()
            px.append((x, y))
            if x < minx:
                minx = x
            if x > maxx:
                maxx = x
            if y < miny:
                miny = y
            if y > maxy:
                maxy = y
            for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                ny, nx = y + dy, x + dx
                if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not seen[ny, nx]:
                    seen[ny, nx] = True
                    stack.append((ny, nx))
        if len(px) >= 40:
            out.append((minx, miny, maxx, maxy, px))
    return out


def split_boxes(comps, std):
    """把粘连成长条的连通域按标准框尺寸切成单格。"""
    boxes = []
    for minx, miny, maxx, maxy, px in comps:
        bw = maxx - minx + 1
        bh = maxy - miny + 1
        nx = max(1, int(round(bw / std)))
        ny = max(1, int(round(bh / std)))
        for iy in range(ny):
            for ix in range(nx):
                # 用该子格内实际红色像素的质心更准
                sub = [(x, y) for (x, y) in px
                       if minx + ix * bw / nx <= x < minx + (ix + 1) * bw / nx
                       and miny + iy * bh / ny <= y < miny + (iy + 1) * bh / ny]
                if len(sub) < 15:
                    continue
                cx = sum(p[0] for p in sub) / len(sub)
                cy = sum(p[1] for p in sub) / len(sub)
                boxes.append((cx, cy))
    return boxes


def two_opt(order, pts, iters=200):
    """对环形顺序做 2-opt：反复翻转片段，缩短总路程、解开自交。"""
    pts = np.array(pts, dtype=float)
    best = list(order)
    n = len(best)

    def total(seq):
        s = 0.0
        for i in range(n):
            s += np.linalg.norm(pts[seq[i]] - pts[seq[(i + 1) % n]])
        return s

    cur = total(best)
    improved = True
    rounds = 0
    while improved and rounds < iters:
        improved = False
        rounds += 1
        for i in range(n - 1):
            for j in range(i + 2, n):
                if i == 0 and j == n - 1:
                    continue
                cand = best[:i + 1] + best[i + 1:j + 1][::-1] + best[j + 1:]
                t = total(cand)
                if t < cur - 1e-9:
                    best, cur, improved = cand, t, True
        # 环形等价起点轮换：顺带尝试整体反向
        rev = [best[0]] + best[1:][::-1]
        t = total(rev)
        if t < cur - 1e-9:
            best, cur = rev, t
            improved = True
    return best, cur


def chain(points, prefer_dir=None):
    """最近邻 + 方向连续性，把点串成环。"""
    n = len(points)
    pts = np.array(points, dtype=float)
    remaining = set(range(n))
    # 起点：最靠左上（y 最小，其次 x 最小）
    start = int(np.lexsort((pts[:, 0], pts[:, 1]))[0])
    order = [start]
    remaining.discard(start)
    while remaining:
        cur = pts[order[-1]]
        if len(order) >= 2:
            d = cur - pts[order[-2]]
            nd = np.linalg.norm(d)
            d = d / nd if nd > 1e-6 else np.array([1.0, 0.0])
        else:
            d = None
        best, best_score = None, None
        for j in remaining:
            v = pts[j] - cur
            dist = np.linalg.norm(v)
            if dist < 1e-6:
                continue
            score = dist
            if d is not None:
                cos = float(np.dot(v / dist, d))
                # 鼓励方向延续：背离当前行进方向的候选加惩罚
                score *= (1.0 + 1.6 * max(0.0, 1.0 - cos))
            if best_score is None or score < best_score:
                best, best_score = j, score
        order.append(best)
        remaining.discard(best)
    return order


def main():
    maps = sys.argv[1:] or ["aiji"]
    os.makedirs(CHK, exist_ok=True)
    for m in maps:
        p = os.path.join(SCENE, m, "ditu2_1024.tga")
        if not os.path.exists(p):
            print(f"[{m}] 无 ditu2_1024.tga，跳过")
            continue
        im = Image.open(p).convert("RGB")
        W, H = im.size
        arr = np.asarray(im)
        comps = components(red_mask(arr))
        # 标准框尺寸：取各连通域中「最短边」的中位数
        sides = sorted(min(c[2] - c[0] + 1, c[3] - c[1] + 1) for c in comps)
        std = sides[len(sides) // 2]
        boxes = split_boxes(comps, std)
        print(f"[{m}] 连通域 {len(comps)}  标准框宽 {std}  切分后单格 {len(boxes)}  期望 {TILES.get(m)}")

        order = chain(boxes)
        order, tour_len = two_opt(order, boxes)
        ordered = [boxes[i] for i in order]
        print(f"  2-opt 后环长 {tour_len:.0f}px")

        # 画核对图
        dbg = im.copy()
        d = ImageDraw.Draw(dbg)
        path = [(x, y) for x, y in ordered]
        if len(path) > 1:
            d.line(path, fill=(0, 255, 0), width=3)
            d.line([path[-1], path[0]], fill=(0, 128, 255), width=2)
        for i, (x, y) in enumerate(path):
            d.ellipse([x - 5, y - 5, x + 5, y + 5], outline=(255, 255, 0), width=2)
            if i % 5 == 0:
                d.text((x + 7, y - 6), str(i), fill=(0, 0, 255))
        dbg.save(os.path.join(CHK, f"_{m}_board_check.png"))

        # 落盘
        norm = [{"i": i, "u": round(x / W, 5), "v": round(1.0 - y / H, 5),
                 "px": round(x, 1), "py": round(y, 1)} for i, (x, y) in enumerate(path)]
        dst = os.path.join(OUT, f"{m}_board.json")
        with open(dst, "w", encoding="utf-8") as f:
            json.dump({
                "_comment": "逆向重建的棋盘路径（从 ditu2_1024.tga 红框提取 + 沿路排序），非原版原始数据",
                "_source": p,
                "_image_size": [W, H],
                "_note": "u,v 为贴图归一化坐标；v 已翻转（3D 里向上为正）",
                "count": len(norm),
                "expected_tiles": TILES.get(m),
                "tiles": norm,
            }, f, ensure_ascii=False, indent=1)
        print(f"  -> {dst}  核对图 {m}_board_check.png")


if __name__ == "__main__":
    main()
