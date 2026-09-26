# -*- coding: utf-8 -*-
"""
pol_render2.py —— 高分辨率渲染单栋建筑，用于人工判定 UV 是否正确。

与 pol2obj.render_textured 的差别：
  * 支持任意 (u 字段, v 字段, 是否翻转 u, 是否翻转 v)
  * 输出大图（默认 760x700），带简单朗伯光照 + 环境光，便于肉眼看结构
  * 可选多机位（前 / 3/4 / 俯）

用法：
  python tools/pol_render2.py <building_dir> <out.png> [u] [v] [flags]
  flags: fu(翻 u) fv(翻 v) swap(用 f5/f4)
"""
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import r6pol  # noqa: E402
import pol2obj as P  # noqa: E402

HEADER = 144


def load(bdir):
    pol = os.path.join(bdir, "model.pol")
    b = open(pol, "rb").read()
    m = r6pol.parse(pol)
    nv = m["nv"]
    f = np.frombuffer(b, dtype="<f4", count=nv * 8, offset=HEADER).reshape(nv, 8).astype(np.float64)
    tri = np.asarray(m["indices"], dtype=np.int64).reshape(-1, 3)
    tri = tri[(tri < nv).all(axis=1)]
    tex = None
    for fn in sorted(os.listdir(bdir)):
        if fn.lower().endswith(".tga"):
            tex = os.path.join(bdir, fn)
            break
    return f[:, 1:4], f[:, [4, 5]], tri, tex


def render(pos, uv, tri, tex, out, w=760, h=700, yaw=38.0, pitch=24.0):
    from PIL import Image

    P3 = pos[tri]
    ca, sa = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
    cb, sb = math.cos(math.radians(pitch)), math.sin(math.radians(pitch))
    # 以模型中心为原点
    ctr = (pos.min(0) + pos.max(0)) / 2.0
    Q = pos - ctr
    X = Q[:, 0] * ca - Q[:, 2] * sa
    Z = Q[:, 0] * sa + Q[:, 2] * ca
    Y = Q[:, 1] * cb - Z * sb
    Zc = Q[:, 1] * sb + Z * cb
    S = np.stack([X, -Zc], axis=1)
    span = max(float(np.ptp(S[:, 0])), float(np.ptp(S[:, 1])), 1e-6)
    k = min(w, h) * 0.84 / span
    scr = np.stack([S[:, 0] * k + w / 2.0, S[:, 1] * k + h / 2.0], axis=1)

    T = np.asarray(Image.open(tex).convert("RGB")).astype(np.float64) if tex else np.full((8, 8, 3), 190.0)
    th, tw = T.shape[:2]
    img = np.full((h, w, 3), 26.0)
    z = np.full((h, w), 1e18)

    fn = np.cross(P3[:, 1] - P3[:, 0], P3[:, 2] - P3[:, 0])
    fn /= np.maximum(np.linalg.norm(fn, axis=1, keepdims=True), 1e-12)

    for i in range(len(tri)):
        t = tri[i]
        p0, p1, p2 = scr[t[0]], scr[t[1]], scr[t[2]]
        z0, z1, z2 = Zc[t[0]], Zc[t[1]], Zc[t[2]]
        x0, x1 = max(int(min(p0[0], p1[0], p2[0])), 0), min(int(max(p0[0], p1[0], p2[0])) + 1, w)
        y0, y1 = max(int(min(p0[1], p1[1], p2[1])), 0), min(int(max(p0[1], p1[1], p2[1])) + 1, h)
        if x1 <= x0 or y1 <= y0:
            continue
        xs, ys = np.meshgrid(np.arange(x0, x1) + 0.5, np.arange(y0, y1) + 0.5)
        d = (p1[1] - p2[1]) * (p0[0] - p2[0]) + (p2[0] - p1[0]) * (p0[1] - p2[1])
        if abs(d) < 1e-9:
            continue
        l0 = ((p1[1] - p2[1]) * (xs - p2[0]) + (p2[0] - p1[0]) * (ys - p2[1])) / d
        l1 = ((p2[1] - p0[1]) * (xs - p2[0]) + (p0[0] - p2[0]) * (ys - p2[1])) / d
        l2 = 1.0 - l0 - l1
        ins = (l0 >= 0) & (l1 >= 0) & (l2 >= 0)
        if not ins.any():
            continue
        zz = l0 * z0 + l1 * z1 + l2 * z2
        sub = z[y0:y1, x0:x1]
        up = ins & (zz < sub)
        if not up.any():
            continue
        sub[up] = zz[up]
        u = l0 * uv[t[0], 0] + l1 * uv[t[1], 0] + l2 * uv[t[2], 0]
        v = l0 * uv[t[0], 1] + l1 * uv[t[1], 1] + l2 * uv[t[2], 1]
        tx = np.clip((u * tw).astype(np.int64), 0, tw - 1)
        ty = np.clip(((1.0 - v) * th).astype(np.int64), 0, th - 1)
        col = T[ty, tx]
        n = fn[i]
        lam = 0.62 + 0.38 * max(0.0, float(-n[0] * 0.45 - n[2] * 0.55 + n[1] * 0.70))
        blk = img[y0:y1, x0:x1]
        blk[:] = np.where(up[..., None], np.clip(col * lam, 0, 255), blk)

    Image.fromarray(img.astype(np.uint8)).save(out)
    return out


def main():
    bdir = sys.argv[1].rstrip("/\\")
    out = sys.argv[2]
    flags = set(sys.argv[3:])
    pos, uv, tri, tex = load(bdir)
    u, v = uv[:, 0].copy(), uv[:, 1].copy()
    if "swap" in flags:
        u, v = uv[:, 1].copy(), uv[:, 0].copy()
    if "fu" in flags:
        u = 1.0 - u
    if "fv" in flags:
        v = 1.0 - v
    render(pos, np.stack([u, v], 1), tri, tex, out)
    print("-> %s  (%s  uv=(%s) tri=%d tex=%s)" % (out, bdir, ",".join(sys.argv[3:]) or "raw", len(tri), os.path.basename(tex)))


if __name__ == "__main__":
    main()
