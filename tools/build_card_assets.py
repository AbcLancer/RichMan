#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
build_card_assets.py —— 把 42 张原版卡面 `samples/card/<n>_<中文名>.tga`
转到 `game/assets/card/<id>.png`，并生成 `index.json`。

编号口径（三处必须一致，已逐条核对）：
  1. `samples/card/<n>_<名>.tga` 的 n = 1..42
  2. `game/data/rules/realtime.json` 的 `cards` 数组下标 + 1
     （顺序：caishen, fushen, … nuke —— 与卡面文件名一一对应）
  3. `config/String.txt` 里 9001..9042 的说明文字，条目标签就是卡面中文名

产物 index.json 结构：
  {"_source": ..., "cards": [{"n":1,"id":"caishen","file":"caishen.png",
                              "name_tga":"财神卡","ui_name":"财神卡",
                              "desc":"有请财神爷附身","desc_id":9001}, ...]}
"""
import json
import os
import re
import shutil

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC_DIR = os.path.join(ROOT, "samples", "card")
OUT_DIR = os.path.join(ROOT, "game", "assets", "card")
RULES = os.path.join(ROOT, "game", "data", "rules", "realtime.json")
STRINGS = os.path.join(ROOT, "game", "data", "rules", "ui_strings.json")

NAME_RE = re.compile(r"^(\d+)_(.+)\.(tga|png)$", re.IGNORECASE)

# 卡面**左上角徽章**里的数字（1..5）。原版配置里**没有**卡片价格表 →
# 只能从卡面 art 读。已用 `samples/card/*` 放大成串两次逐条核对
# （.workbuddy/tmp/badges.png）：一/二/三/四/五步卡 = 5/4/3/2/1，
# 核弹·财神·福神·土神·改建·购地·均富·隐形 = 5。
# 语义未在 config 中定义 —— 疑为「点券售价」（卡片商店里买入要花的点券），
# 也可能是卡片等级；**待实测确认**，代码里按点券售价用并保留此注释。
# 顺序 = realtime.json cards 0..41。
BADGE = [5, 5, 4, 3, 4, 4, 4, 5, 5, 4, 3, 2, 1, 1,
         2, 4, 5, 2, 3, 5, 3, 2, 3, 3, 4, 3, 4, 3,
         3, 2, 3, 3, 2, 4, 4, 3, 3, 5, 2, 2, 5, 5]
# 徽章底色（红/绿）也随卡不同 —— 疑为卡片分类，未使用，仅记录。
# 绿：土神·一~五步卡；红：其余。


def main() -> None:
    cards = json.load(open(RULES, encoding="utf-8"))["cards"]
    strings = json.load(open(STRINGS, encoding="utf-8"))
    desc = strings["card_desc"]          # "9001" -> "有请财神附身"
    entries = strings["entries"]

    # 扫 samples/card，按编号索引（同一编号优先 tga）
    by_n: dict = {}
    for fn in os.listdir(SRC_DIR):
        m = NAME_RE.match(fn)
        if not m:
            continue
        n = int(m.group(1))
        ext = m.group(3).lower()
        if n not in by_n or ext == "tga":
            by_n[n] = (fn, m.group(2))

    os.makedirs(OUT_DIR, exist_ok=True)
    out = {"_source": "samples/card/<n>_<名>.tga（原版 pck）",
           "_note": "n / realtime.json 下标+1 / String.txt 9000+n 三处编号一致",
           "cards": []}
    miss = []
    for i, c in enumerate(cards, 1):
        cid = str(c["id"])
        if i not in by_n:
            miss.append(i)
            continue
        fn, cn = by_n[i]
        src = os.path.join(SRC_DIR, fn)
        im = Image.open(src).convert("RGBA")
        dst = os.path.join(OUT_DIR, cid + ".png")
        im.save(dst)
        sid = str(9000 + i)
        e = entries.get(sid, {})
        out["cards"].append({
            "n": i,
            "id": cid,
            "file": cid + ".png",
            "size": list(im.size),
            "name_tga": cn,
            "ui_name": e.get("name", cn),
            "desc_id": int(sid),
            "desc": desc.get(sid, ""),
            "effect": c.get("effect", ""),
            "badge": BADGE[i - 1] if i - 1 < len(BADGE) else None,
        })

    with open(os.path.join(OUT_DIR, "index.json"), "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=1)

    print("写出 %d 张卡面 → %s" % (len(out["cards"]), OUT_DIR))
    if miss:
        print("!! 缺编号:", miss)
    for r in out["cards"][:3] + out["cards"][-2:]:
        print("  %2d %-12s %s  「%s」 %s" % (
            r["n"], r["id"], r["ui_name"], r["desc"], r["file"]))


if __name__ == "__main__":
    main()
