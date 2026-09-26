#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""把原版**全局事件插画**（`samples/news/01..38.tga`，38 张 256×256）转成
`game/assets/news/01.png..38.png`。

## 这是什么

老板的原版截图 `docs/screenshots/orig/records/全局事件.png` 里那种**全屏插画**：
一张 256×256 的图 + 一行 `Info.txt` 的文案（例：「经济萧条，所有房租下降17%。」）。

对应的文案表 = `config/Info.txt` 里标签为 `"NEWS"` 的那些（甲1..甲19 等，id 3001 起）。

## ⚠️ 插画与事件的**对应关系没有依据**

`news/` 里的文件名只是 `01..38`，`Info.txt` 里也没有指向插画的字段
（`config/` 下翻不到映射表，exe 里那几个 `news` 字符串也只是路径模板）。
→ 本工具只负责**把 38 张图搬进来**；运行时按**序号**取图，并把这层不确定性
  登记在 `docs/alignment-gap.md`。

用法：

    .workbuddy/venv/Scripts/python.exe tools/build_news_assets.py
"""

from __future__ import annotations

import glob
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "samples", "news")
OUT = os.path.join(ROOT, "game", "assets", "news")


def main() -> int:
    os.makedirs(OUT, exist_ok=True)
    files = sorted(glob.glob(os.path.join(SRC, "*.tga")))
    n = 0
    for f in files:
        base = os.path.splitext(os.path.basename(f))[0]
        im = Image.open(f).convert("RGBA")
        im.save(os.path.join(OUT, "%s.png" % base))
        n += 1
    print("全局事件插画 %d 张 → %s" % (n, OUT))
    return 0


if __name__ == "__main__":
    sys.exit(main())
