#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
大富翁6 (Richman 6, Softstar 2002) gamedata.pck 解包/打包工具

格式（逆向确认，见 docs/asset-format.md）:
  Header : b"PCK\\0" + u32 unknown
  Directory: 条目数组，固定步长 264 字节，从文件偏移 8 开始
  Entry  : [u8 flag=0][char name[] GBK, NUL 结尾][zero padding]
           尾部 8 字节: [u8 pad=0][u32 data_offset][u24 data_size]
  数据区 : 各文件连续存放，未压缩

校验: entry[i].offset + entry[i].size == entry[i+1].offset

用法:
  python r6pck.py list  <pck> [-o list.txt]
  python r6pck.py extract <pck> <outdir> [--filter substr] [--limit N]
  python r6pck.py info  <pck>
"""
import os
import struct
import sys
import json

MAGIC = b"PCK\0"
STRIDE = 264
DIR_START = 8


def read_entries(pck_path):
    with open(pck_path, "rb") as f:
        head = f.read(DIR_START)
        if head[:3] != b"PCK":
            raise ValueError("not a PCK file: magic=%r" % head[:4])
        unknown = struct.unpack("<I", head[4:8])[0]

        entries = []
        pos = DIR_START
        for idx in range(300000):
            f.seek(pos)
            seg = f.read(STRIDE)
            if len(seg) < STRIDE:
                break
            # name: NUL-terminated GBK from seg[1:]
            nul = seg.find(b"\0", 1)
            raw = seg[1:nul] if nul > 0 else b""
            if not raw:
                break
            try:
                name = raw.decode("gbk")
            except UnicodeDecodeError:
                break
            if not all(32 <= c or c in (9,) for c in raw):
                break
            tail = seg[-8:]
            off = struct.unpack("<I", tail[1:5])[0]
            size = tail[5] | (tail[6] << 8) | (tail[7] << 16)
            if off == 0 or off >= os.path.getsize(pck_path):
                break
            entries.append({"index": idx, "name": name, "offset": off, "size": size})
            pos += STRIDE
        return unknown, entries


def cmd_info(path):
    unknown, ents = read_entries(path)
    total = sum(e["size"] for e in ents)
    print("file      :", path, "(%.1f MB)" % (os.path.getsize(path) / 1048576))
    print("header u32:", unknown, hex(unknown))
    print("entries   :", len(ents))
    print("data bytes:", total, "(%.1f MB)" % (total / 1048576))
    print("dir bytes :", DIR_START + len(ents) * STRIDE)
    # 校验连续性
    bad = 0
    for a, b in zip(ents, ents[1:]):
        if a["offset"] + a["size"] != b["offset"]:
            bad += 1
    print("contiguity: %s (%d breaks)" % ("OK" if bad == 0 else "BROKEN", bad))
    # 扩展名统计
    from collections import Counter
    c = Counter(os.path.splitext(e["name"])[1].lower() for e in ents)
    print("ext top20 :", c.most_common(20))
    # 顶层目录
    top = Counter(e["name"].split("/")[0] for e in ents)
    print("top dirs  :", top.most_common(40))


def cmd_list(path, out=None):
    unknown, ents = read_entries(path)
    lines = ["%-7s %10s  %s" % (e["index"], e["size"], e["name"]) for e in ents]
    text = "\n".join(lines)
    if out:
        with open(out, "w", encoding="utf-8") as f:
            f.write(text)
        print("wrote %d entries -> %s" % (len(ents), out))
    else:
        print(text)


def cmd_extract(path, outdir, filt=None, limit=None):
    unknown, ents = read_entries(path)
    sel = [e for e in ents if (filt is None or filt.lower() in e["name"].lower())]
    if limit:
        sel = sel[:limit]
    with open(path, "rb") as f:
        for e in sel:
            dst = os.path.join(outdir, e["name"].replace("/", os.sep))
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            f.seek(e["offset"])
            data = f.read(e["size"])
            with open(dst, "wb") as g:
                g.write(data)
    print("extracted %d file(s) -> %s" % (len(sel), outdir))


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        return 1
    cmd, path = sys.argv[1], sys.argv[2]
    if cmd == "info":
        cmd_info(path)
    elif cmd == "list":
        out = None
        if "-o" in sys.argv:
            out = sys.argv[sys.argv.index("-o") + 1]
        cmd_list(path, out)
    elif cmd == "extract":
        outdir = sys.argv[3]
        filt = None
        limit = None
        if "--filter" in sys.argv:
            filt = sys.argv[sys.argv.index("--filter") + 1]
        if "--limit" in sys.argv:
            limit = int(sys.argv[sys.argv.index("--limit") + 1])
        cmd_extract(path, outdir, filt, limit)
    else:
        print(__doc__)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
