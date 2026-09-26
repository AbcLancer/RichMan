# -*- coding: utf-8 -*-
"""
bld_sheet.py —— 建筑贴图「根因隔离」对照表（议题 20，2026-09-26）

思路：同一栋建筑渲染两次，唯一变量是**贴图来源**：
  左列 = 原始 .pol 的 f4/f5 UV + 建筑目录里那张**原始 .tga**
  右列 = 同一套 f4/f5 UV + **工程里已发布的 game/assets/buildings/tex/<id>__*.png**
若左列正常、右列烂 → 根因在打包（snap_uv_to_content / bleed_atlas）；
若两列都烂 → 根因在 UV 语义本身。

用法：
    python tools/bld_sheet.py <out.png> <map: aiji> <id...>
"""
import glob
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pol_render2 as R  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SAMPLES = os.path.join(ROOT, "samples", "building")
SHIPPED = os.path.join(ROOT, "game", "assets", "buildings", "tex")


def pick_tga(bdir):
    for fn in sorted(os.listdir(bdir)):
        if fn.lower().endswith(".tga"):
            return os.path.join(bdir, fn)
    return None


def pick_shipped(bid):
    hits = sorted(glob.glob(os.path.join(SHIPPED, bid + "__*.png")))
    return hits[0] if hits else None


def main():
    from PIL import Image, ImageDraw
    out = sys.argv[1]
    ids = sys.argv[3:] if len(sys.argv) > 3 else ["a0101", "a0201", "a0304"]
    W, H = 380, 350
    rows = []
    for bid in ids:
        bdir = os.path.join(SAMPLES, bid)
        if not os.path.isdir(bdir):
            print("!! 缺目录 %s" % bdir)
            continue
        pos, uv, tri, tga = R.load(bdir)
        shop = pick_shipped(bid)
        tiles = []
        for tag, tex in (("raw .tga", tga), ("shipped png", shop)):
            tmp = os.path.join(ROOT, ".workbuddy", "_bs_%s_%s.png" % (bid, tag.replace(" ", "_").replace(".", "")))
            if tex is None:
                tiles.append((tag + " (缺失)", Image.new("RGB", (W, H), (30, 20, 20))))
                continue
            R.render(pos, uv, tri, tex, tmp, w=W, h=H)
            tiles.append((tag, Image.open(tmp).convert("RGB")))
        rows.append((bid, tiles))

    cols = len(rows[0][1]) if rows else 2
    sheet = Image.new("RGB", (cols * W, len(rows) * (H + 22)), (18, 18, 22))
    d = ImageDraw.Draw(sheet)
    for r, (bid, tiles) in enumerate(rows):
        y = r * (H + 22)
        d.text((6, y + 5), "%s   (pol f4/f5 UV, 无光照对齐)" % bid, fill=(235, 235, 245))
        for c, (tag, im) in enumerate(tiles):
            sheet.paste(im, (c * W, y + 22))
            d.text((c * W + 6, y + 22 + H - 14), tag, fill=(255, 230, 140))
    sheet.save(out)
    print("-> %s  (%d 栋 x %d 列)" % (out, len(rows), cols))


if __name__ == "__main__":
    main()
