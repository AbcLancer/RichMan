#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""从原版 House.txt 生成 game/data/rules/houses.json

House.txt（GBK 纯文本，F:\\游戏\\Rich6\\config\\House.txt）结构：

    NumType = 6

    Type = Uptown
    nGrade = 12
             /*名字      文件      宽    长    升级费   基本租金   地价影响    附加-对商业 附加-对住宅 附加-对工业*/
    HouseData:    一级公寓     a0101     1     1     1000        1500         1            2           0           0
    ...

字段（House.txt 自己的注释行给出）：
    名字 / 文件 / 宽 / 长 / 升级费 / 基本租金 / 地价影响 / 附加-对商业 / 附加-对住宅 / 附加-对工业

语义（结合游戏内行为与 Info.txt 交叉印证）：
    * 「升级费」= 由**当前等级**升到下一等级要付的钱（元）
      —— Info.txt id 93「<ROAD>\\n升级费用<NUMBER>元\\n是否升级」。
    * 「基本租金」= 该等级地产被踩到时付的过路费基数（元）
      —— Info.txt id 94「此地属于<SOMEONE> 请付费用<NUMBER>元」。
    * 「宽/长」= 占地面积（格）。Uptown/Shop/Industry 各分 1x1 / 2x2 / 3x3 三档，
      每档若干级，合计 = nGrade。
    * 附加-对商业/住宅/工业：同街区其他建筑对该格的加成，具体公式原版未给
      —— 只原样存下，标注 TODO，不臆造公式。

用法：
    python tools/build_house_rules.py            # 读取默认路径并写 game/data/rules/houses.json
    python tools/build_house_rules.py <in> <out>
"""
from __future__ import annotations

import json
import os
import re
import sys

DEFAULT_SRC = r"F:\游戏\Rich6\config\House.txt"
DEFAULT_OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                           "game", "data", "rules", "houses.json")

# House.txt 的 Type 名 → 工程内 id / 中文名 / 该主题的建筑 id 家族前缀
TYPE_ALIAS = {
    "Uptown":   ("uptown",   "住宅区", "a"),
    "Shop":     ("shop",     "商业区", "b"),
    "Industry": ("industry", "工业区", "c"),
    "Special1": ("special1", "特殊建筑·增值（俱乐部/银行/大酒店）", "d2"),
    "Special2": ("special2", "特殊建筑·公益（花园/连锁店/公园）",   "d1"),
    "Special3": ("special3", "特殊建筑·减益（垃圾场/发电厂/研究所）", "d3"),
}

# 工程内用于挑建筑的顺序（越靠前越优先）
PRIMARY_TYPES = ["uptown", "shop", "industry"]

FIELDS = ["name", "file", "w", "h", "upgrade_cost", "base_rent",
          "price_effect", "add_shop", "add_uptown", "add_industry"]

INT_FIELDS = ["w", "h", "upgrade_cost", "base_rent",
              "price_effect", "add_shop", "add_uptown", "add_industry"]


def read_gbk(path: str) -> str:
    with open(path, "rb") as fh:
        raw = fh.read()
    for enc in ("gbk", "gb18030", "cp936"):
        try:
            return raw.decode(enc)
        except UnicodeDecodeError:
            continue
    return raw.decode("gbk", errors="replace")


def parse(path: str) -> dict:
    text = read_gbk(path).replace("\r\n", "\n").replace("\r", "\n")
    types: dict = {}
    order: list = []
    cur_id = None
    num_type = 0

    for lineno, raw in enumerate(text.split("\n"), 1):
        line = raw.split("/*")[0].split("//")[0].strip()
        if not line:
            continue

        m = re.match(r"^NumType\s*=\s*(\d+)$", line)
        if m:
            num_type = int(m.group(1))
            continue

        m = re.match(r"^Type\s*=\s*(\S+)$", line)
        if m:
            raw_type = m.group(1)
            if raw_type not in TYPE_ALIAS:
                raise SystemExit("未知 Type: %s (第 %d 行)" % (raw_type, lineno))
            tid, cn, fam = TYPE_ALIAS[raw_type]
            cur_id = tid
            types[tid] = {
                "raw_type": raw_type,
                "cn": cn,
                "family": fam,
                "n_grade": 0,
                "grades": [],
            }
            order.append(tid)
            continue

        m = re.match(r"^nGrade\s*=\s*(\d+)$", line)
        if m:
            if cur_id is None:
                raise SystemExit("nGrade 出现在任何 Type 之前（第 %d 行）" % lineno)
            types[cur_id]["n_grade"] = int(m.group(1))
            continue

        if line.startswith("HouseData"):
            if cur_id is None:
                raise SystemExit("HouseData 出现在任何 Type 之前（第 %d 行）" % lineno)
            toks = line.split()
            # toks[0] 是 "HouseData:"，之后 10 个字段
            vals = toks[1:]
            if len(vals) != len(FIELDS):
                raise SystemExit("第 %d 行字段数 %d != %d：%r"
                                 % (lineno, len(vals), len(FIELDS), raw.strip()))
            g = {"level": len(types[cur_id]["grades"]) + 1}
            for k, v in zip(FIELDS, vals):
                if k in INT_FIELDS:
                    g[k] = int(v)
                else:
                    g[k] = v
            g["size"] = "%dx%d" % (g["w"], g["h"])
            types[cur_id]["grades"].append(g)
            continue
        # 其它行（如 "//" 注释）忽略

    # 完整性校验：条数 == nGrade
    for tid in order:
        t = types[tid]
        if t["n_grade"] and len(t["grades"]) != t["n_grade"]:
            raise SystemExit("%s: nGrade=%d 但解析到 %d 条 HouseData"
                             % (tid, t["n_grade"], len(t["grades"])))
        if not t["n_grade"]:
            t["n_grade"] = len(t["grades"])

    if num_type and len(order) != num_type:
        raise SystemExit("NumType=%d 但解析到 %d 个 Type" % (num_type, len(order)))

    return types, order, num_type


def build_map(types: dict):
    """file 前缀 → type_id（如 'a0101' → 'uptown'，'d201' → 'special1'）"""
    out = {}
    for tid, t in types.items():
        for g in t["grades"]:
            out[g["file"]] = tid
    return out


def build_files(types: dict):
    """
    file → 该等级的全部信息（反查表）。

    游戏侧拿到的只有「模型 id」（a0101 / b0203 / d201），但渲染时要按
    House.txt 的「宽/长」把房子放大（1x1 / 2x2 / 3x3），所以需要一条
    file → (w, h, 主题, 等级) 的 O(1) 反查路径，避免每次遍历 grades。
    """
    out = {}
    for tid, t in types.items():
        for g in t["grades"]:
            out[g["file"]] = {
                "type": tid,
                "cn": t["cn"],
                "family": t["family"],
                "level": g["level"],
                "name": g["name"],
                "w": g["w"],
                "h": g["h"],
                "size": g["size"],
            }
    return out


def main() -> int:
    src = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_SRC
    out = sys.argv[2] if len(sys.argv) > 2 else DEFAULT_OUT
    if not os.path.exists(src):
        print("找不到 %s" % src, file=sys.stderr)
        return 1

    types, order, num_type = parse(src)

    doc = {
        "_source": src,
        "_note": ("原版房屋等级表。House.txt 的每一行 HouseData = 一个等级，顺序即升级顺序。"),
        "_upgrade_cost_semantics": ("「升级费」= **建成该等级房屋的造价**，即由上一级升到本级的费用。"
                                    "判据：同一尺寸档内造价恒定（公寓 a01xx 全 1000、住宅 a02xx 全 2000、"
                                    "住宅区 a03xx 全 3000），且随尺寸档单调递增 —— 越大的房子越贵；"
                                    "反过来把「升级费」读作「离开本级的费用」会让最后一档 "
                                    "（如四级住宅区 a0304）的费用悬空无处可去。"),
        "_fields": FIELDS,
        "_field_cn": ["名字", "文件", "宽", "长", "升级费", "基本租金",
                      "地价影响", "附加-对商业", "附加-对住宅", "附加-对工业"],
        "_level_semantics": {
            "0": "空地（已买下但未建设）→ 无房屋模型",
            "1..n_grade": "对应 grades[level-1]",
        },
        "_todo": ("附加-对商业/住宅/工业 的合成公式原版未给出（House.txt 只有数值、"
                  "无可执行逻辑），故只原样存档，未参与租金计算。"),
        "num_type": num_type,
        "type_order": order,
        "primary_types": PRIMARY_TYPES,
        "file_to_type": build_map(types),
        "files": build_files(types),
        "types": types,
    }

    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w", encoding="utf-8", newline="\n") as fh:
        json.dump(doc, fh, ensure_ascii=False, indent=2)
        fh.write("\n")

    total = sum(len(types[t]["grades"]) for t in order)
    print("[houses] %s → %s" % (src, out))
    for tid in order:
        t = types[tid]
        print("  %-9s %-9s nGrade=%-3d  %s → %s" % (
            tid, t["raw_type"], t["n_grade"],
            t["grades"][0]["name"], t["grades"][-1]["name"]))
    print("  合计 %d 个等级" % total)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
