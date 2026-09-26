#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""从原版素材/参考截图里切出 HUD 贴图 → game/assets/ui/hud/

来源分两类（都写进 hud.json 的 _source 以便溯源）：
  1) uitex/other/number1.tga（原版顶栏用的粗体白字+深蓝描边，4 列 × 3 行）
     → num_0..9 / num_x
  2) 原版实机截图（原版没把顶栏底条/图徽做成贴图，是程序绘制的）：
     - docs/screenshots/orig/07_牌桌.png（1536×1152 = 原版 1024×768 的 1.5 倍）
       → coin1..coin5（计数项图徽椭圆）、btnstrip（右侧暂停/放大镜/监视器胶囊）

坐标系约定：本文件里所有"原版像素"一律归一化到 **1024×768**（= 截图坐标 ÷ 1.5）。
Godot 侧按 UI_SCALE = 视口高 / 768 缩放。

用法：
    python tools/make_hud_ui.py            # 生成贴图 + hud.json + 复核图
"""
from __future__ import annotations

import json
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHOT = os.path.join(ROOT, "docs", "screenshots", "orig", "07_牌桌.png")
NUM1 = os.path.join(ROOT, "game", "assets", "uitex", "other", "number1.png")
OUT = os.path.join(ROOT, "game", "assets", "ui", "hud")
TMP = os.path.join(ROOT, ".workbuddy", "tmp")
SHOT_DIV = 1.5          # 1536/1024

# ---- 截图坐标系（1536×1152）里的裁剪框 ------------------------------------
# 图徽椭圆：留 2px 余量，随后用椭圆 alpha 抠掉四角
COIN_BOXES = {
    "coin1_money":  (0, 1, 78, 39),
    "coin2_stock":  (260, 1, 340, 39),
    "coin3_house":  (534, 1, 614, 39),
    "coin4_cards":  (796, 1, 882, 39),
    "coin5_face":   (1011, 3, 1048, 40),
}
BTN_STRIP_BOX = (1284, 0, 1522, 42)      # 暂停 / 放大镜 / 监视器
PANEL_BOX = (1120, 0, 1246, 42)          # x/y 面板（用于取斜杠 + 量尺寸）
PANEL_TEXT_BOX = (1132, 7, 1238, 35)     # 只含面板内部文字（避开上下亮边）


def _ellipse_alpha(w: int, h: int, pad: float = 0.5) -> Image.Image:
    """内切椭圆 mask（1px 反锯齿），用来抠掉矩形裁切里的四角底色。"""
    yy, xx = np.mgrid[0:h, 0:w]
    cx, cy = (w - 1) / 2.0, (h - 1) / 2.0
    rx, ry = (w - 1) / 2.0 - pad, (h - 1) / 2.0 - pad
    d = ((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2
    a = np.clip((1.0 - d) * (max(w, h) / 2.0), 0.0, 1.0)   # 边缘 1px 渐变
    return Image.fromarray((a * 255).astype(np.uint8), "L")


def _slice_digits() -> dict:
    """切 `uitex/other/number1.tga`（粗体白字 + 深蓝描边）→ num_0..9 / num_x。

    ⚠️ 为什么不用游戏点阵字体 `gbdata/unicode24.tft`（见 tools/r6_tft.py）：
       它的数字是**细笔画**，而原版顶栏数字是**粗体实心**。三者同高并排比对
       （`.workbuddy/tmp/ui/digit_cmp.png`）后确认 —— 顶栏用的是 number1 这套。
       unicode16/24 那两套留给正文中文用。

    切法：number1 是 4 列 × 3 行网格（128×128），行主序对应 `0..9` 再 `x`。
    单元格用等分（32×43）再取内部墨迹 bbox，避免依赖字距。
    """
    im = Image.open(NUM1).convert("RGBA")
    a = np.array(im)
    solid = a[:, :, 3] > 40
    H, W = solid.shape
    xs = [0, W // 4, W // 2, W * 3 // 4, W]
    ys = [0, H // 3, H * 2 // 3, H]
    chars = "0123456789"
    meta = {}
    k = 0
    for r in range(3):
        for c in range(4):
            x0, x1 = xs[c], xs[c + 1]
            y0, y1 = ys[r], ys[r + 1]
            sub = solid[y0:y1, x0:x1]
            if not sub.any():
                continue
            rr = np.where(sub.any(axis=1))[0]
            cc = np.where(sub.any(axis=0))[0]
            by0, by1 = y0 + int(rr.min()), y0 + int(rr.max())
            bx0, bx1 = x0 + int(cc.min()), x0 + int(cc.max())
            name = chars[k] if k < len(chars) else "x"
            im.crop((bx0, by0, bx1 + 1, by1 + 1)).save(os.path.join(OUT, "num_%s.png" % name))
            meta[name] = [bx0, by0, bx1 + 1, by1 + 1]
            k += 1
    missing = [c for c in chars if c not in meta]
    if missing:
        raise RuntimeError("number1.png 切片失败，缺字符 %s" % missing)
    return meta


def _slice_slash() -> list:
    """从原版 `x/y` 面板里抠出斜杠字形（number1 那套没有 `/`）。

    面板底色实测 (17,85,153)，字是亮白；三段亮块中间那段就是斜杠。
    """
    im = Image.open(SHOT).convert("RGB")
    x0, y0, x1, y1 = PANEL_TEXT_BOX
    reg = np.array(im.crop((x0, y0, x1, y1))).astype(int)
    bright = reg.min(axis=2) > 110
    cols = bright.any(axis=0)
    out, s = [], None
    for i, v in enumerate(cols):
        if v and s is None:
            s = i
        elif not v and s is not None:
            out.append((s, i - 1)); s = None
    if s is not None:
        out.append((s, len(cols) - 1))
    out = [r for r in out if r[1] - r[0] >= 3]
    if len(out) < 3:
        raise RuntimeError("x/y 面板里没找到 3 段字块：%s" % out)
    sl = out[len(out) // 2]
    sub = bright[:, sl[0]:sl[1] + 1]
    rr = np.where(sub.any(axis=1))[0]
    Image.open(SHOT).convert("RGBA").crop(
        (x0 + sl[0], y0 + int(rr.min()), x0 + sl[1] + 1, y0 + int(rr.max()) + 1)
    ).save(os.path.join(OUT, "num_slash.png"))
    return [x0 + sl[0], y0 + int(rr.min()), x0 + sl[1] + 1, y0 + int(rr.max()) + 1]


def main() -> int:
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(TMP, exist_ok=True)
    shot = Image.open(SHOT).convert("RGBA")
    meta: dict = {"_source": "tools/make_hud_ui.py", "_scale_ref": "原版 1024×768",
                  "_shot_div": SHOT_DIV, "glyphs": {}, "boxes": {}}

    # 1) 数字（来自 r6_tft.py 产出的游戏真字体）
    meta["glyphs"] = _slice_digits()
    meta["boxes"]["slash"] = _slice_slash()

    # 2) 计数项图徽（椭圆抠图）
    for name, (x0, y0, x1, y1) in COIN_BOXES.items():
        c = shot.crop((x0, y0, x1, y1))
        c.putalpha(_ellipse_alpha(c.width, c.height)) if name != "coin5_face" else None
        if name == "coin5_face":
            n = max(c.width, c.height)
            sq = Image.new("RGBA", (n, n), (17, 34, 187, 255))
            sq.paste(c, ((n - c.width) // 2, (n - c.height) // 2))
            sq.putalpha(_ellipse_alpha(n, n, pad=1.0))
            c = sq
        c.save(os.path.join(OUT, name + ".png"))
        meta["boxes"][name] = [x0, y0, x1, y1]

    # 3) 右侧三按钮条（原样保留，含各自胶囊）
    bs = shot.crop(BTN_STRIP_BOX)
    bs.save(os.path.join(OUT, "btnstrip.png"))
    meta["boxes"]["btnstrip"] = list(BTN_STRIP_BOX)
    meta["boxes"]["panel_xy"] = list(PANEL_BOX)

    # 4) 标称尺寸（换算到原版 1024×768）
    def n(v):
        return round(v / SHOT_DIV, 2)
    meta["metrics"] = {
        "bar_h": n(40.0),
        "coin_size": [n(72.0), n(32.0)],
        "coin_dx": [n(33.5), n(305.5), n(573.5), n(840.5), n(1029.0)],
        "coin_cy": n(21.0),
        "panel_xy": [n(PANEL_BOX[0]), n(PANEL_BOX[2])],
        "btnstrip": [n(BTN_STRIP_BOX[0]), n(BTN_STRIP_BOX[2])],
        "digit_h": n(26.0),
        "screen_ref": [1024, 768],
    }
    with open(os.path.join(OUT, "hud.json"), "w", encoding="utf-8") as f:
        json.dump(meta, f, ensure_ascii=False, indent=1)

    # 5) 复核图
    files = sorted(f for f in os.listdir(OUT) if f.endswith(".png"))
    tiles = []
    for f in files:
        im = Image.open(os.path.join(OUT, f)).convert("RGBA")
        s = max(1, min(4, 200 // max(im.size)))
        tiles.append((f, im.size, im.resize((im.width * s, im.height * s), Image.NEAREST)))
    S = 5
    cols = 5
    cw = max(t[2].width for t in tiles) + 2 * S
    ch = max(t[2].height for t in tiles) + 3 * S
    rows = (len(tiles) + cols - 1) // cols
    sheet = Image.new("RGB", (cw * cols, ch * rows), (34, 36, 44))
    for i, (f, osz, im) in enumerate(tiles):
        r, c = divmod(i, cols)
        x, y = c * cw + S, r * ch + S
        for by in range(0, im.height, 12):
            for bx in range(0, im.width, 12):
                col = (86, 90, 104) if ((bx // 12 + by // 12) % 2 == 0) else (62, 66, 78)
                sheet.paste(col, (x + bx, y + by, x + min(bx + 11, im.width), y + min(by + 11, im.height)))
        sheet.paste(im, (x, y), im)
    sheet.save(os.path.join(TMP, "hud_out_check.png"))
    print("写出 %d 个贴图 + hud.json → %s" % (len(files), OUT))
    print("复核图 → .workbuddy/tmp/hud_out_check.png")
    print("metrics =", json.dumps(meta["metrics"], ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
