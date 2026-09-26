# -*- coding: utf-8 -*-
"""
在 .r6m 街道表之后自动搜索「地块/路径坐标表」。

思路：网格记录应是 (x,?,z) 这样的浮点，按路径顺序排列。
判据：
  1. 记录数 >= 40
  2. 相邻点间距的变异系数小（路径是连续的）
  3. 点集有实际跨度（不是全零/全同）
  4. 首尾接近（棋盘是环）
对每个候选步长与字段偏移打分，取最高分。
"""
import os
import struct
import sys

import numpy as np

MAPS = ["aiji", "china", "island", "japan", "paris", "train"]

# 各地图实际格数（由 tools/build_map.py 产出）
TILES = {"aiji": 111, "china": 96, "island": 56, "japan": 71,
         "paris": 96, "train": 51, "space": 6, "trybuild": 21}


def parse_head(d):
    z = d.index(b"\0", 0x50)
    p = z + 1
    while p < len(d) and d[p] == 0xCD:
        p += 1
    _z2, n = struct.unpack("<II", d[p:p + 8])
    sp = p + 8
    streets = []
    for i in range(n):
        s = d[sp + i * 16: sp + i * 16 + 16].split(b"\0")[0]
        try:
            streets.append(s.decode("gbk"))
        except UnicodeDecodeError:
            streets.append("<bad>")
    return sp + n * 16, n, streets


def score_path(pts):
    """给一组 2D 点打分：越像「连续环形路径」分越高。"""
    if len(pts) < 20:
        return -1.0
    d = np.linalg.norm(np.diff(pts, axis=0), axis=1)
    if d.mean() <= 1e-6:
        return -1.0
    cv = d.std() / d.mean()               # 间距一致性
    span = pts.max(axis=0) - pts.min(axis=0)
    if min(span) < 5.0:
        return -1.0
    # 点应基本不重复
    uniq = len(np.unique(np.round(pts, 3), axis=0))
    if uniq < len(pts) * 0.8:
        return -1.0
    loop = np.linalg.norm(pts[0] - pts[-1]) / max(d.mean() * 3.0, 1e-6)
    s = 0.0
    s += 2.0 / (1.0 + cv)                 # 间距越均匀越好
    s += 1.0 / (1.0 + loop)               # 首尾越近越好
    s += min(span) / (span.max() + 1e-6)  # 长宽比
    s -= abs(np.abs(pts).max() - 500) / 5000.0   # 尺度接近「几百」量级
    return s


def main():
    base = sys.argv[1] if len(sys.argv) > 1 else "samples/scene"
    for m in MAPS:
        p = os.path.join(base, m, m + ".r6m")
        if not os.path.exists(p):
            continue
        d = open(p, "rb").read()
        after, n, streets = parse_head(d)
        rest = len(d) - after
        n_tile = TILES.get(m, 0)
        print(f"=== {m}: size={len(d)} streets={n} after=0x{after:X} rest={rest} 期望格数={n_tile}")
        best = None
        # 候选步长：记录若是 (x,y,z)+n*4 字节
        for stride in range(4, 65, 4):
            if rest < stride * 40:
                continue
            cnt = rest // stride
            for fld in range(0, min(stride - 7, 25), 4):
                arr = np.frombuffer(d, dtype="<f4", count=cnt * stride // 4,
                                    offset=after + fld)
                pts = arr.reshape(cnt, stride // 4)[:, :2].astype(np.float64)
                if not np.isfinite(pts).all():
                    continue
                sc = score_path(pts)
                if sc > 0 and (best is None or sc > best[0]):
                    best = (sc, stride, fld, cnt)
        if best:
            sc, stride, fld, cnt = best
            print(f"    最佳候选: 步长={stride} 字段偏移={fld} 记录数={cnt} 得分={sc:.3f}")
            if n_tile and cnt >= n_tile:
                arr = np.frombuffer(d, dtype="<f4", count=cnt * stride // 4, offset=after + fld)
                pts = arr.reshape(cnt, stride // 4)[:, :2].astype(np.float64)
                print(f"    前 6 点: " + " ".join(f"({x:.1f},{y:.1f})" for x, y in pts[:6]))
                print(f"    后 3 点: " + " ".join(f"({x:.1f},{y:.1f})" for x, y in pts[-3:]))
        else:
            print("    未找到候选")
        print(f"    街道表后 48 字节: {d[after:after+48].hex(' ')}")


if __name__ == "__main__":
    main()
