#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""解析原版 `config/Info.txt`（1490 行）→ `game/data/rules/info_strings.json`。

## 为什么需要它（和 `build_ui_strings.py` 的区别）

| 文件 | 是什么 | 我们已有的产物 |
|---|---|---|
| `config/String.txt` | **界面标签 / 卡片说明**（按钮文字、卡片菜单、42 张卡说明、卡片不可用原因码 60..70） | `ui_strings.json` ✅ |
| `config/Info.txt` | **游戏过程中弹的消息**（1600+ 条）：事件、异常状态、市政、卡片、新闻、拍卖、特殊建物… | ← **本工具** |

两份文件的 **id 空间是独立的**（String.txt 的 63 = 「只能用于对手的地产」；Info.txt 的 63
= 「今日乐透开奖」）。别把两者混着查。

## 格式

    // 分区注释（就是原版的功能目录）
    住院            {  1 , "SELF", "MINE",, "<SOMEONE>住院" }     （尾注）
                      └id   └受众   └类别   ↑偶尔有两个逗号

三个字符串依次是 **受众 / 类别 / 文本**：
  受众：`ALL` 所有人 / `SELF` 自己 / `OTHER` 除自己外
  类别：`MINE` 对自己的提示 / `MANSAY` 角色说话 / `PETSAY` 宠物说话 / `GAME` 一般游戏信息 / `NEWS` 新闻
占位符：`<SOMEONE>` `<SOMEONE1>` `<SOMEONE2>` `<NUMBER>` `<FLTNUM>` `<CARDNAME>` `<ROAD>`
        `<STOCKNAME>` `<STOCKNAME1>` `<STOCKNAME2>` `<BABYNAME>`

## 用法

    .workbuddy/venv/Scripts/python.exe tools/build_info_strings.py
"""

from __future__ import annotations

import collections
import io
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "docs", "original-readable", "installation", "config", "Info.txt")
OUT = os.path.join(ROOT, "game", "data", "rules", "info_strings.json")

ENTRY_RE = re.compile(r"\{\s*(\d+)\s*,(.*?)\}\s*(.*)$")
STR_RE = re.compile(r'"((?:[^"\\]|\\.)*)"')
PLACEHOLDER_RE = re.compile(
    r"<([A-Z][A-Z0-9]*)>")
SECTION_RE = re.compile(r"^//\s*(.+?)\s*$")


def parse(path: str):
    entries: dict[str, dict] = {}
    dupes: dict[str, list[int]] = collections.defaultdict(list)
    sections: list[dict] = []
    section = ""
    lines = io.open(path, encoding="utf-8", errors="replace").read().splitlines()
    for no, raw in enumerate(lines, 1):
        s = raw.strip()
        if s.startswith("//"):
            m = SECTION_RE.match(s)
            if m and not re.match(r"^\d[、.．]", m.group(1)):
                section = m.group(1)
                sections.append({"line": no, "title": section})
            continue
        m = ENTRY_RE.search(raw)
        if not m:
            continue
        mid = m.group(1)
        strs = STR_RE.findall(m.group(2))
        tail = m.group(3).strip()
        # 允许「两个逗号」造成的空段 → 固定取后三个字符串
        strs = strs[-3:] if len(strs) >= 3 else ([""] * (3 - len(strs)) + strs)
        # 原版文本里的「反斜杠 + n」是**两个字符**，不是真换行。
        # 直接 json.dump 会写成双反斜杠，读回来仍是字面量 → 这里转成真换行。
        text = strs[2].replace("\\n", "\n")
        rec = {
            "id": int(mid),
            "audience": strs[0],
            "kind": strs[1],
            "text": text,
            "name": re.sub(r"\s+", "", raw.split("{")[0].strip()),
            "section": section,
            "placeholders": sorted(set(PLACEHOLDER_RE.findall(text))),
            "raw": raw.rstrip(),
            "line": no,
            "_comment": tail.lstrip("（(").rstrip("）)") if tail else None,
        }
        if mid in entries:
            dupes[mid].append(no)
            continue                      # 同 id 保留首次（与 String.txt 生成器同一策略）
        entries[mid] = rec
    return entries, dict(dupes), sections


def main() -> int:
    entries, dupes, sections = parse(SRC)
    doc = {
        "_source": "F:\\游戏\\Rich6\\config\\Info.txt（原版安装目录明文，UTF-8）",
        "_format": "受众(ALL/SELF/OTHER) + 类别(MINE/MANSAY/PETSAY/GAME/NEWS) + 文本；"
                   "占位符 <SOMEONE> <SOMEONE1/2> <NUMBER> <FLTNUM> <CARDNAME> <ROAD> "
                   "<STOCKNAME/1/2> <BABYNAME>",
        "_note": "id 空间与 config/String.txt **完全独立**，别混查。",
        "_duplicate_ids": dupes,
        "sections": sections,
        "entries": entries,
    }
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with io.open(OUT, "w", encoding="utf-8", newline="\n") as f:
        json.dump(doc, f, ensure_ascii=False, indent=1)
        f.write("\n")
    print("Info.txt → %s" % OUT)
    print("  条目 %d 条；分区 %d 个；同 id 撞号 %d 处（保留首次）"
          % (len(entries), len(sections), len(dupes)))
    for k in ["1", "41", "42", "191", "194", "201", "202", "203", "8001", "9001"]:
        e = entries.get(k)
        if e:
            print("  %5s [%s/%s] %s" % (k, e["audience"], e["kind"],
                                        e["text"].replace("\n", "\\n")))
    return 0


if __name__ == "__main__":
    sys.exit(main())
