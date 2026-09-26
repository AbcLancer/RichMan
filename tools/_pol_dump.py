# -*- coding: utf-8 -*-
"""_pol_dump.py —— 原样 dump .pol 的顶点记录与材质/索引区，用于人工辨别字段布局。"""
import struct
import sys

HEADER = 144
STRIDE = 32


def main(path):
    b = open(path, "rb").read()
    nv = struct.unpack_from("<I", b, 124)[0]
    name = b[8:40].split(b"\0")[0].decode("latin1", "replace")
    print("file=%s size=%d name=%s nv=%d" % (path, len(b), name, nv))
    print("header 144B:")
    for i in range(0, 144, 16):
        print("  %04x %s | %s" % (i, b[i:i + 16].hex(" "),
                                  "".join(chr(c) if 32 <= c < 127 else "." for c in b[i:i + 16])))
    print("-" * 100)
    print("vertex records (32B each) — 8 x f32 逐条:")
    hdr = ["f0", "f1", "f2", "f3", "f4", "f5", "f6", "f7"]
    print("  #    " + "".join("%-11s" % h for h in hdr))
    for k in range(min(nv, int(sys.argv[2]) if len(sys.argv) > 2 else 20)):
        o = HEADER + STRIDE * k
        fs = [struct.unpack_from("<f", b, o + 4 * j)[0] for j in range(8)]
        print("  %-4d " % k + "".join("%-11.4f" % v for v in fs))
    end = HEADER + STRIDE * nv
    print("-" * 100)
    print("材质块 + 索引区（%d .. %d）:" % (end, len(b)))
    for i in range(end, len(b), 16):
        chunk = b[i:i + 16]
        print("  %04x %s | %s" % (i, chunk.hex(" "),
                                  "".join(chr(c) if 32 <= c < 127 else "." for c in chunk)))


if __name__ == "__main__":
    main(sys.argv[1])
