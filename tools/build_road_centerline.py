# -*- coding: utf-8 -*-
"""
由原版地形贴图重建棋盘格子坐标（最终方案）。

为什么不用「沿路追踪」：碎石路与沙地的亮度差太小（V≈0.78 vs 0.93 且沙地波动大），
按颜色分割会把整片沙漠都选进来。改用**红框锚点 + 闭合 Catmull-Rom 样条**：
红框本身就是编辑器标出的道路槽位，组内密集且贴合路面；组间空档（事件格位置）
用平滑样条过渡，视觉上与原版一致。

输入：game/data/maps/<map>_board.json（上一步的红框有序锚点）
输出：game/data/maps/<map>_tilepos.json
     .workbuddy/tex/_<map>_path.png（核对图，叠加在原版贴图上）
"""
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

OUT = r"D:\Projects\RichMan\game\data\maps"
SCENE = r"D:\Projects\RichMan\samples\scene"
CHK = r"D:\Projects\RichMan\.workbuddy\tex"

TILES = {"aiji": 111, "china": 96, "island": 56, "japan": 71, "paris": 96, "train": 51}
BOARD_SIZE = 200.0     # 贴图 0..1 映射到地面上 BOARD_SIZE 平方单位


def catmull_rom_closed(pts, samples_per_seg=24):
    """闭合 Catmull-Rom 样条：经过所有控制点。"""
    P = np.asarray(pts, dtype=float)
    n = len(P)
    out = []
    for i in range(n):
        p0 = P[(i - 1) % n]
        p1 = P[i]
        p2 = P[(i + 1) % n]
        p3 = P[(i + 2) % n]
        t = np.linspace(0.0, 1.0, samples_per_seg, endpoint=False).reshape(-1, 1)
        t2 = t * t
        t3 = t2 * t
        seg = 0.5 * ((2 * p1) +
                     (-p0 + p2) * t +
                     (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 +
                     (-p0 + 3 * p1 - 3 * p2 + p3) * t3)
        out.append(seg)
    return np.vstack(out)


def resample(pts, n):
    """按弧长等距重采样 n 个点（闭合曲线）。"""
    P = np.vstack([pts, pts[:1]])
    seg = np.linalg.norm(np.diff(P, axis=0), axis=1)
    arc = np.concatenate([[0.0], np.cumsum(seg)])
    total = arc[-1]
    out = []
    for k in range(n):
        tgt = total * k / n
        idx = int(np.searchsorted(arc, tgt))
        idx = min(max(idx, 1), len(arc) - 1)
        f = (tgt - arc[idx - 1]) / max(arc[idx] - arc[idx - 1], 1e-9)
        out.append(P[idx - 1] + (P[idx] - P[idx - 1]) * f)
    return np.array(out), total


def build(m, n_tiles):
    bj = os.path.join(OUT, f"{m}_board.json")
    if not os.path.exists(bj):
        print(f"[{m}] 缺 {m}_board.json，跳过")
        return
    data = json.load(open(bj, encoding="utf-8"))
    anchors = [(t["px"], t["py"]) for t in data["tiles"]]
    W, H = data["_image_size"]
    if len(anchors) < 8:
        print(f"[{m}] 锚点太少({len(anchors)})，跳过")
        return

    curve = catmull_rom_closed(anchors, samples_per_seg=40)
    tiles_pt, total = resample(curve, n_tiles)
    print(f"[{m}] 锚点 {len(anchors)} -> 样条 {len(curve)} 点，环长 {total:.0f}px，"
          f"重采样 {n_tiles} 格（格距 {total/n_tiles:.1f}px）")

    tiles = []
    for k, (x, y) in enumerate(tiles_pt):
        u = x / W
        vz = y / H
        tiles.append({
            "i": k,
            "u": round(float(u), 6),
            "v": round(float(1.0 - vz), 6),
            "px": round(float(x), 1), "py": round(float(y), 1),
            "x": round(float((u - 0.5) * BOARD_SIZE), 4),
            "z": round(float((0.5 - vz) * BOARD_SIZE), 4),
        })

    dst = os.path.join(OUT, f"{m}_tilepos.json")
    with open(dst, "w", encoding="utf-8") as f:
        json.dump({
            "_comment": "由红框锚点 + 闭合 Catmull-Rom 样条重建的棋盘坐标（逆向，非原版原始路径数据）",
            "_source": bj,
            "_image_size": [W, H],
            "_board_size": BOARD_SIZE,
            "count": n_tiles,
            "path_total_px": round(float(total), 1),
            "tiles": tiles,
        }, f, ensure_ascii=False, indent=1)

    # 核对图
    tex = os.path.join(SCENE, m, "ditu2_1024.tga")
    if os.path.exists(tex):
        im = Image.open(tex).convert("RGB")
        d = ImageDraw.Draw(im)
        d.line([(p[0], p[1]) for p in curve], fill=(0, 255, 0), width=2)
        for k in (0, 20, 40, 60, 80, 100):
            if k < len(tiles):
                t = tiles[k]
                d.ellipse([t["px"] - 6, t["py"] - 6, t["px"] + 6, t["py"] + 6],
                          outline=(255, 0, 255), width=3)
        im.save(os.path.join(CHK, f"_{m}_path.png"))
    print(f"  -> {dst}   核对图 _{m}_path.png")


def main():
    maps = sys.argv[1:] or ["aiji"]
    os.makedirs(CHK, exist_ok=True)
    for m in maps:
        build(m, TILES.get(m, 100))


if __name__ == "__main__":
    main()
