#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""解析原版 `config/Role.txt`（12 个角色）→ `game/data/rules/roles.json`。

## 这张表一下子解决了两件事

| 列 | 含义 | 用途 |
|---|---|---|
| 人名 | 角色名 | 选人界面 |
| 模型目录 | `role1`..`role9` / `rolea/b/c` | 素材索引（**没有 role10/11/12**） |
| 害人积极性 / **买卖股票积极性** / 买地积极性 | 三项**性格权重** | **AI 行为**（我们原来是极简版，没用这三项） |
| **缺省公司** | 每个角色绑定的公司名 | ⭐ **股票系统的公司名来源** |
| 标示物 | `diamond` / `hat` / `knife` … | 随身物图标（`uitex/player/roleN_31`） |
| 标志色 | R G B | 角色配色 |

## ⭐ 「缺省公司」是怎么确认的

老板 2026-09-26 跑原版截了股票界面（`docs/screenshots/orig/records/`，见
`docs/orig-records-audit.md`），面板上是 **中华美食 / 新土地 / 第一宝藏 / 玛雅 / 阿里巴巴**。
前四个与 `Role.txt` 的缺省公司**逐字对上**（孙小美=中华美食、阿土伯=新土地、
宫本宝藏=第一宝藏、乌咪=玛雅），而且那一局玩家是**孙小美**、**持股 2000**
—— 正好等于 `Initvar_r.txt` 的 `Player_Com_SelfShares = 2000`。
→ **股票面板 = 各玩家以自己的「缺省公司」上市**，玩家初始持有本公司 2000 股。

（面板上第 5 行「阿里巴巴」不在这张表里，它是**地图的虚拟公司**之一
（`config/scene/aiji/Aiji.txt` 的 6 家）—— 说明面板也可能混排虚拟公司，登记为待查。）

⚠️ Role.txt 里**没有** `role10/11/12`，只有 `role1..9 + rolea/b/c`。

用法：

    .workbuddy/venv/Scripts/python.exe tools/build_role_data.py
"""

from __future__ import annotations

import io
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "docs", "original-readable", "installation",
                   "config", "Role.txt")
OUT = os.path.join(ROOT, "game", "data", "rules", "roles.json")


def main() -> int:
    lines = io.open(SRC, encoding="utf-8", errors="replace").read().splitlines()
    roles: list[dict] = []
    for raw in lines:
        s = raw.strip()
        if not s or s.startswith("//"):
            continue
        # 字段之间既有 tab 也有连续空格 → 一律按空白切
        f = re.split(r"\s+", s)
        if len(f) < 10:
            continue
        try:
            aggr = [int(f[2]), int(f[3]), int(f[4])]
            rgb = [int(f[7]), int(f[8]), int(f[9])]
        except ValueError:
            continue
        roles.append({
            "n": len(roles) + 1,
            "name": f[0],
            "model": f[1],              # role1..role9 / rolea/b/c
            # 三项性格权重：害人 / 买卖股票 / 买地（AI 用）
            "aggr": {"screw": aggr[0], "stock": aggr[1], "land": aggr[2]},
            "company": f[5],            # ⭐ 缺省公司 = 股票系统里的公司名
            "marker": f[6],             # 随身物素材名（uitex/player/roleN_31）
            "color": rgb,
        })
    doc = {
        "_source": "F:\\游戏\\Rich6\\config\\Role.txt（原版安装目录明文，UTF-8）",
        "_note": "第 6 列「缺省公司」= 该角色上市的公司名（股票系统用，老板实机截图确认）；"
                 "第 3~5 列是 AI 的三项性格权重。角色模型只有 role1..9 + rolea/b/c。",
        "count": len(roles),
        "roles": roles,
        # 便捷索引
        "by_model": {r["model"]: r for r in roles},
        "by_name": {r["name"]: r for r in roles},
        "companies": [r["company"] for r in roles],
    }
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with io.open(OUT, "w", encoding="utf-8", newline="\n") as fh:
        json.dump(doc, fh, ensure_ascii=False, indent=1)
        fh.write("\n")
    print("Role.txt → %s" % OUT)
    print("  角色 %d 个；缺省公司 %d 家" % (len(roles), len(doc["companies"])))
    for r in roles[:4]:
        print("    %-6s %-6s 公司=%-8s 性格=%s" % (
            r["name"], r["model"], r["company"], r["aggr"]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
