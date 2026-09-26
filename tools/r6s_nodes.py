# -*- coding: utf-8 -*-
"""
r6s_nodes.py —— 从场景文件 `.r6s`(R6SM) 里提取原版的**地产块节点**并另存，供对照。

背景（来源：`samples/scene/japan/场景.txt`，原版《地图制作的要求》）
--------------------------------------------------------------------
  「每一个场景随着路面有一条 Bezier 曲线……路线的名字为 **R6_Route_1**」
  「对每一大块地产格，用平面（Plane）来表示，名字为 **R6_Bblock_AXB_i**，
    A 是宽几格，B 是长几格，i 是第几块地产，平面的宽为 A×100，长为 B×100」

实测（2026-09-25）：每张图的 `.r6s` 里确实有一串 `R6_Bblock_AXB_i` 节点，
每个节点后面跟着 **4 个 u32（网格顶点索引）** 和一个 **4×4 变换矩阵**，
矩阵是**行主序、行向量约定**（v' = v·M），所以**第 4 行 = 世界坐标**，前 3 行 = 旋转基。

产物
----
  docs/orig-scene/<map>.json   机读（name / A / B / idx / translation / **matrix** / found）
  docs/orig-scene/<map>.md     人读表
  docs/orig-scene/INDEX.md     全部地图汇总（块数、格数估算）

用法
----
  python tools/r6s_nodes.py                 # 全部地图
  python tools/r6s_nodes.py --src samples/scene --out docs/orig-scene
  python tools/r6s_nodes.py --map aiji      # 只做一张
  python tools/r6s_nodes.py --dump trybuild # 把原始节点区十六进制打印出来（逆向用）
"""

import argparse
import json
import math
import os
import re
import struct
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

NAME_FIELD = 16        # 节点名字段固定 16 字节（不足补 0，过长的名字正好填满）


def f32(b, o):
    return struct.unpack_from("<f", b, o)[0]


def u32(b, o):
    return struct.unpack_from("<I", b, o)[0]


def matrix_at(b, o):
    """o 处是否为「正交基 + 末行平移」的 4x4 矩阵；是则返回 (矩阵, 平移)。"""
    if o + 64 > len(b):
        return None
    m = [f32(b, o + 4 * i) for i in range(16)]
    # 行主序：(r0, r1, r2, t)
    for r in range(4):
        for c in range(4):
            v = m[r * 4 + c]
            if v != v or abs(v) > 1e6:      # NaN / 爆炸值
                return None
    rows = [m[0:3], m[4:7], m[8:11]]
    for r in rows:
        n = sum(x * x for x in r)
        if abs(n - 1.0) > 0.05:             # 基向量必须是单位长
            return None
    for i in range(3):
        for j in range(i + 1, 3):
            d = sum(rows[i][k] * rows[j][k] for k in range(3))
            if abs(d) > 0.06:               # 必须两两正交
                return None
    if abs(m[15] - 1.0) > 0.01:             # 齐次项
        return None
    t = (m[12], m[13], m[14])
    if sum(x * x for x in t) < 0.5:         # 平移不能为 0（方块要落在地图上）
        return None
    return m, t


def haxes(mat):
    """从 4×4 里挑出两条**水平轴**（|y| 最小的两行），返回 [(行号, 角度°), ...]。
    第 1 行实测恒为 (0,1,0) 法线，故水平轴必是第 0/2 行。"""
    if not mat:
        return []
    cand = []
    for r in range(3):
        cand.append((abs(mat[r][1]), r))
    cand.sort()
    out = []
    for _, r in cand[:2]:
        out.append((r, math.degrees(math.atan2(mat[r][2], mat[r][0]))))
    out.sort()
    return out


def parse(b):
    """返回节点列表（按文件顺序）。"""
    nodes = []
    for m in re.finditer(rb"R6_Route_1|R6_B[Bb]lock_[0-9]+[Xx][0-9]+_[0-9]+", b):
        off = m.start()
        name = m.group().decode("latin1")
        nm = re.match(r"R6_B[Bb]lock_([0-9]+)[Xx]([0-9]+)_([0-9]+)", name)
        idx = [u32(b, off + NAME_FIELD + 4 * i) for i in range(4)]
        # 矩阵：名字后 32 字节起（名字 16 + 索引 16）开始找，允许少量对齐偏移
        mat = None
        t = None
        for d in range(32, 96, 4):
            got = matrix_at(b, off + d)
            if got:
                mat, t = got
                break
        # 完整 4×4（行主序）：前 3 行 = 旋转基，第 4 行 = 世界平移。
        # 实测：第 1 行恒为 (0,1,0)（法线），第 0/2 行是两条水平轴 ——
        # 街区就是按这两条轴摆的，A 沿哪条轴要靠拟合实测（见 tools/fit_board_from_r6s.py）。
        mat4 = [[round(mat[r * 4 + c], 6) for c in range(4)] for r in range(4)] if mat else None
        nodes.append({
            "name": name,
            "kind": "block" if nm else "route",
            "A": int(nm.group(1)) if nm else 0,
            "B": int(nm.group(2)) if nm else 0,
            "index": int(nm.group(3)) if nm else 0,
            "idx": idx if all(v < 100000 for v in idx) else [],
            "translation": [round(v, 3) for v in t] if t else None,
            "matrix": mat4,
            "matrix_found": mat is not None,
            "offset": off,
        })
    return nodes


def dump_region(b, first_off, n=512):
    lo = max(0, first_off - 64)
    out = []
    for i in range(lo, min(len(b), lo + n), 16):
        ch = b[i:i + 16]
        out.append("  %06x  %-47s  |%s|" % (i, " ".join("%02x" % c for c in ch),
                                           "".join(c_ if 32 <= c_ < 127 else "." for c_ in ch)))
    return "\n".join(out)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", default=os.path.join(ROOT, "samples", "scene"))
    ap.add_argument("--out", default=os.path.join(ROOT, "docs", "orig-scene"))
    ap.add_argument("--map", default="")
    ap.add_argument("--dump", default="")
    a = ap.parse_args()

    src = os.path.abspath(a.src)
    out = os.path.abspath(a.out)

    if a.dump:
        p = os.path.join(src, a.dump, a.dump + ".r6s")
        b = open(p, "rb").read()
        m = re.search(rb"R6_Route_1", b)
        print("== %s（%d 字节）节点区 ==" % (p, len(b)))
        print(dump_region(b, m.start(), 1200) if m else "没找到 R6_Route_1")
        return

    os.makedirs(out, exist_ok=True)
    # ⚠️ --map 过滤运行时不得覆盖全量 INDEX.md
    tag = ("__" + a.map) if a.map else ""
    files = []
    for dp, dn, fn in os.walk(src):
        for f in fn:
            if f.lower().endswith(".r6s"):
                if a.map and not f.lower().startswith(a.map.lower()):
                    continue
                files.append(os.path.join(dp, f))
    files.sort()

    summary = []
    for p in files:
        rel = os.path.relpath(p, src).replace("\\", "/")
        b = open(p, "rb").read()
        nodes = parse(b)
        blocks = [n for n in nodes if n["kind"] == "block"]
        routes = [n for n in nodes if n["kind"] == "route"]
        plots = sum(n["A"] for n in blocks)          # 沿路方向格数估算
        cells = sum(n["A"] * n["B"] for n in blocks)  # 平面格数总和（含纵深）
        mapname = os.path.splitext(os.path.basename(p))[0]
        doc = {
            "file": rel, "bytes": len(b), "map": mapname,
            "route_nodes": routes, "blocks": blocks,
            "n_blocks": len(blocks), "sum_A": plots, "sum_AxB": cells,
        }
        with open(os.path.join(out, mapname + ".json"), "w", encoding="utf-8") as f:
            json.dump(doc, f, ensure_ascii=False, indent=1)

        L = ["# %s —— 原版地产块节点" % rel, "",
             "- 来源：`%s`（%d 字节）" % (rel, len(b)),
             "- 路线节点：%s" % (", ".join("`%s`" % x["name"] for x in routes) or "（无）"),
             "- 地产块 %d 个，ΣA = **%d**（沿路格数估算），Σ(A×B) = %d" % (len(blocks), plots, cells),
             "",
             "| # | 节点名 | A×B | 索引 id | 4 个顶点索引 | 世界坐标 (矩阵第4行) | 水平轴 (行号:角度°) | 矩阵 |",
             "|---|--------|-----|---------|--------------|----------------------|--------------------|------|"]
        for i, n in enumerate(blocks):
            t = n["translation"]
            ts = "(%.2f, %.2f, %.2f)" % tuple(t) if t else "**未定位**"
            ax = " · ".join("r%d:%.1f°" % (r, deg) for r, deg in haxes(n.get("matrix")))
            L.append("| %d | `%s` | %dx%d | %d | %s | %s | %s | %s |"
                     % (i + 1, n["name"], n["A"], n["B"], n["index"],
                        ",".join(str(v) for v in n["idx"]) or "-", ts,
                        ax or "-", "✔" if n["matrix_found"] else "✘"))
        L += ["", "> 坐标取自 4×4 变换矩阵的**第 4 行**（行主序 / 行向量约定 `v' = v·M`）。",
              "> 名字与 A×B 是**确定的**（原文规范 + 字符串直读）；",
              "> 坐标由「正交基 + 非零平移」启发式定位，**误差已核对但未逐块人工复核**。",
              "> 矩阵第 1 行实测**恒为 `(0,1,0)`（法线）**，第 0/2 行是两条水平轴；",
              "> 街区尺寸 = `A×100 × B×100`（1 格 = 100 世界单位，见《地图制作的要求》）。",
              "> 完整 4×4 存在 JSON 的 `matrix` 字段里，供 `tools/fit_board_from_r6s.py` 反推格点。", ""]
        with open(os.path.join(out, mapname + ".md"), "w", encoding="utf-8", newline="") as f:
            f.write("\n".join(L))

        ok = sum(1 for n in blocks if n["matrix_found"])
        summary.append((mapname, rel, len(blocks), plots, cells, ok, len(routes)))
        print("[r6s] %-14s 块 %2d  ΣA=%4d  Σ(A×B)=%5d  定位 %2d/%2d  路线 %d"
              % (mapname, len(blocks), plots, cells, ok, len(blocks), len(routes)))

    # ---- 汇总索引 ----
    L = ["# 原版场景节点索引（`tools/r6s_nodes.py` 生成，可重跑覆盖）", "",
         "每张图的 `.r6s` 里带着原版**地产块划分** `R6_Bblock_AXB_i` 与**路线曲线** `R6_Route_1`，",
         "依据是原版《地图制作的要求》（`docs/orig-logic/scene/japan/场景.txt`）。", "",
         "| 地图 | 文件 | 地产块数 | ΣA（沿路格数） | Σ(A×B) | 已定位坐标 | 路线节点 |",
         "|------|------|---------|---------------|--------|-----------|---------|"]
    if tag:
        L.insert(5, "> ⚠️ 这是按 `--map=%s` 过滤的**子集**，全量见 `INDEX.md`。\n" % a.map)
    for mapname, rel, nb, plots, cells, ok, nr in summary:
        L.append("| `%s` | `%s` | %d | %d | %d | %d/%d | %d |"
                 % (mapname, rel, nb, plots, cells, ok, nb, nr))
    L += ["", "## 怎么用", "",
          "- **地产块名单**：告诉我们原版每张图的街区怎么分、每个街区几格 —— 现在",
          "  `tools/build_map.py` 是按「街区序号轮转主题」猜的，可以改成照原版分块。",
          "- **世界坐标**：矩阵第 4 行就是该块中心在图上的位置，可以拿来校正",
          "  `game/data/maps/<map>_tilepos.json`（现在的坐标是「红框锚点 + 样条重建」推的）。",
          "- 每块的 `A×B` 配合「1 格 = 100 世界单位」可以反推块的实际尺寸，",
          "  与顶点索引一起能定位到 `.r6s` 网格里的那 4 个角点。", ""]
    with open(os.path.join(out, "INDEX%s.md" % tag), "w", encoding="utf-8", newline="") as f:
        f.write("\n".join(L))
    print("[r6s] 汇总 → %s" % os.path.join(out, "INDEX%s.md" % tag))


if __name__ == "__main__":
    main()
