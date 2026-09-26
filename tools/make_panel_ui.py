#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
make_panel_ui.py —— 从原版素材整理出「牌桌 HUD」用的一组贴图。

产出目录 `game/assets/ui/panel/`（ASCII 文件名，避免中文名在 --import 里出岔子）：

    frame_atb.png    左下角色面板底框    <- uitex/other/atb.png 的内容区（裁到 176x120）
    icon_tv.png      右下图标条 ① 电视/角色  <- uitex/subc/电视.png
    icon_chart.png   右下图标条 ② 折线图     <- uitex/subc/股票.png
    icon_map.png     右下图标条 ③ MAP       <- uitex/subc/地图.png
    icon_chat.png    右下图标条 ④ 聊天       <- uitex/subc/聊天.png
    icon_mic.png     右下图标条 ⑤ 话筒       <- uitex/subc/话筒.png
    icon_play.png    右下图标条 ⑥ 播放 ▶     <- uitex/subc/min.png
    go.png/go_dn.png 动作 GO 气泡（常态/按下）<- uitex/labar/go.png / go_dn.png
                      ⚠️ 单张都是**贴边裁切**的残图，别直接用；
    go_btn.png       实际使用的 GO 钮 = dial(蓝球) + go 叠加（78x78 native）
    go_btn_dn.png    同上，按下态
    dice.png         骰子静态                   <- uitex/labar/骰子.png
    dice_anim.png    骰子滚动 16 帧（8x2 网格） <- uitex/labar/anim.png
    dial.png         角色头顶信息圆盘底         <- uitex/labar/背景.png
    saybk.png        对话气泡底                 <- uitex/other/saybk.png
    gear.png         左下齿轮按钮（自原版截图裁，抠 alpha）
    panel.json       各槽位矩形（frame_atb 内，单位=图内像素）

用法：
    .workbuddy/venv/Scripts/python.exe tools/make_panel_ui.py
"""
from __future__ import annotations

import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
UITEX = os.path.join(ROOT, "game", "assets", "uitex")
OUT = os.path.join(ROOT, "game", "assets", "ui", "panel")
SHOT = os.path.join(ROOT, "docs", "screenshots", "orig", "07_牌桌.png")

# 原版截图 = 1024x768 的 1.5 倍
SHOT_DIV = 1.5
# 齿轮在原版截图里的包围盒（1536x1152 坐标系），由 tools/_tmp_measure2.py 量出后目视校正
GEAR_BOX = (4, 1052, 76, 1124)          # x0,y0,x1,y1


def _load(path):
    if not os.path.exists(path):
        sys.exit("缺文件：%s" % path)
    return Image.open(path).convert("RGBA")


# ----------------------------------------------------------------- atb 槽位
def _bbox(mask):
    ys, xs = np.nonzero(mask)
    if len(xs) == 0:
        return None
    return [int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1]


def _blobs(mask, min_w=6, min_h=3):
    """按列切、再按行切 → 矩形块列表。用于平色素材（atb.png 全是平色块）。"""
    cols = mask.sum(axis=0)
    runs, s = [], None
    for i, v in enumerate(cols):
        if v >= min_h and s is None:
            s = i
        elif v < min_h and s is not None:
            runs.append((s, i))
            s = None
    if s is not None:
        runs.append((s, len(cols)))

    out = []
    for c0, c1 in runs:
        if c1 - c0 < min_w:
            continue
        sub = mask[:, c0:c1]
        rows = sub.sum(axis=1)
        rr, s2 = [], None
        for i, v in enumerate(rows):
            if v >= (c1 - c0) * 0.5 and s2 is None:
                s2 = i
            elif v < (c1 - c0) * 0.5 and s2 is not None:
                rr.append((s2, i))
                s2 = None
        if s2 is not None:
            rr.append((s2, len(rows)))
        for r0, r1 in rr:
            if r1 - r0 >= min_h:
                out.append([c0, r0, c1, r1])
    return out


def _atb_slots(atb: Image.Image):
    """在 atb.png 里定位各槽位。

    atb.png 是**纯平色**素材（每种用途一个固定 RGB），所以按颜色精确分割即可：
        浅蓝 (79,195,255)    = 头像/信息 大方块
        深蓝 (28, 36,131)    = 名字/状态 胶囊
        绿边 (45,142,45)/(152,255,184) + 半透明底 (102,138,255) = 下部两条细条
        薄荷青 (118,255,210) = 外框描边
    返回主框矩形 + 各槽位（含局部坐标）。
    """
    a = np.asarray(atb.convert("RGBA")).astype(np.int16)
    al = a[:, :, 3]
    op = al > 16

    main = op.copy()
    main[:, 176:] = False                       # 176 右侧那条装饰不与主框同体
    m = _bbox(main)
    cx0, cy0, cx1, cy1 = m

    def eq(rgb, tol=8):
        return ((np.abs(a[:, :, 0] - rgb[0]) <= tol) &
                (np.abs(a[:, :, 1] - rgb[1]) <= tol) &
                (np.abs(a[:, :, 2] - rgb[2]) <= tol) & op)

    light = _blobs(eq((79, 195, 255)))
    navy = _blobs(eq((28, 36, 131)))
    gdark = _blobs(eq((45, 142, 45)), min_w=20, min_h=1)

    # 两条细条：由深绿上下边合成（同一条的上下边 x 范围一致）
    bars = []
    if len(gdark) >= 4:
        # 按 x 起点配对
        pairs = {}
        for r in gdark:
            pairs.setdefault(r[0], []).append(r)
        for x0 in sorted(pairs):
            rs = sorted(pairs[x0], key=lambda r: r[1])
            if len(rs) >= 2:
                bars.append([rs[0][0], rs[0][1], rs[0][2], rs[-1][3]])

    def loc(r):
        return [r[0] - cx0, r[1] - cy0, r[2] - cx0, r[3] - cy0] if r else None

    light = sorted(light, key=lambda r: r[0])
    navy = sorted(navy, key=lambda r: r[0])      # 按 x：左=名字条，右=状态条
    bars = sorted(bars, key=lambda r: r[0])

    return {
        "content": m,
        "avatar": loc(light[0]) if len(light) > 0 else None,
        "info": loc(light[1]) if len(light) > 1 else None,
        "name": loc(navy[0]) if len(navy) > 0 else None,
        "stat": loc(navy[-1]) if len(navy) > 1 else None,
        "bar_a": loc(bars[0]) if len(bars) > 0 else None,
        "bar_b": loc(bars[1]) if len(bars) > 1 else None,
        "_raw": {"light": light, "navy": navy, "bars": bars},
    }


def _alpha_behind(img: Image.Image) -> Image.Image:
    """把「近似背景灰白/沙色」的像素抠掉（用于从截图裁的齿轮）。"""
    a = np.asarray(img.convert("RGB")).astype(np.int16)
    r, g, b = a[:, :, 0], a[:, :, 1], a[:, :, 2]
    keep = (r > 120) & (b > 120) & (g < 150) & (b > g + 30)      # 紫粉齿轮
    keep |= (r > 200) & (g > 200) & (b > 200)                    # 白描边
    out = np.asarray(img).copy()
    out[:, :, 3] = np.where(keep, 255, 0).astype(np.uint8)
    return Image.fromarray(out, "RGBA")


# --------------------------------------------------------------- GO 钮合成
GO_SCALE = 1.146            # 蓝球 64 → 73.3 native（原版实机截图按色分离量得）
GO_OFFSET = (13.7, 1.0)     # 青球可见区中心 相对 蓝球可见区中心，native
GO_CANVAS = 78              # 合成后画布边长（native）


def _compose_go(dial: Image.Image, go: Image.Image) -> Image.Image:
    """把 `dial`(蓝球) 与 `go`(青球) 按原版位置叠成一张 GO 钮。

    两张源图都是「贴边裁切」的，所以**不能按画布对齐**，只能按**可见区中心**对齐
    —— 这正是原版当年把两张图分开画的原因。
    """
    s = GO_SCALE
    n = GO_CANVAS
    big = n * 3                                   # 先放大画布，避免贴到负坐标
    cv = Image.new("RGBA", (big, big), (0, 0, 0, 0))

    def draw(src: Image.Image, center: tuple) -> None:
        w = max(1, round(src.width * s))
        h = max(1, round(src.height * s))
        im = src.resize((w, h), Image.LANCZOS)
        bb = src.getchannel("A").getbbox()        # 源图可见区
        cx = (bb[0] + bb[2]) / 2.0 * s            # 可见区中心在缩放后的位置
        cy = (bb[1] + bb[3]) / 2.0 * s
        cv.alpha_composite(im, (round(center[0] - cx), round(center[1] - cy)))

    base = (big / 2.0, big / 2.0)                 # 蓝球可见区中心 = 画布中心
    draw(dial, base)
    draw(go, (base[0] + GO_OFFSET[0], base[1] + GO_OFFSET[1]))

    cv = cv.crop(cv.getchannel("A").getbbox())    # 裁到真正用到的范围
    if max(cv.size) > n:                          # 超出就等比缩到 n
        k = n / float(max(cv.size))
        cv = cv.resize((max(1, round(cv.width * k)), max(1, round(cv.height * k))),
                       Image.LANCZOS)
    out = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    out.alpha_composite(cv, ((n - cv.width) // 2, (n - cv.height) // 2))
    return out


DICE_FACE = 32              # 骰子单格边长（`labar/骰子.png` 与 `anim.png` 都是 32 的栅格）
DICE_SPIN_FRAMES = 16       # `labar/anim.png` = 4x4 共 16 帧翻滚动画
DICE_SPIN_COLS = 4


def _runs(flags) -> list:
    """把一维 bool 序列切成 [(start, stop), ...]，只取 True 段。"""
    out, s = [], None
    for i, v in enumerate(flags):
        if v and s is None:
            s = i
        elif not v and s is not None:
            out.append((s, i))
            s = None
    if s is not None:
        out.append((s, len(flags)))
    return out


def _dice_faces(img: Image.Image) -> list:
    """`labar/骰子.png`(128x64) = **6 个骰子面**（3 列 x 2 行），不是两颗骰子。

    ⚠️ 不能用连通域：上下两排骰子在 alpha 上是**相连的**（列内无零行），
    `ndimage.label` 只会得到 3 块（每列一块）。所以按投影切：
      纵向投影的**零列**把图分成 3 列（实测零列恰在 x=44、x=77）；
      横向无零行 → 每列再按高度均分成上下 2 格。
    顺序：左上→右、上→下 = 1..6。
    """
    a = np.asarray(img.convert("RGBA"))
    op = a[:, :, 3] > 16
    cols = _runs(op.any(axis=0))
    if not cols:
        return []
    # 相邻列之间只隔 1 px 时会被当成两段 —— 够用；若合成一整段则按等宽切
    if len(cols) == 1:
        x0, x1 = cols[0]
        w = (x1 - x0) / 3.0
        cols = [(x0 + int(round(i * w)), x0 + int(round((i + 1) * w))) for i in range(3)]
    rows = _runs(op.any(axis=1))
    if rows:
        ry0, ry1 = rows[0]
    else:
        ry0, ry1 = 0, img.height
    nrow = 2 if (ry1 - ry0) >= DICE_FACE * 2 - 4 else 1
    h = (ry1 - ry0) / float(nrow)
    faces = []
    # ⚠️ 必须**行优先**（先上排 1/2/3，再下排 4/5/6）；按列遍历会得到 1,4,2,5,3,6
    for r in range(nrow):
        cy0 = int(round(ry0 + r * h))
        cy1 = int(round(ry0 + (r + 1) * h))
        cy = (cy0 + cy1) // 2
        for x0, x1 in cols:
            cx = (x0 + x1) // 2
            k = DICE_FACE // 2
            faces.append(img.crop((cx - k, cy - k, cx + k, cy + k)))
    return faces


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    meta = {"_comment": "由 tools/make_panel_ui.py 生成；尺寸均为原版 1024x768 设计分辨率下的像素值",
            "_source": "F:\\游戏\\Rich6 gamedata.pck -> uitex/** + docs/screenshots/orig/07_牌桌.png"}

    # ---- 1) 左下角色面板底框 ----
    atb = _load(os.path.join(UITEX, "other", "atb.png"))
    slots = _atb_slots(atb)
    cx0, cy0, cx1, cy1 = slots["content"]
    frame = atb.crop((cx0, cy0, cx1, cy1))
    frame.save(os.path.join(OUT, "frame_atb.png"))

    meta["frame_atb"] = {
        "size": [frame.width, frame.height],
        "avatar_slot": slots["avatar"],
        "info_slot": slots["info"],
        "name_slot": slots["name"],
        "stat_slot": slots["stat"],
        "bar_a_slot": slots["bar_a"],
        "bar_b_slot": slots["bar_b"],
        "_dump": slots["_raw"],
    }

    # ---- 2) 右下 6 图标 ----
    icons = [("icon_tv", "电视"), ("icon_chart", "股票"), ("icon_map", "地图"),
             ("icon_chat", "聊天"), ("icon_mic", "话筒"), ("icon_play", "min")]
    for dst, src in icons:
        im = _load(os.path.join(UITEX, "subc", src + ".png"))
        im.save(os.path.join(OUT, dst + ".png"))
        meta.setdefault("icons", {})[dst] = {"size": list(im.size), "_from": "uitex/subc/%s.png" % src}

    # ---- 3) GO 气泡 / 骰子 / 圆盘 / 对话气泡 ----
    for dst, sub, src in [("go", "labar", "go"), ("go_dn", "labar", "go_dn"),
                          ("dice", "labar", "骰子"), ("dice_anim", "labar", "anim"),
                          ("dial", "labar", "背景"), ("saybk", "other", "saybk")]:
        im = _load(os.path.join(UITEX, sub, src + ".png"))
        im.save(os.path.join(OUT, dst + ".png"))
        meta.setdefault("misc", {})[dst] = {"size": list(im.size),
                                            "_from": "uitex/%s/%s.png" % (sub, src)}

    # ---- 3b) GO 钮合成 --------------------------------------------------
    # 原版角色头顶的 GO 钮**不是一个贴图**：`labar/背景.png`（深蓝球）打底，
    # `labar/go.png`（青球 + GO）叠在偏右上。两张都贴着画布边缘被裁过（go 的
    # 可见区 bbox=(0,10,41,64)、背景=(0,3,64,64)）→ 直接单独用任一张都不对。
    # 叠加参数由原版实机截图 `08_牌桌_2.png` 按颜色分离量得（截图 ÷1.5 = native）：
    #   蓝球直径 ≈73.3 native（贴图 64 → 缩放 ×1.146）；青球可见区中心比蓝球
    #   可见区中心偏 (+13.7, +1.0) native。
    dial = _load(os.path.join(OUT, "dial.png"))
    for dst, src in [("go_btn", "go"), ("go_btn_dn", "go_dn")]:
        cv = _compose_go(dial, _load(os.path.join(OUT, src + ".png")))
        cv.save(os.path.join(OUT, dst + ".png"))
        meta.setdefault("misc", {})[dst] = {
            "size": list(cv.size), "_from": "labar/背景.png + labar/%s.png 叠加" % src,
            "scale": GO_SCALE, "offset": list(GO_OFFSET)}
        print("  %-12s %s  (背景+%s)" % (dst, cv.size, src))

    # ---- 3c) 骰子：6 个面 + 16 帧翻滚动画 --------------------------------
    # `labar/骰子.png` 与 `labar/anim.png` 是原版 GO 钮那一套骰子素材：
    #   骰子.png  = 6 个面（3x2），1/4 是红点、2/3/5/6 是黑点
    #   anim.png  = 4x4 = 16 帧翻滚（点击 GO 之后一直转，停下才定格到某个面）
    faces = _dice_faces(_load(os.path.join(OUT, "dice.png")))
    if len(faces) == 6:
        strip = Image.new("RGBA", (DICE_FACE * 6, DICE_FACE), (0, 0, 0, 0))
        for i, f in enumerate(faces):
            strip.alpha_composite(f, (i * DICE_FACE, 0))
        strip.save(os.path.join(OUT, "die_faces.png"))
        meta["die_faces"] = {"size": list(strip.size), "frame": DICE_FACE, "count": 6,
                             "_from": "uitex/labar/骰子.png（6 个面，左上→右下 = 1..6）"}
        print("  %-12s %s  (6 面 1x6)" % ("die_faces", strip.size))
    else:
        print("⚠️ 骰子面切分成 %d 块（期望 6），跳过 die_faces.png" % len(faces))

    spin = _load(os.path.join(OUT, "dice_anim.png"))
    meta["die_spin"] = {"size": list(spin.size), "frame": DICE_FACE,
                        "cols": DICE_SPIN_COLS, "frames": DICE_SPIN_FRAMES,
                        "_from": "uitex/labar/anim.png（4x4 翻滚动画）"}

    # ---- 4) 齿轮（自原版截图裁）----
    if os.path.exists(SHOT):
        sh = _load(SHOT)
        g = sh.crop(GEAR_BOX)
        g = _alpha_behind(g)
        bb = g.getbbox()
        if bb:
            g = g.crop(bb)
        g.save(os.path.join(OUT, "gear.png"))
        meta["gear"] = {"size": list(g.size), "_from": "07_牌桌.png %s" % (GEAR_BOX,)}
    else:
        print("⚠️ 找不到原版截图，跳过 gear.png")

    # ---- 5) 版式度量（原版 1024x768 像素）----
    # 全部由 tools/_tmp_measure3.py 在原版实机截图上量得（截图 ÷1.5 = native）
    meta["layout"] = {
        "_comment": "原版截图 1536x1152 = 1024x768 的 1.5 倍；以下均已 ÷1.5 换到 native",
        "screen_ref": [1024, 768],
        "char_panel": {"x": 1.3, "y_from_bottom": 2.7, "w": 220.0, "h": 149.3,
                       "frame_native": [frame.width, frame.height]},
        "bottom_right": {"x_from_right": 0.7, "y_from_bottom": 0.7, "w": 292.0, "h": 196.0,
                         "minimap_h": 156.7, "iconbar_h": 36.7, "gap": 2.6},
        "minimap_frame": {"border": [170, 232, 250], "border2": [60, 128, 210],
                          "bg": [22, 62, 122], "radius": 9.0},
        "icon_bar": {"bg": [212, 250, 238], "border": [10, 80, 200],
                     "radius": 12.0, "icon_size": 28.7, "pad": 3.0,
                     "order": [d for d, _ in icons],
                     "actions": ["角色/电视", "股价图", "地图 MAP", "聊天", "话筒", "播放/最小化"]},
        "gear": {"src_box": list(GEAR_BOX)},
        "avatar_col": {"x_from_right": 2.0, "y_top": 216.7, "w": 35.3, "h": 42.0,
                       "step": 52.0, "count_shown": 4},
        # GO 钮左侧的**骰子数量选择器**：竖排两颗骰子图标，白=选中 / 灰=未选中。
        # 量自原版实机 `08_牌桌_2.png`（截图 ÷1.5 = native）：骰子 24x24，
        # 相对蓝盘**可见区中心**的偏移 (-24.4,-12.3) 与 (-24.4,+13.7)。
        # 上限 = 2：原版 5 张实机截图（07/08/09/new_session_board/new_session_later）
        # 一致只有 2 颗，从未出现第 3 颗 → 别再往上加。
        "go_dice": {"size": 24.0, "disk_size": 78.0,
                    "offsets": [[-24.4, -12.3], [-24.4, 13.7]],
                    "max_count": 2,
                    "_comment": "白=选中/灰=未选中；原版实机固定 2 颗（5 张截图一致）"},
    }

    with open(os.path.join(OUT, "panel.json"), "w", encoding="utf-8") as f:
        json.dump(meta, f, ensure_ascii=False, indent=2)

    print("产出 %s：" % OUT)
    for n in sorted(os.listdir(OUT)):
        if n.endswith(".png"):
            print("   %-18s %s" % (n, Image.open(os.path.join(OUT, n)).size))
    import pprint
    print("\nframe_atb 槽位：")
    pprint.pprint(meta["frame_atb"])


if __name__ == "__main__":
    main()
