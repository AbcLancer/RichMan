# -*- coding: utf-8 -*-
"""
pol_uvlayout.py —— 把 .pol 的 UV 三角形直接叠画到贴图图集上，用来判定 UV 字段对不对。

判据：
  * UV 正确  → 三角面应规整地铺在图集上、边对齐色块、互不穿插
  * UV 错误  → 三角形乱成一团、大面积压在白色留白上

用法：
  python tools/pol_uvlayout.py <building_dir> <out.png> [u_field] [v_field] [--flipv]
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import r6pol  # noqa: E402
import pol2obj as P  # noqa: E402

HEADER = 144


def main():
    bdir = sys.argv[1].rstrip("/\\")
    out = sys.argv[2]
    uf = int(sys.argv[3]) if len(sys.argv) > 3 else 4
    vf = int(sys.argv[4]) if len(sys.argv) > 4 else 5
    flipv = "--flipv" in sys.argv

    pol = os.path.join(bdir, "model.pol")
    b = open(pol, "rb").read()
    m = r6pol.parse(pol)
    nv = m["nv"]
    raw = np.frombuffer(b, dtype="<f4", count=nv * 8, offset=HEADER).reshape(nv, 8).astype(np.float64)
    tri = np.asarray(m["indices"], dtype=np.int64).reshape(-1, 3)
    tri = tri[(tri < nv).all(axis=1)]

    tex = P.find_tex(os.path.dirname(bdir), os.path.basename(bdir), m.get("tex_name") or None)
    if tex is None:
        for f in sorted(os.listdir(bdir)):
            if f.lower().endswith(".tga"):
                tex = os.path.join(bdir, f)
                break

    from PIL import Image, ImageDraw

    S = 700
    base = Image.open(tex).convert("RGB").resize((S, S), Image.NEAREST)
    dr = ImageDraw.Draw(base)

    u = raw[:, uf]
    v = raw[:, vf]
    if flipv:
        v = -v

    umin, umax, vmin, vmax = u.min(), u.max(), v.min(), v.max()
    print("u[%.4f, %.4f]  v[%.4f, %.4f]" % (umin, umax, vmin, vmax))

    # 归一化到画布（保持比例，把 [umin,umax]x[vmin,vmax] 映射到画布）
    span = max(umax - umin, vmax - vmin, 1e-6)
    k = S / span

    def px(i):
        return (u[i] - umin) * k, S - (v[i] - vmin) * k

    for idx, t in enumerate(tri):
        pts = [px(i) for i in t]
        col = (255, 40, 40) if idx % 2 == 0 else (40, 120, 255)
        dr.polygon(pts, outline=col)
    base.save(out)
    print("-> %s  (u=f%d v=f%d flipv=%s, %d tri, tex=%s)"
          % (out, uf, vf, flipv, len(tri), os.path.basename(tex)))


if __name__ == "__main__":
    main()
