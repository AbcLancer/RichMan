#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""把小神仙 / 两家商店的**原版 UI 素材**转进工程。

## 素材含义（逐张看过，`samples/uitex/pet/<dir>/` 每只 20 张）

| 原版文件 | 尺寸 | 含义 | 我们的命名 |
|---|---|---|---|
| `01..04` | 64×64 | **4 个等级的小头像**（面板里用） | `face1..4.png` |
| `10, 11` | 64×64 | 两个小表情变体 | `mini1..2.png` |
| `20..23` | 64×64 | 另一组 4 等级头像 | `faceb1..4.png` |
| `30..33` | 64×64 | **施法特效**（放技能时头顶闪光的那个） | `cast1..4.png` |
| `70..73` | 128×128 | **4 个等级的大图**（商店货架用） | `big1..4.png` |
| `90, 91` | 32×32 | 小图标 | `icon1..2.png` |

`uitex/pet/星01..04.tga`（32×32）= **等级星**。

## 两家商店的底图（原版现成的，不用自己画）

| 原版文件 | 尺寸 | 用途 |
|---|---|---|
| `uitex/pethouse/精灵屋.tga` | 256×256 | 「小神仙」**持有面板**（标题「小神仙」，2×2 共 4 格） |
| `uitex/pethouse/商店.tga` | 256×256 | 「**小神仙商店**」货架（2×2 共 4 格） |
| `uitex/pethouse/浮动条.tga` | 64×32 | 浮动说明条 |
| `uitex/other/cardshop.tga` | 256×256 | 「**卡片商店**」（8 格 2×4 + 顶部「您有 N 点券」深色条） |
| `uitex/other/cardshop1.tga` | 64×32 | 卡片商店的浮动条 |

槽位坐标是从底图上量出来的（见 `SLOT` 常量），UI 按这些比例摆内容。

## 用法

    .workbuddy/venv/Scripts/python.exe tools/build_pet_assets.py
"""

from __future__ import annotations

import json
import os

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PET_SRC = os.path.join(ROOT, "samples", "uitex", "pet")
HOUSE_SRC = os.path.join(ROOT, "samples", "uitex", "pethouse")
OTHER_SRC = os.path.join(ROOT, "samples", "uitex", "other")
PET_OUT = os.path.join(ROOT, "game", "assets", "pets")
UI_OUT = os.path.join(ROOT, "game", "assets", "ui", "shop")

# 原版文件号 → 我们的语义名
GROUPS = {
    "face": ["01", "02", "03", "04"],
    "mini": ["10", "11"],
    "faceb": ["20", "21", "22", "23"],
    "cast": ["30", "31", "32", "33"],
    "big": ["70", "71", "72", "73"],
    "icon": ["90", "91"],
}
UI_FILES = {
    "pethouse_panel.png": os.path.join(HOUSE_SRC, "精灵屋.tga"),
    "pethouse_shop.png": os.path.join(HOUSE_SRC, "商店.tga"),
    "pethouse_bar.png": os.path.join(HOUSE_SRC, "浮动条.tga"),
    "cardshop.png": os.path.join(OTHER_SRC, "cardshop.tga"),
    "cardshop_bar.png": os.path.join(OTHER_SRC, "cardshop1.tga"),
    # 原版通用对话框素材（`uitex/other/`）：
    #   infobk = 灰白圆角信息框 → 商店/卡片购买的**二次确认框**底图
    #            （对得上老板原版截图 docs/screenshots/orig/records/小神仙商店购买确认.png）
    #   saybk  = 说话气泡（角色/小神仙台词）
    #   msgbox / hint = 小消息框 / 提示条
    "infobk.png": os.path.join(OTHER_SRC, "infobk.tga"),
    "saybk.png": os.path.join(OTHER_SRC, "saybk.tga"),
    "msgbox.png": os.path.join(OTHER_SRC, "msgbox.tga"),
    "hint.png": os.path.join(OTHER_SRC, "hint.tga"),
    # 股票买进对话框（`uitex/buystock/`）—— 老板原版截图里那个
    # 「买进 [1900] / [63650] / OK PASS」的粉框：上排标签+输入、中间金额、下面按钮条
    "stock_buy.png": os.path.join(ROOT, "samples", "uitex", "buystock", "buystock.tga"),
    "stock_bar.png": os.path.join(ROOT, "samples", "uitex", "buystock", "bar.tga"),
    "stock_ok_1.png": os.path.join(ROOT, "samples", "uitex", "buystock", "ok_1.tga"),
    "stock_ok_2.png": os.path.join(ROOT, "samples", "uitex", "buystock", "ok_2.tga"),
    "stock_pass_1.png": os.path.join(ROOT, "samples", "uitex", "buystock", "pass_1.tga"),
    "stock_pass_2.png": os.path.join(ROOT, "samples", "uitex", "buystock", "pass_2.tga"),
}

# ---- 槽位（native 256×256 底图坐标；x, y, w, h）----
# 「小神仙」持有面板 / 小神仙商店：2×2，每格 = 图像区 + 下方标签条
SLOT = {
    "panel": [  # uitex/pethouse/精灵屋.tga
        {"img": [24, 49, 80, 64], "bar": [24, 117, 80, 20]},
        {"img": [120, 49, 80, 64], "bar": [120, 117, 80, 20]},
        {"img": [24, 144, 80, 64], "bar": [24, 212, 80, 20]},
        {"img": [120, 144, 80, 64], "bar": [120, 212, 80, 20]},
    ],
    "shop": [  # uitex/pethouse/商店.tga
        {"img": [36, 68, 64, 60], "bar": [20, 132, 98, 24]},
        {"img": [146, 68, 64, 60], "bar": [130, 132, 98, 24]},
        {"img": [36, 158, 64, 60], "bar": [20, 222, 98, 24]},
        {"img": [146, 158, 64, 60], "bar": [130, 222, 98, 24]},
    ],
    # 卡片商店：顶部深色条 = Info.txt 41「卡片商店 您有<NUMBER>点券」
    "cardshop": {
        "title_bar": [84, 80, 88, 23],
        "slots": [  # 2 列 × 4 行
            {"x": 29, "y": 118, "w": 95, "h": 30},
            {"x": 127, "y": 118, "w": 95, "h": 30},
            {"x": 29, "y": 152, "w": 95, "h": 30},
            {"x": 127, "y": 152, "w": 95, "h": 30},
            {"x": 29, "y": 185, "w": 95, "h": 30},
            {"x": 127, "y": 185, "w": 95, "h": 30},
            {"x": 29, "y": 218, "w": 95, "h": 30},
            {"x": 127, "y": 218, "w": 95, "h": 30},
        ],
    },
}


def main() -> None:
    os.makedirs(PET_OUT, exist_ok=True)
    os.makedirs(UI_OUT, exist_ok=True)

    # 1) 每只小神仙的图
    dirs = sorted(d for d in os.listdir(PET_SRC)
                  if os.path.isdir(os.path.join(PET_SRC, d)))
    index = {"_source": "samples/uitex/pet/<dir>/（原版 pck，20 张/只）",
             "_note": "原版文件号 → 语义名见 tools/build_pet_assets.py 文件头",
             "pets": []}
    for d in dirs:
        src = os.path.join(PET_SRC, d)
        out = os.path.join(PET_OUT, d)
        os.makedirs(out, exist_ok=True)
        rec = {"id": d, "files": {}}
        for kind, nums in GROUPS.items():
            names = []
            for i, n in enumerate(nums, 1):
                p = os.path.join(src, n + ".tga")
                if not os.path.exists(p):
                    p = os.path.join(src, n + ".png")
                if not os.path.exists(p):
                    continue
                im = Image.open(p).convert("RGBA")
                fn = "%s%d.png" % (kind, i)
                im.save(os.path.join(out, fn))
                names.append(fn)
            rec["files"][kind] = names
        index["pets"].append(rec)

    # 2) 等级星
    stars = []
    for i in range(1, 5):
        p = os.path.join(PET_SRC, "星%02d.tga" % i)
        if os.path.exists(p):
            Image.open(p).convert("RGBA").save(os.path.join(PET_OUT, "star%d.png" % i))
            stars.append("star%d.png" % i)
    index["stars"] = stars

    # 3) 两家商店的底图
    for name, p in UI_FILES.items():
        if os.path.exists(p):
            Image.open(p).convert("RGBA").save(os.path.join(UI_OUT, name))
        else:
            print("!! 缺素材", p)

    # 4) 槽位表一并落到 json（UI 读它，避免把坐标硬编码进 gdscript）
    index["slot"] = SLOT
    index["ui"] = {k: os.path.join("res://assets/ui/shop", k) for k in UI_FILES}
    with open(os.path.join(PET_OUT, "index.json"), "w", encoding="utf-8") as f:
        json.dump(index, f, ensure_ascii=False, indent=1)

    print("小神仙 %d 只 → %s" % (len(dirs), PET_OUT))
    print("等级星 %d 个；商店底图 %d 张 → %s" % (len(stars), len(UI_FILES), UI_OUT))
    for r in index["pets"][:2]:
        print("  ", r["id"], {k: len(v) for k, v in r["files"].items()})


if __name__ == "__main__":
    main()
