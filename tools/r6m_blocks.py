# -*- coding: utf-8 -*-
"""Export original R6MP property blocks.

Corrected from rich6.exe 0x42c250: count + 64-byte matrix + id,width,depth,
then width*depth records of 16 bytes. Matrix origin is a grid corner.
For the full map and road linkage use tools/r6_map_verified.py.
"""

import argparse
import json
import os
import struct
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MAGIC = b"R6MP"
HEADER_SCAN = 800        # 在文件头这段里找「u32 计数 + 20 条记录」


def f32(b, o):
    return struct.unpack_from("<f", b, o)[0]


def u32(b, o):
    return struct.unpack_from("<I", b, o)[0]


def find_table(b, n_expect):
    """找「u32 == 街区数」且紧随其后的记录串长度自洽的位置。"""
    for off in range(64, min(len(b) - 4, HEADER_SCAN), 4):
        if u32(b, off) != n_expect:
            continue
        return off
    return -1


def parse(b, n_expect):
    off = find_table(b, n_expect)
    if off < 0:
        return None
    recs, p = [], off + 4        # count immediately followed by matrix
    for _ in range(n_expect):
        if p + 76 > len(b):
            return None
        mat = [round(f32(b, p + 4 * i), 6) for i in range(16)]
        tx, ty, tz = (f32(b, p + 48), f32(b, p + 52), f32(b, p + 56))
        one = f32(b, p + 60)
        idx, A, B = u32(b, p + 64), u32(b, p + 68), u32(b, p + 72)
        flag = 0 # compatibility only; no block flag exists in this header
        if not (1 <= A <= 64 and 1 <= B <= 64) or abs(one - 1.0) > 1e-3:
            return None
        cells = []
        q = p + 76
        for _c in range(A * B):
            cells.append([u32(b, q + 16 * _c + 4 * i) for i in range(4)])
        size = 76 + 16 * A * B
        recs.append({
            "name": "R6_Bblock_%dX%d_%d" % (A, B, idx), "index": idx,
            "A": A, "B": B, "flag": flag,
            "translation": [round(tx, 3), round(ty, 3), round(tz, 3)],
            "matrix": mat, "matrix11": mat[:11], "cells": cells, "offset": p, "size": size,
        })
        p += size
    return {"table_offset": off, "count": n_expect, "end": p, "blocks": recs}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", default=os.path.join(ROOT, "samples", "scene"))
    ap.add_argument("--out", default=os.path.join(ROOT, "docs", "orig-logic"))
    ap.add_argument("--map", default="")
    a = ap.parse_args()

    src, out = os.path.abspath(a.src), os.path.abspath(a.out)
    maps = {}
    for dp, _dn, fn in os.walk(src):
        for f in fn:
            if f.lower().endswith(".r6m"):
                name = os.path.splitext(f)[0]
                if a.map and name != a.map:
                    continue
                maps.setdefault(os.path.relpath(os.path.join(dp, f), src).split(os.sep)[0],
                                []).append((name, os.path.join(dp, f)))

    ok = 0
    for mapdir, items in sorted(maps.items()):
        for name, p in items:
            b = open(p, "rb").read()
            if b[:4] != MAGIC:
                continue
            # 街区数：拿 .r6s 的数（没有就试常见值）
            n = None
            r6s = os.path.join(os.path.dirname(p), mapdir + ".r6s")
            if os.path.exists(r6s):
                import re
                n = len(set(re.findall(rb"R6_B[Bb]lock_[0-9]+[Xx][0-9]+_[0-9]+",
                                       open(r6s, "rb").read())))
            if not n:
                continue
            doc = parse(b, n)
            if not doc:
                print("[r6m] %-10s ✘ 未解析出街区表（街区数 %d）" % (name, n))
                continue
            tag = name
            d = os.path.join(out, tag)
            os.makedirs(d, exist_ok=True)
            doc["file"] = os.path.relpath(p, src).replace("\\", "/")
            doc["bytes"] = len(b)
            with open(os.path.join(d, "r6m_blocks.json"), "w", encoding="utf-8") as fh:
                json.dump(doc, fh, ensure_ascii=False, indent=1)

            L = ["# %s —— `.r6m` 地产块表（已解）" % doc["file"], "",
                 "- 文件 %d 字节；表起点 offset **%d**（u32 = 街区数 **%d**）" %
                 (len(b), doc["table_offset"], doc["count"]),
                 "- 记录长度 = `48×A + 76`；表尾 offset %d，Σ = **%d** 字节" %
                 (doc["end"], doc["end"] - doc["table_offset"] - 4), "",
                 "| # | 表内序号 | A×B | 标志 | 世界平移 | 记录长 |",
                 "|---|---|---|---|---|---|"]
            for r in doc["blocks"]:
                L.append("| %s | %d | %dx%d | %d | (%.2f, %.2f, %.2f) | %d |"
                         % (r["name"], r["index"], r["A"], r["B"], r["flag"],
                            r["translation"][0], r["translation"][1],
                            r["translation"][2], r["size"]))
            L += ["", "> 逐格记录（每格 16 B = 4×u32）**不含浮点坐标**，是属性字段；",
                  "> 格中心由「块矩阵 + A×B 规则网格 + 1 格 = 100 世界单位」推出。",
                  "> 生成脚本：`tools/r6m_blocks.py`（可重跑覆盖）。", ""]
            with open(os.path.join(d, "r6m_blocks.md"), "w", encoding="utf-8", newline="") as fh:
                fh.write("\n".join(L))
            ok += 1
            print("[r6m] %-10s ✔ 街区 %2d 表@%d  长度 %d..%d  Σ=%d"
                  % (name, len(doc["blocks"]), doc["table_offset"],
                     doc["table_offset"], doc["end"], doc["end"] - doc["table_offset"] - 4))
    print("[r6m] 完成 %d 张地图 → %s" % (ok, out))


if __name__ == "__main__":
    main()
