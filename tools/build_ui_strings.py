#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
build_ui_strings.py —— 把原版 `config/String.txt`（界面字串表）转成
`game/data/rules/ui_strings.json`（可复现）。

原版 String.txt 是 exe 里 UI 文案的唯一权威（README 记录：编号 1..9042）。
行格式（三种变体都存在）：

    点卡片菜单       {  1 , "使用" }
    网路连接讯息     {  201 , "SELF", "MINE", "主机人数已满" }
    不能购买地产     {  60 , "现金不足" }                        （当手上现金不足时…）

坑：
  * `{ }` 里的字符串**本身含逗号**（如 `"嘻嘻, 我是小赌神\\n我能…"`），
    所以**不能按逗号 split** → 用正则提「最后一个引号串」当文案。
  * 行尾可能还有抽屉注释（在 `}` 之后），要丢掉。
  * `\\n` 是字面两字符 → 还原成真换行。
"""
import json
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(
    ROOT, "docs", "original-readable", "installation", "config", "String.txt"
)
OUT = os.path.join(ROOT, "game", "data", "rules", "ui_strings.json")

# 需要单独拎出来的编号区段（供代码直接取用）
CARD_DESC_RANGE = (9001, 9042)      # 42 张卡的说明文字
CARD_TARGET_IDS = list(range(1101, 1107))   # 请选择对手/地产/股票/道路/卡片/房屋
CARD_MENU_IDS = list(range(1, 7))           # 使用/锁定/丢弃/喂食/解除/组合
PANEL_IDS = [2010, 2011, 2012, 2013, 2014, 2016, 2017, 2018, 2019,
             2005, 2008, 2009, 2030, 2031]

LINE_RE = re.compile(r"^\s*([^\{]+?)\s*\{\s*(.*?)\s*\}\s*(.*)$")
ID_RE = re.compile(r"^\s*(\d+)\s*")
STR_RE = re.compile(r'"((?:[^"\\]|\\.)*)"')
TAG_RE = re.compile(r'\b(SELF|MINE|PETSAY|MANSAY|OTHER|SOMEONE)\b')


def parse(path: str) -> dict:
    entries: dict = {}
    dupes: dict = {}
    # 原版 txt 在硬盘上是 GBK，但这批反汇编导出件是 UTF-8 → 用 utf-8 读（已实测）。
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        for ln, raw in enumerate(f, 1):
            line = raw.rstrip("\r\n")
            if not line.strip() or line.lstrip().startswith("//"):
                continue
            m = LINE_RE.match(line)
            if not m:
                continue
            label = m.group(1).strip()
            body = m.group(2)
            tail = m.group(3).strip()
            idm = ID_RE.match(body)
            if not idm:
                continue
            eid = int(idm.group(1))
            strs = STR_RE.findall(body)
            text = strs[-1] if strs else ""
            tags = TAG_RE.findall(body)
            # ⚠️ 原版 String.txt 里有**编号冲突**：第 104 行写成 `{ 02 , ... }`，
            #    与第 4 行的 `{ 2 , "锁定" }` 撞号（`02` 多半本该是 `302`）。
            #    按「首次出现优先」处理，否则卡片菜单「锁定」会被顶掉
            #    （实测过：菜单变成 使用 / <SOMEONE>退出游戏 / 丢弃）。
            if str(eid) in entries:
                dupes.setdefault(str(eid), []).append(ln)
                continue
            entries[str(eid)] = {
                "name": label,
                "text": text.replace("\\n", "\n"),
                "tags": tags,
                "raw": line.strip(),
                "line": ln,
                "_comment": tail or None,
            }
    return entries, dupes


def main() -> None:
    if not os.path.exists(SRC):
        raise SystemExit("找不到 %s" % SRC)
    entries, dupes = parse(SRC)

    cards = {}
    for i in range(CARD_DESC_RANGE[0], CARD_DESC_RANGE[1] + 1):
        e = entries.get(str(i))
        if e:
            cards[str(i)] = e["text"]

    out = {
        "_source": "docs/original-readable/installation/config/String.txt",
        "_comment": "原版界面字串表（编号 = exe 内的字串 id）。生成器 tools/build_ui_strings.py。",
        "_count": len(entries),
        "_duplicate_ids": {k: v for k, v in dupes.items()},
        "_duplicate_note": "原版 String.txt 里同 id 出现多次时只保留**首次**（见 _duplicate_ids 的行号）",
        "entries": entries,
        # —— 派生索引（代码直接用，省得每次扫全表）——
        "card_desc": cards,                     # 9001..9042 → 42 张卡说明
        "card_desc_first_id": CARD_DESC_RANGE[0],
        "card_targets": {str(i): entries[str(i)]["text"] for i in CARD_TARGET_IDS
                         if str(i) in entries},
        "card_menu": {str(i): entries[str(i)]["text"] for i in CARD_MENU_IDS
                      if str(i) in entries},
        "panel": {str(i): entries[str(i)]["text"] for i in PANEL_IDS
                  if str(i) in entries},
    }

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=1)

    print("解析 %d 条，写出 %s" % (len(entries), OUT))
    if dupes:
        print("  ⚠ 同 id 冲突 %d 处（保留首次）: %s" % (len(dupes), dupes))
    print("  卡说明 %d 条 / 目标提示 %d 条 / 卡菜单 %d 条 / 面板 %d 条" % (
        len(cards), len(out["card_targets"]), len(out["card_menu"]), len(out["panel"])))
    for k in sorted(cards, key=int)[:3]:
        print("   9000+%s: %s" % (k, cards[k]))
    for k in sorted(cards, key=int)[-2:]:
        print("   9000+%s: %s" % (k, cards[k]))


if __name__ == "__main__":
    main()
