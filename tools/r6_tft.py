#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""解原版点阵字体 `gbdata/*.tft`（TNFT）→ Godot 可用的 BMFont（.fnt + .png）。

## TNFT 格式（已定死，文件大小精确吻合）

    偏移 0   : "TNFT"                4 字节魔数
    偏移 4   : u32 版本 = 1
    偏移 8   : u32 字高 px（16 / 24）
    偏移 12  : u32 = 1
    偏移 16  : u32 字形数 = 65536     （完整 Unicode BMP）
    偏移 20  : 字形位图，字形数 × (px*px/8) 字节
               每个字形 = px×px **1bpp**，行主序、每行 ceil(px/8) 字节、
               **MSB 在左**；字形是固定字框（无逐字宽度）

校验：unicode16 = 20 + 65536×32 = 2097172 ✓；unicode24 = 20 + 65536×72 = 4718612 ✓

## 输出

    game/assets/fonts/r6_24.{fnt,png}      正文 24px（ASCII + GB2312 + 全角/标点）
    game/assets/fonts/r6_16.{fnt,png}      正文 16px（同上）
    game/assets/fonts/hud_num24.{fnt,png}  顶栏数字（0-9 / x）：白字 + 深蓝描边，
                                           **已烘进颜色**，用法 modulate=白

用法：
    python tools/r6_tft.py                # 全部
    python tools/r6_tft.py --px 24        # 只做 24
    python tools/r6_tft.py --check        # 额外输出复核图到 .workbuddy/tmp/
"""
from __future__ import annotations

import argparse
import os
import struct
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "samples", "gbdata")
OUT = os.path.join(ROOT, "game", "assets", "fonts")
TMP = os.path.join(ROOT, ".workbuddy", "tmp")

HDR = 20
OUTLINE_RGB = (17, 34, 187)      # 顶栏数字描边色（实测自原版截图）


# --------------------------------------------------------------------- 解码
def load_tft(path: str) -> tuple[int, np.ndarray]:
    """→ (字高 px, 形状 (65536, px, px) 的 bool 位图)"""
    d = open(path, "rb").read()
    if d[:4] != b"TNFT":
        raise ValueError("%s 不是 TNFT" % path)
    _ver, px, _one, count = struct.unpack_from("<4I", d, 4)
    if count != 65536:
        raise ValueError("字形数不是 65536：%d" % count)
    stride = px // 8
    raw = np.frombuffer(d, dtype=np.uint8, count=count * px * stride, offset=HDR)
    bits = np.unpackbits(raw.reshape(count * px, stride), axis=1)   # MSB 在左
    return px, bits.reshape(count, px, px).astype(bool)


# ------------------------------------------------------------------ 字符集
def charset() -> list[int]:
    """ASCII + GB2312 全字符集 + 常用符号 → 码点（去重升序）。"""
    cps: set[int] = set(range(0x20, 0x7F))
    # GB2312：区 1..9 是符号区，16..87 是汉字区
    for hi in range(0xA1, 0xF8):
        for lo in range(0xA1, 0xFF):
            try:
                ch = bytes((hi, lo)).decode("gb2312")
            except UnicodeDecodeError:
                continue
            if len(ch) == 1:
                cps.add(ord(ch))
    cps.update(range(0x3000, 0x3040))          # CJK 标点
    cps.update((0x00B7, 0x2018, 0x2019, 0x201C, 0x201D, 0x2026, 0x2014,
                0x00D7, 0x00F7, 0x00B0, 0x2103, 0x00A5, 0x00A7))
    cps.update(range(0xFF01, 0xFF61))          # 全角
    return sorted(c for c in cps if 0 <= c < 65536)


def ink_bbox(g: np.ndarray) -> tuple[int, int, int, int] | None:
    rs = np.where(g.any(axis=1))[0]
    cs = np.where(g.any(axis=0))[0]
    if rs.size == 0:
        return None
    return int(cs.min()), int(rs.min()), int(cs.max()), int(rs.max())


def advance_of(g: np.ndarray, px: int, cps: int) -> int:
    """固定字框字体：CJK/全角走满宽，ASCII 用墨迹宽 +1（近似比例字体）。"""
    if cps >= 0x2E80 or 0x3000 <= cps <= 0x303F or cps >= 0xFF01:
        return px
    bb = ink_bbox(g)
    if bb is None:
        return px // 2
    return min(px, int(bb[2] - bb[0] + 1) + 1)


def pack(px: int, bits: np.ndarray, cps: list[int], colorize: bool) -> tuple:
    """把选中字形打进网格图。colorize=True 时烘「白字 + 深蓝描边」。"""
    cells = []
    for c in cps:
        bb = ink_bbox(bits[c])
        if bb is None:
            continue
        cells.append((c, bb))
    if not cells:
        raise RuntimeError("没有可打包的字形")
    cw = max(bb[2] - bb[0] + 1 for _, bb in cells) + (2 if colorize else 0)
    chh = max(bb[3] - bb[1] + 1 for _, bb in cells) + (2 if colorize else 0)
    cols = 16 if len(cells) <= 256 else 128
    rows = (len(cells) + cols - 1) // cols
    W, H = cols * cw, rows * chh
    atlas = np.zeros((H, W, 4), np.uint8)
    recs = []
    for i, (c, bb) in enumerate(cells):
        x0, y0, x1, y1 = bb
        g = bits[c][y0:y1 + 1, x0:x1 + 1]
        gh, gw = g.shape
        col, row = i % cols, i // cols
        ax, ay = col * cw, row * chh          # 描边版的 1px 余量在 tile 内部
        if colorize:
            tile = np.zeros((gh + 2, gw + 2), bool)
            tile[1:-1, 1:-1] = g
            dil = tile.copy()
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    if dx or dy:
                        dil |= np.roll(np.roll(tile, dy, 0), dx, 1)
            a = np.zeros((gh + 2, gw + 2, 4), np.uint8)
            a[dil] = (*OUTLINE_RGB, 255)
            a[tile] = (255, 255, 255, 255)
            atlas[ay:ay + gh + 2, ax:ax + gw + 2] = a
            recs.append((c, ax, ay, gw + 2, gh + 2, -1, -1))
        else:
            a = np.zeros((gh, gw, 4), np.uint8)
            a[g] = (255, 255, 255, 255)
            atlas[ay:ay + gh, ax:ax + gw] = a
            recs.append((c, ax, ay, gw, gh, 0, 0))
    adv = {c: advance_of(bits[c], px, c) for c in cps}
    return atlas, recs, adv, (W, H), cw, chh


def write_fnt(path: str, png_name: str, px: int, W: int, H: int, recs, adv, colorize: bool) -> None:
    base = int(round(px * 0.79))          # 基线（经验值，观感对齐）
    lines = [
        'info face="r6_%d" size=%d bold=0 italic=0 charset="" unicode=1 '
        'stretchH=100 smooth=0 aa=1 padding=0,0,0,0 spacing=0,0 outline=0' % (px, px),
        "common lineHeight=%d base=%d scaleW=%d scaleH=%d pages=1 packed=0 "
        "alphaChnl=0 redChnl=4 greenChnl=4 blueChnl=4" % (px, base, W, H),
        'page id=0 file="%s"' % png_name,
        "chars count=%d" % len(recs),
    ]
    for (c, x, y, w, h, ox, oy) in recs:
        lines.append("char id=%d x=%d y=%d width=%d height=%d xoffset=%d yoffset=%d "
                     "xadvance=%d page=0 chnl=15" % (c, x, y, w, h, ox, oy, adv.get(c, px)))
    lines.append("kernings count=0")
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")


def build(px: int, check: bool) -> str:
    bits = load_tft(os.path.join(SRC, "unicode%d.tft" % px))[1]
    os.makedirs(OUT, exist_ok=True)
    cps = charset()
    atlas, recs, adv, (W, H), cw, chh = pack(px, bits, cps, colorize=False)
    img = Image.fromarray(atlas, "RGBA")
    png = "r6_%d.png" % px
    img.save(os.path.join(OUT, png))
    write_fnt(os.path.join(OUT, "r6_%d.fnt" % px), png, px, W, H, recs, adv, False)
    print("r6_%d: %d 字形 图集 %d×%d 单元格 %d×%d → %.2f MB" %
          (px, len(recs), W, H, cw, chh, W * H * 4 / 1048576))

    # 顶栏数字专用（白字 + 深蓝描边），字形数很少
    num_cps = list(range(0x30, 0x3A)) + [ord("/"), ord("x"), ord("%"), ord(",")]
    a2, r2, ad2, (W2, H2), _, _ = pack(px, bits, num_cps, colorize=True)
    Image.fromarray(a2, "RGBA").save(os.path.join(OUT, "hud_num%d.png" % px))
    write_fnt(os.path.join(OUT, "hud_num%d.fnt" % px), "hud_num%d.png" % px, px, W2, H2, r2, ad2, True)
    print("hud_num%d: %d 字形 %d×%d" % (px, len(r2), W2, H2))

    if check:
        os.makedirs(TMP, exist_ok=True)
        vw, vh = min(W, 1400), min(H, 900)
        strip = Image.new("RGB", (vw, vh), (24, 26, 32))
        strip.paste(img.crop((0, 0, vw, vh)), (0, 0), img.crop((0, 0, vw, vh)))
        strip = strip.resize((vw * 2, vh * 2), Image.NEAREST)
        strip.save(os.path.join(TMP, "font_check_%d.png" % px))
    return png


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--px", type=int, default=0, choices=[0, 16, 24])
    ap.add_argument("--check", action="store_true")
    a = ap.parse_args()
    todo = [a.px] if a.px else [24, 16]
    for px in todo:
        build(px, a.check)
    print("→", OUT)
    return 0


if __name__ == "__main__":
    sys.exit(main())
