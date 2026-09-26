#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
由原版大富翁6 数据生成工程用地图 JSON。

数据来源（全部为原版真实数据，非杜撰）:
  - samples/scene/<map>/street.txt   街道名列表
  - samples/scene/<map>/<map>.txt    地图经济设定（虚拟公司、标志位置坐标）
  - F:/游戏/Rich6/config/Roadevent.txt  16 种事件点定义
  - F:/游戏/Rich6/config/House.txt      建筑类型与尺寸

棋盘构造规则:
  tile 0 = 起点
  其后循环: [该街道的 4 个地产格] (+ 该街之后可能有 1 个事件格)
  事件格数量按图配置，见 `EVENTS_OVERRIDE`：
    - aiji（埃及）：22 街 × 4 + 5 事件 + 1 起点 = **94 格**（原版 `aiji.r6m` ΣA = 94）
    - 其余地图：每街 1 个事件格（无原版格数证据，沿用历史规则）

用法: python tools/build_map.py
输出: game/data/maps/*.json
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SAMPLES = os.path.join(ROOT, "samples", "scene")
OUT = os.path.join(ROOT, "game", "data", "maps")
GAME = r"F:\游戏\Rich6"

# Roadevent.txt 的 16 种事件点（名称 → 资源名）
ROAD_EVENTS = [
    ("platform", "传送平台"), ("cardshop", "卡片商店"), ("hospital", "医院"),
    ("cardpt", "卡片点"), ("tvnews", "电视台"), ("labar", "拉霸"),
    ("capital", "市政府"), ("pethouse", "精灵屋"), ("game_a", "游戏点A"),
    ("game_b", "游戏点B"), ("credit", "点券"), ("casino", "乐透"),
]

PLOTS_PER_STREET = 4

# 逐图覆盖「全图事件格数」。
#   默认 None = 每条街后放 1 个事件格（历史规则，街头数即事件数）。
#   aiji 有原版权威格数：`aiji.r6m` 里 20 个街区各声明「宽 A 格」，**ΣA = 94 格**
#   （见 docs/orig-logic/aiji/r6m_blocks.*）。街道名表也是原版的 22 条
#   （`aiji.r6m` offset 148 = 22，152 起 22×16B 定长名字），于是
#       1 起点 + 22 街 × 4 地产 + 5 事件 = 94  ✔
#   5 个事件格均摊落到第 0/4/9/13/18 条街之后。
#   ⚠️ 原版数据里没有「每条街几个地产格」这个字段，94 与 22×4 的组合是本工程的选择，
#      若要改成别的分配（例如加事件格、减地产格），只改这张表。
EVENTS_OVERRIDE = {"aiji": 5}

MAP_CN = {
    "aiji": "埃及", "china": "中国", "island": "岛屿", "japan": "日本",
    "paris": "巴黎", "space": "太空", "train": "火车", "trybuild": "测试",
}


def read_gbk(path):
    with open(path, "rb") as f:
        return f.read().decode("gbk", errors="replace")


def parse_streets(mapdir, name):
    p = os.path.join(mapdir, "street.txt")
    if not os.path.exists(p):
        return []
    lines = [l.strip() for l in read_gbk(p).replace("\r", "").split("\n")]
    lines = [l for l in lines if l]
    if not lines:
        return []
    try:
        n = int(lines[0])
    except ValueError:
        n = len(lines)
    return lines[1:1 + n]


def parse_map_txt(mapdir, name):
    """解析 <map>.txt: 建筑开关 / 虚拟公司 / 标志位置"""
    p = os.path.join(mapdir, "%s.txt" % name)
    info = {"build_flags": {}, "companies": [], "landmarks": {}}
    if not os.path.exists(p):
        return info
    for raw in read_gbk(p).replace("\r", "").split("\n"):
        line = raw.split("//")[0].strip()
        if not line:
            continue
        if line.startswith("industry") or line.startswith("shop") or line.startswith("uptown"):
            for kv in line.split():
                parts = kv.split()
            toks = line.split()
            for i in range(0, len(toks) - 1, 2):
                info["build_flags"][toks[i]] = int(toks[i + 1])
        elif re.match(r"^[^\s]+\s+-?\d+(\.\d+)?\s+", line) and len(line.split()) == 4:
            toks = line.split()
            try:
                info["landmarks"][toks[0]] = [float(x) for x in toks[1:4]]
            except ValueError:
                pass
        else:
            toks = line.split()
            if len(toks) >= 3:
                try:
                    cap, shares = int(toks[1]), int(toks[2])
                except ValueError:
                    continue
                if cap > 1000 and shares > 0:
                    info["companies"].append({"name": toks[0], "capital": cap, "shares": shares})
    return info


def parse_camera(mapdir, name):
    """从 .r6m 头部读取相机俯角（最后一个 float，30 或 45）"""
    p = os.path.join(mapdir, "%s.r6m" % name)
    if not os.path.exists(p):
        return {"distance": 12.0, "yaw": 40.0}
    import struct
    d = open(p, "rb").read(0x50)
    fl = [struct.unpack("<f", d[o:o + 4])[0] for o in range(8, 0x50, 4)]
    return {"distance": 12.0, "yaw": fl[-1] if len(fl) >= 18 else 40.0}


def build_map(name):
    mapdir = os.path.join(SAMPLES, name)
    streets = parse_streets(mapdir, name)
    info = parse_map_txt(mapdir, name)
    cam = parse_camera(mapdir, name)

    n_ev = EVENTS_OVERRIDE.get(name)
    if n_ev is None:
        ev_slots = set(range(len(streets)))          # 历史规则：每条街后 1 个
    else:
        # 把 n_ev 个事件格**均摊**到各街之后（含第 0 街）
        ev_slots = set()
        for k in range(max(1, n_ev)):
            ev_slots.add(min(len(streets) - 1, int(round(k * len(streets) / float(n_ev)))))

    tiles = [{"i": 0, "kind": "start", "name": "起点"}]
    i = 1
    ev = 0
    for si, st in enumerate(streets):
        for pi in range(PLOTS_PER_STREET):
            tiles.append({
                "i": i, "kind": "plot",
                "street": st, "street_index": si, "plot_in_street": pi,
                "plot_key": "%02d%02d" % (si, pi),
            })
            i += 1
        if si not in ev_slots:
            continue
        eid, ename = ROAD_EVENTS[ev % len(ROAD_EVENTS)]
        t = {"i": i, "kind": "event", "event": eid, "name": ename}
        if ename in info["landmarks"]:
            t["pos"] = info["landmarks"][ename]
        tiles.append(t)
        i += 1
        ev += 1

    return {
        "_source": "gamedata.pck scene/%s  (原版数据生成)" % name,
        "name": name,
        "display_name": MAP_CN.get(name, name),
        "camera": cam,
        "build_flags": info["build_flags"],
        "virtual_companies": info["companies"],
        "landmarks": info["landmarks"],
        "streets": streets,
        "tile_count": len(tiles),
        "plots_per_street": PLOTS_PER_STREET,
        "tiles": tiles,
    }


def main():
    os.makedirs(OUT, exist_ok=True)
    if not os.path.isdir(SAMPLES):
        print("!! 未找到 %s，请先解包 scene/" % SAMPLES)
        return 1
    for name in sorted(os.listdir(SAMPLES)):
        d = os.path.join(SAMPLES, name)
        if not os.path.isdir(d):
            continue
        # Verified original road records supersede the historical synthetic layout.
        if name == "aiji":
            dst = os.path.join(OUT, "aiji.json")
            if os.path.isfile(dst):
                with open(dst, encoding="utf-8") as existing:
                    verified = json.load(existing)
                if "Original R6MP records" in verified.get("_source", ""):
                    print("aiji: 保留已恢复的原版 144 格；重建请用 tools/r6_map_verified.py")
                    continue
        m = build_map(name)
        dst = os.path.join(OUT, "%s.json" % name)
        with open(dst, "w", encoding="utf-8") as f:
            json.dump(m, f, ensure_ascii=False, indent=1)
        print("%-10s %2d 街道  %3d 格  %2d 事件  %d 公司  -> %s"
              % (name, len(m["streets"]), m["tile_count"],
                 sum(1 for t in m["tiles"] if t["kind"] == "event"),
                 len(m["virtual_companies"]), os.path.basename(dst)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
