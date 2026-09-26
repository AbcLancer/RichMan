# -*- coding: utf-8 -*-
"""用差分法定位原版光标精灵的真实绘制位置，并反解「请求坐标 -> 实际坐标」的映射。"""
import numpy as np
from PIL import Image

DIR = r"D:\Projects\RichMan\docs\screenshots\orig"
REQ = {"_curA": (200, 200), "_curB": (900, 650), "_curC": (500, 400)}

imgs = {k: np.asarray(Image.open(f"{DIR}\\{k}.png").convert("RGB"), dtype=np.int16) for k in REQ}
print("图像尺寸:", {k: v.shape for k, v in imgs.items()})


def blobs(a, b, thr=40):
    d = np.abs(a - b).sum(axis=2)
    ys, xs = np.nonzero(d > thr)
    if len(xs) == 0:
        return []
    # 简单连通聚类：按 x 距离排序分组
    pts = sorted(zip(xs, ys))
    groups = []
    cur = [pts[0]]
    for p in pts[1:]:
        if p[0] - cur[-1][0] <= 25:
            cur.append(p)
        else:
            groups.append(cur)
            cur = [p]
    groups.append(cur)
    out = []
    for g in groups:
        gx = [p[0] for p in g]
        gy = [p[1] for p in g]
        if len(g) < 30:
            continue
        out.append((sum(gx) / len(gx), sum(gy) / len(gy), min(gx), min(gy), len(g)))
    out.sort()
    return out


keys = list(REQ)
pairs = [(keys[0], keys[1]), (keys[0], keys[2]), (keys[1], keys[2])]
obs = []
for a, b in pairs:
    bl = blobs(imgs[a], imgs[b])
    print(f"\n差分 {a} vs {b}: 发现 {len(bl)} 个团块")
    for cx, cy, mx, my, n in bl:
        print(f"   质心=({cx:.1f},{cy:.1f}) 左上=({mx},{my}) 像素数={n}")
    if len(bl) == 2:
        ra, rb = REQ[a], REQ[b]
        lo, hi = bl if ra[0] < rb[0] else (bl[1], bl[0])
        obs.append((ra, (lo[0], lo[1])))
        obs.append((rb, (hi[0], hi[1])))

if len(obs) >= 4:
    A = np.array([[r[0], r[1], 1.0] for r, _ in obs])
    Bx = np.array([d[0] for _, d in obs])
    By = np.array([d[1] for _, d in obs])
    cx, *_ = np.linalg.lstsq(A, Bx, rcond=None)
    cy, *_ = np.linalg.lstsq(A, By, rcond=None)
    print("\n=== 映射 请求(x,y) -> 绘制(x,y) ===")
    print(f"  draw_x = {cx[0]:.5f}*x + {cx[1]:.5f}*y + {cx[2]:.2f}")
    print(f"  draw_y = {cy[0]:.5f}*x + {cy[1]:.5f}*y + {cy[2]:.2f}")
    for r, d in obs:
        px = cx[0] * r[0] + cx[1] * r[1] + cx[2]
        py = cy[0] * r[0] + cy[1] * r[1] + cy[2]
        print(f"  请求{r} -> 实测({d[0]:.0f},{d[1]:.0f}) 拟合({px:.0f},{py:.0f})")
    # 反解：想让光标出现在 draw 位置，应请求什么
    M = np.array([[cx[0], cx[1]], [cy[0], cy[1]]])
    try:
        Mi = np.linalg.inv(M)
        print("\n=== 反解 期望绘制位置 -> 应请求坐标 ===")
        for target in [(925, 674), (270, 270), (265, 572)]:
            v = np.array(target) - np.array([cx[2], cy[2]])
            r = Mi @ v
            print(f"  想在 {target} 看到光标 -> 请求 ({r[0]:.0f}, {r[1]:.0f})")
    except np.linalg.LinAlgError:
        print("矩阵不可逆")
else:
    print("观测不足，无法拟合")
