#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
大富翁6 地图文件 (.r6m) 结构分析器

已知结构（逆向中）:
  +0x00  char[4]  "R6MP"
  +0x04  u32      100          (疑似格子边长/版本)
  +0x08  float[]  一批参数 (0.8/0.5/1.0/0.7/0.4 ... )
  +0x50  char[]   "<map>.R6S\0"  场景文件名
  ...            0xCD 填充 (MSVC 未初始化内存)
  ...            u32 0, u32 n_street
  ...            n_street × 16 字节 GBK 街道名
  ...            疑似格子/道路网络数据
"""
import glob
import os
import struct
import sys

MAPS = ["aiji", "china", "island", "japan", "paris", "space", "train", "trybuild"]


def be_f32(b, o):
    return struct.unpack("<f", b[o:o + 4])[0]


def analyze(path):
    d = open(path, "rb").read()
    name = os.path.basename(path)
    print("=" * 72)
    print("%s  size=%d" % (name, len(d)))
    if d[:4] != b"R6MP":
        print("  !! magic mismatch:", d[:4])
        return
    print("  magic R6MP, u32@4 =", struct.unpack("<I", d[4:8])[0])
    print("  floats@0x08..0x50:")
    fl = [be_f32(d, o) for o in range(8, 0x50, 4)]
    print("   ", " ".join("%.4g" % f for f in fl))
    # 场景文件名
    z = d.index(b"\0", 0x50)
    print("  scene ref @0x50:", d[0x50:z].decode("latin1"))
    # 找 0xCD 填充结束后的 u32 对
    p = z + 1
    while p < len(d) and d[p] == 0xCD:
        p += 1
    print("  first non-CD @0x%X" % p)
    z2, n = struct.unpack("<II", d[p:p + 8])
    print("   u32[0]=%d  u32[1]=%d" % (z2, n))
    sp = p + 8
    streets = []
    for i in range(n):
        s = d[sp + i * 16: sp + i * 16 + 16]
        st = s.split(b"\0")[0]
        try:
            streets.append(st.decode("gbk"))
        except UnicodeDecodeError:
            streets.append("<bad>")
    print("   streets(%d):" % len(streets), " / ".join(streets))
    after = sp + n * 16
    print("  data after streets @0x%X, remaining=%d bytes" % (after, len(d) - after))
    # 观察后续
    rest = d[after:after + 64]
    print("   next64:", rest.hex(" "))
    return {"name": name, "n_street": n, "streets": streets,
            "after": after, "size": len(d)}


if __name__ == "__main__":
    base = sys.argv[1] if len(sys.argv) > 1 else "samples/scene"
    infos = []
    for m in MAPS:
        p = os.path.join(base, m, m + ".r6m")
        if os.path.exists(p):
            infos.append(analyze(p))
    print("\n" + "=" * 72)
    print("汇总")
    print("%-12s %8s %8s %8s %s" % ("map", "r6m", "n_street", "remain", "streets[:6]"))
    for i in infos:
        print("%-12s %8d %8d %8d %s" % (i["name"], i["size"], i["n_street"],
                                        i["size"] - i["after"], "/".join(i["streets"][:6])))
