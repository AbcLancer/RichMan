#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""把小神仙的**原版数据**编成 `game/data/rules/pets.json`。

## 数据来源（三处，全部是原版文件，不臆造）

| 来源 | 给出什么 |
|---|---|
| `config/Pet.txt` | 9 只小神仙 × **4 个等级**，每只三行数字：<br>① 即时制-秒数 ② 回合制-次数 ③ **消耗点数**<br>+ 素材目录名（qiongshen / hutu / …） |
| `config/String.txt` 2201..2209 | **技能名**：穷神技 罚金加倍 / 梦游技 强迫梦游 / 拆除技 拆除房屋 / 免费技 免付房租 / 土神技 强制占地 / 加盖技 升级房屋 / 无敌技 无敌状态 / 骰子技 遥控骰子 / PK技 攻击小神仙 |
| `config/Info.txt` 202 | **持有上限**：「您已拥有5位小神仙，此时不能请神！」 |
| `config/Info.txt` 191..196 / 203 | 特技在**受害者侧**看到的文案 / 购买确认文案「<BABYNAME>价格<NUMBER>点券 确认要购买吗？」 |

⚠️ 我们是**即时制** → 取第 ① 行（秒数），第 ② 行（回合制次数）只留档。
⚠️ `Info.txt` 203 的 `<NUMBER>`（购买价格）**原版没有给出具体数值** →
本工具取 `Pet.txt` 第 ③ 行第 1 级值当购买价（那是唯一可用的数字），
登记为**推断**（见 `docs/decision-log.md §16`）。

## 用法

    .workbuddy/venv/Scripts/python.exe tools/build_pet_data.py
"""

from __future__ import annotations

import io
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "docs", "original-readable", "installation", "config")
PETTXT = os.path.join(SRC, "Pet.txt")
STRINGTXT = os.path.join(SRC, "String.txt")
OUT = os.path.join(ROOT, "game", "data", "rules", "pets.json")

# String.txt 2201..2209 = 技能名；这里把「技能名」映射到我们 Sim 里的 effect 键。
# ⚠ 这个映射**原版没有**（配置里只有中文技能名）→ 是按技能名 + Info.txt 的受害者文案
#   （191..196）对上来的推导，登记在 docs/ui-audit.md / decision-log。
SKILL_EFFECT = {
    "qiongshen": "curse_rent_double",   # 穷神技 罚金加倍 → 挂一个对手：他付的租金翻倍
    "hutu": "sleep_nearby",             # 梦游技 强迫梦游 → 周围对手梦游（冬眠）
    "emo": "demolish_enemy",            # 拆除技 拆除房屋 → 拆对手一栋房
    "caishen": "free_rent",             # 免费技 免付房租 → 自己 N 秒免租
    "tushen": "seize_enemy_plot",       # 土神技 强制占地 → 强占对手一处地
    "jingling": "free_upgrade",         # 加盖技 升级房屋 → 自己一栋房免费升一级
    "huaxian": "invincible",            # 无敌技 无敌状态 → 自己无敌
    "dushen": "max_dice",               # 骰子技 遥控骰子 → 下一掷取最大点数
    "guaishou": "attack_pet",           # PK技 攻击小神仙 → 打掉对手一只小神仙
}

NUM_RE = re.compile(r"^\s*(\d+(?:\s+\d+)*)\s*//")


def parse_pet_txt(path: str) -> list[dict]:
    """Pet.txt：每只三段 —— 名字+目录行、即时制行、回合制行、消耗点数行。"""
    lines = io.open(path, encoding="utf-8", errors="replace").read().splitlines()
    out: list[dict] = []
    i = 0
    while i < len(lines):
        head = lines[i].strip()
        if not head:
            i += 1
            continue
        parts = head.split()
        if len(parts) < 2:
            i += 1
            continue
        name, d = parts[0], parts[1]
        nums = []
        for k in (1, 2, 3):
            if i + k >= len(lines):
                break
            m = NUM_RE.match(lines[i + k])
            nums.append([int(x) for x in m.group(1).split()] if m else [])
        if len(nums) == 3 and all(len(x) == 4 for x in nums):
            out.append({"name": name, "dir": d,
                        "realtime_seconds": nums[0], "turn_times": nums[1],
                        "points": nums[2]})
        i += 4
    return out


def parse_skill_names(path: str) -> dict[int, str]:
    """String.txt 2201..2209 → {消息 id: '穷神技  罚金加倍'}（顺带返回 raw 便于核对）。"""
    out: dict[int, str] = {}
    for ln in io.open(path, encoding="utf-8", errors="replace").read().splitlines():
        m = re.search(r"\{\s*(\d+)\s*,\s*\"([^\"]*)\"", ln)
        if not m:
            continue
        mid = int(m.group(1))
        if 2201 <= mid <= 2209:
            out[mid] = m.group(2)
    return out


def main() -> int:
    pets = parse_pet_txt(PETTXT)
    skills = parse_skill_names(STRINGTXT)
    if len(pets) != 9:
        print(f"⚠ Pet.txt 解析出 {len(pets)} 只（期望 9）")
    if len(skills) != 9:
        print(f"⚠ String.txt 2201..2209 解析出 {len(skills)} 条（期望 9）")

    records = []
    for i, p in enumerate(pets):
        sid = 2201 + i
        raw = skills.get(sid, "")
        # 「穷神技  罚金加倍」→ skill / skill_desc
        bits = re.split(r"\s{2,}", raw.strip(), maxsplit=1)
        skill = bits[0] if bits and bits[0] else ""
        desc = bits[1] if len(bits) > 1 else ""
        records.append({
            "id": p["dir"],
            "name": p["name"],
            "dir": p["dir"],
            "skill_id": sid,
            "skill": skill,
            "skill_desc": desc,
            "skill_raw": raw,
            "effect": SKILL_EFFECT.get(p["dir"], ""),
            # 即时制取第 ① 行；回合制第 ② 行只留档
            "seconds": p["realtime_seconds"],
            "turn_times": p["turn_times"],
            "points": p["points"],
            "buy_price": p["points"][0],     # ← 推断，见文件头注释
        })

    doc = {
        "_source": "F:\\游戏\\Rich6\\config\\Pet.txt（9 只 × 4 级：即时制秒数 / 回合制次数 /"
                   " 消耗点数）+ config\\String.txt 2201..2209（技能名）+ config\\Info.txt 202"
                   "（持有上限 5 位）",
        "_columns": "seconds / turn_times / points 都是**4 个等级**的值，下标 0 = 1 级。"
                    "即时制用 seconds。",
        "_inferred": {
            "buy_price": "Info.txt 203「<BABYNAME>价格<NUMBER>点券」没给具体值 → 取 Pet.txt"
                         "『消耗点数』第 1 级值（唯一可用数字）。属推断。",
            "effect": "原版只有中文技能名，`effect` 是按技能名 + Info.txt 191..196 的受害者"
                      "文案对上来的映射，属推断。",
            "seconds_semantics": "解释为『特技持续 / 冷却秒数』：发动后该小神仙要等"
                                 "seconds[level-1] 秒才能再发动。",
        },
        "max_owned": 5,
        "max_owned_source": "Info.txt 202「您已拥有5位小神仙，此时不能请神！」",
        "pets": records,
    }

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with io.open(OUT, "w", encoding="utf-8", newline="\n") as f:
        json.dump(doc, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print(f"写入 {OUT}")
    for r in records:
        print("  %-10s %-9s %-8s %-10s sec=%-16s pts=%-12s buy=%d"
              % (r["name"], r["id"], r["skill"], r["effect"],
                 r["seconds"], r["points"], r["buy_price"]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
