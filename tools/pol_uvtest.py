# -*- coding: utf-8 -*-
"""
pol_uvtest.py —— 用「候选 UV 字段对」各渲染一张，拼成对比图，肉眼挑出正确的那个。

用法：
  python tools/pol_uvtest.py <building_dir> <out.png>
示例：
  python tools/pol_uvtest.py samples/building/a0101 .workbuddy/uvtest_a0101.png
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pol2obj as P  # noqa: E402


def raw_fields(pol_path, nv):
    b = open(pol_path, "rb").read()
    return np.frombuffer(b, dtype="<f4", count=nv * 8, offset=144).reshape(nv, 8).astype(np.float64)


def main():
    bdir = sys.argv[1].rstrip("/\\")
    out = sys.argv[2]
    pol = os.path.join(bdir, "model.pol")
    g = P.load_pol(pol)
    nv = g["pos"].shape[0]
    raw = raw_fields(pol, nv)
    tex = P.find_tex(os.path.dirname(bdir), os.path.basename(bdir), g["tex"])

    # (标签, 源字段) —— 1-x 表示取反
    cands = [
        ("f4, f5   (当前导出)", (4, 5)),
        ("f5, f4   (旧导出)", (5, 4)),
        ("f4, 1-f5", (4, -5)),
        ("1-f4, f5", (-4, 5)),
        ("f5, 1-f4", (5, -4)),
        ("1-f5, f4", (-5, 4)),
        ("f0, f4", (0, 4)),
        ("f0, f5", (0, 5)),
    ]

    from PIL import Image, ImageDraw

    w, h = 320, 280
    cols = 4
    rows = (len(cands) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * w, rows * (h + 18)), (16, 16, 20))
    dr = ImageDraw.Draw(sheet)
    tmp = os.path.join(os.path.dirname(out), "_uvtest_tmp.png")

    for i, (label, (ui, vi)) in enumerate(cands):
        u = raw[:, abs(ui)].copy()
        v = raw[:, abs(vi)].copy()
        if ui < 0:
            u = 1.0 - u
        if vi < 0:
            v = 1.0 - v
        g["uv"] = np.stack([u, v], axis=1)
        P.render_textured(g, tex, tmp, w, h)
        r, c = divmod(i, cols)
        sheet.paste(Image.open(tmp), (c * w, r * (h + 18) + 18))
        dr.text((c * w + 5, r * (h + 18) + 4), label, fill=(225, 225, 235))

    os.makedirs(os.path.dirname(out), exist_ok=True)
    sheet.save(out)
    print("-> %s   (tex=%s, nv=%d tri=%d)" % (out, os.path.basename(tex) if tex else "-", nv, len(g["tri"])))


if __name__ == "__main__":
    main()
