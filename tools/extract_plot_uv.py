# -*- coding: utf-8 -*-
"""从原版地形贴图 ditu2_1024.tga 中自动提取地块（红色标注框）位置。

思路：编辑器版贴图用纯红框标出每个地块槽位。检出红色像素连通域，
取包围盒中心即得地块的贴图归一化坐标 (u,v)，v 已翻转为常规朝向。
输出：tools/../game/data/maps/<map>_plots_uv.json
"""
import json
import os
import sys

import numpy as np
from PIL import Image

SCENE = r"D:\Projects\RichMan\samples\scene"
OUT = r"D:\Projects\RichMan\game\data\maps"


def find_red_boxes(arr):
    r = arr[:, :, 0].astype(np.int16)
    g = arr[:, :, 1].astype(np.int16)
    b = arr[:, :, 2].astype(np.int16)
    # 只认「编辑器标注用的纯红」；壁画人物的红棕肤色饱和度低，会被排除
    mask = (r > 150) & (g < 70) & (b < 70) & (r - g > 90) & (r - b > 90)
    h, w = mask.shape
    seen = np.zeros_like(mask, dtype=bool)
    boxes = []
    # 迭代式洪泛（避免递归深度）
    ys, xs = np.nonzero(mask)
    for sy, sx in zip(ys, xs):
        if seen[sy, sx]:
            continue
        stack = [(sy, sx)]
        seen[sy, sx] = True
        minx = maxx = sx
        miny = maxy = sy
        n = 0
        while stack:
            y, x = stack.pop()
            n += 1
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
        if n >= 40:
            boxes.append((minx, miny, maxx, maxy, n))
    return boxes, w, h


def main():
    maps = sys.argv[1:] or ["aiji", "china", "island", "japan", "paris"]
    os.makedirs(OUT, exist_ok=True)
    for m in maps:
        cand = os.path.join(SCENE, m, "ditu2_1024.tga")
        if not os.path.exists(cand):
            cand = os.path.join(SCENE, m, "ditu2.tga")
        if not os.path.exists(cand):
            print(f"[{m}] 无 ditu2 贴图，跳过")
            continue
        arr = np.asarray(Image.open(cand).convert("RGB"))
        boxes, w, h = find_red_boxes(arr)
        # 过滤掉过大/过小的团块（红框应为地块大小的矩形）
        boxes = [b for b in boxes if 8 <= (b[2] - b[0]) <= 80 and 8 <= (b[3] - b[1]) <= 80]
        # 按行聚类排序：先 y 后 x
        boxes.sort(key=lambda b: (round(((b[1] + b[3]) / 2) / 40), (b[0] + b[2]) / 2))
        plots = []
        for minx, miny, maxx, maxy, n in boxes:
            cx = (minx + maxx) / 2 / w
            cy = (miny + maxy) / 2 / h
            plots.append({
                "u": round(cx, 5),
                "v": round(1.0 - cy, 5),   # 贴图 y 向下 -> 3D v 向上
                "w": round((maxx - minx) / w, 5),
                "h": round((maxy - miny) / h, 5),
                "src": os.path.basename(cand),
            })
        dst = os.path.join(OUT, f"{m}_plots_uv.json")
        with open(dst, "w", encoding="utf-8") as f:
            json.dump({
                "_comment": f"由 tools/extract_plot_uv.py 从原版 {os.path.basename(cand)} 自动提取",
                "_source": cand,
                "_image_size": [w, h],
                "count": len(plots),
                "plots": plots,
            }, f, ensure_ascii=False, indent=1)
        print(f"[{m}] 检出地块 {len(plots)} 个 -> {dst}")


if __name__ == "__main__":
    main()
