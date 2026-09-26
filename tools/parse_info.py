#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""解析原版 config/Info.txt（消息表）—— 这是原版「消息 id / 文案 / 配音文件 id」的权威表。

行格式（GBK 文本）::

    //角色名                      <- 分组注释（宫本宝藏 / 阿土伯 / 9.拉霸 ...）
    1001攻击	{  5001 , "SELF", "MANSAY", "哈哈，我要攻击<SOMEONE>啦！" }

四个字段：
    消息 id = 1001      （编号规则见下）
    配音 id = 5001      （sound/player/<role>/5001.wav 或 sound/effect/xxx.wav）
    "SELF"              TO   : ALL / SELF / OTHER
    "MANSAY"            TYPE : MINE / MANSAY / PETSAY / GAME / NEWS
    "..."               文案（含 <SOMEONE> <NUMBER> <CARDNAME> <ROAD> <STOCKNAME> 等占位符）

消息 id 编号规律（原版注释「信息的序号不能变动」）：
    1xxx  角色对白（MANSAY）  10xx=角色1 … 1cxx=角色12，每角色 27 条
    2xxx  宠物对白（PETSAY）  N01..N09
    3xxx  ?
    9xxx  界面/查询字串（卡片查询 9001-9042 等）
    6xxx  其它

输出：
    .workbuddy/r6msg/info_all.json     全部条目
    .workbuddy/r6msg/info_index.txt    人工可读的紧凑索引
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = r"F:\游戏\Rich6\config\Info.txt"
OUTDIR = os.path.join(ROOT, ".workbuddy", "r6msg")

# 1001攻击\t{  5001 , "SELF", "MANSAY", "文案" }
# 住院            {  1 , "SELF", "MINE",, "<SOMEONE>住院" }   <- MINE/NEWS/GAME 多一个空字段
LINE = re.compile(r'^\s*(?P<mid>\d+)?\s*(?P<label>[^\t{]*?)\s*\{(?P<body>[^}]*)\}')
GROUP = re.compile(r"^\s*//\s*(.*?)\s*$")


def split_fields(body):
    """按逗号切分，但尊重双引号（文案里可能有半角逗号）。"""
    out, buf, inq, esc = [], [], False, False
    for ch in body:
        if esc:
            buf.append(ch)
            esc = False
            continue
        if ch == "\\":
            esc = True
            buf.append(ch)
            continue
        if ch == '"':
            inq = not inq
            continue
        if ch == "," and not inq:
            out.append("".join(buf).strip())
            buf = []
            continue
        buf.append(ch)
    out.append("".join(buf).strip())
    return out


def parse(path):
    src = open(path, "rb").read().decode("gbk", errors="replace")
    items = []
    group = ""
    for raw in src.splitlines():
        line = raw.rstrip()
        if not line.strip():
            continue
        g = GROUP.match(line)
        if g:
            t = g.group(1)
            # 只把有内容的注释当分组名（跳过分隔线 // 与纯说明）
            if t:
                group = t
            continue
        m = LINE.match(line)
        if m:
            f = split_fields(m.group("body"))
            if len(f) < 4:
                continue
            # f = [snd, TO, TYPE, (EXTRA,) TEXT]   —— 文案恒为最后一栏
            try:
                first = int(f[0])
            except ValueError:
                continue
            # MANSAY/PETSAY 行有「消息 id」数字前缀，花括号首栏为**配音 id**；
            # MINE/NEWS/GAME 行无前缀，花括号首栏即**消息 id**，无配音。
            if m.group("mid"):
                mid, snd = int(m.group("mid")), first
            else:
                mid, snd = first, 0
            items.append(dict(
                mid=mid,
                label=m.group("label"),
                snd=snd,
                to=f[1],
                type=f[2],
                extra=f[3] if len(f) >= 5 else "",
                text=f[-1],
                group=group,
            ))
    return items


def main():
    if not os.path.exists(SRC):
        print("找不到", SRC)
        return 1
    items = parse(SRC)
    os.makedirs(OUTDIR, exist_ok=True)
    dst = os.path.join(OUTDIR, "info_all.json")
    with open(dst, "w", encoding="utf-8") as f:
        json.dump(items, f, ensure_ascii=False, indent=1)

    # 紧凑索引
    idx = os.path.join(OUTDIR, "info_index.txt")
    with open(idx, "w", encoding="utf-8") as f:
        cur = None
        for it in items:
            if it["group"] != cur:
                cur = it["group"]
                f.write(f"\n=== {cur} ===\n")
            f.write(f"  {it['mid']:>5} snd={it['snd']:<5} {it['type']:<7} {it['to']:<6} {it['label']}\n")

    # 统计
    from collections import Counter
    print(f"共解析 {len(items)} 条 -> {dst}")
    print("TYPE 分布:", dict(Counter(i["type"] for i in items)))
    print("分组数:", len({i["group"] for i in items}))
    rng = {}
    for it in items:
        rng.setdefault(it["type"], []).append(it["snd"])
    for t, v in rng.items():
        print(f"  {t:<7} snd 范围 {min(v)} ~ {max(v)}  条数 {len(v)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
