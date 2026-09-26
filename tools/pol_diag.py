# -*- coding: utf-8 -*-
"""
pol_diag.py —— R6HS(.pol) 顶点记录的终极体检。

要回答两个问题：
  Q1  f0 / f4 / f5 / f6 / f7 这 5 个 float 里，哪 3 个是法线、哪 2 个是 UV？
      判据：法线三元组的模长应处处 ≈ 1；UV 的两分量值域应在 [0, k]。
  Q2  tools/r6pol.py 用启发式扫出来的索引块到底对不对？
      判据：合法三角网格的每条边应恰好被 2 个三角面共享（闭合流形）。
           若边出现次数分布散乱 → 索引块找错了，UV 布局图当然也就乱。

用法： python tools/pol_diag.py <file.pol>
"""
import itertools
import os
import struct
import sys
from collections import Counter

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import r6pol  # noqa: E402

HEADER = 144
FIELDS = [0, 4, 5, 6, 7]


def load(path):
    b = open(path, "rb").read()
    nv = struct.unpack_from("<I", b, 124)[0]
    n = min(nv, max(0, (len(b) - HEADER) // 32))
    f = np.frombuffer(b, dtype="<f4", count=n * 8, offset=HEADER).reshape(n, 8).astype(np.float64)
    u = np.frombuffer(b, dtype="<u4", count=n * 8, offset=HEADER).reshape(n, 8)
    m = r6pol.parse(path)
    tri = np.asarray(m["indices"], dtype=np.int64).reshape(-1, 3)
    return b, f, u, m, tri


def q_normals(f):
    print("=== Q1  哪 3 个字段是法线（模长 ≈ 1 的比例）===")
    best = []
    for c in itertools.combinations(FIELDS, 3):
        v = f[:, list(c)]
        ln = np.linalg.norm(v, axis=1)
        ok = float(np.mean(np.abs(ln - 1.0) < 0.02)) * 100
        best.append((ok, c))
    best.sort(reverse=True)
    for ok, c in best:
        tag = " ★" if ok > 60 else ""
        print("   %-14s 单位向量占比 %5.1f%%%s" % (str(c), ok, tag))
    print()
    print("   各字段原始 u32 取值（判断是否有字段其实是整数/标志而非 float）：")
    for i in FIELDS:
        vals, cnts = np.unique(f[:, i] if i in (0,) else None) if False else (None, None)
    return best


def q_u32(u, f):
    print("=== Q1b  各字段按 u32 读的取值分布 ===")
    for i in FIELDS:
        vals, cnts = np.unique(u[:, i], return_counts=True)
        order = np.argsort(-cnts)
        top = ["0x%08X×%d" % (vals[k], cnts[k]) for k in order[:6]]
        nanpct = float(np.mean(~np.isfinite(f[:, i]))) * 100
        print("   f%-2d  nan=%5.1f%%  唯一=%3d  top: %s" % (i, nanpct, len(vals), "  ".join(top)))
    print()


def q_edges(tri, nv):
    print("=== Q2  索引块的流形性 ===")
    c = Counter()
    for t in tri:
        a, b, d = int(t[0]), int(t[1]), int(t[2])
        for x, y in ((a, b), (b, d), (d, a)):
            c[(x, y) if x < y else (y, x)] += 1
    dist = Counter(c.values())
    tot = len(c)
    print("   nv=%d  三角面=%d  唯一边=%d" % (nv, len(tri), tot))
    print("   边的出现次数分布: %s" % dict(sorted(dist.items())))
    print("   → 恰好出现 2 次（闭合流形）的边占 %.1f%%"
          % (dist.get(2, 0) / max(tot, 1) * 100))
    used = len(set(tri.ravel().tolist()))
    print("   被索引到的顶点 %d / %d（%.1f%%）" % (used, nv, used / max(nv, 1) * 100))
    print()


def q_uvdensity(pos, uv, tri):
    print("=== Q3  UV 面积密度（UV 面积 / 3D 面积），均匀展开应彼此接近 ===")

    def area2(p):
        return 0.5 * np.abs((p[:, 1, 0] - p[:, 0, 0]) * (p[:, 2, 1] - p[:, 0, 1])
                            - (p[:, 2, 0] - p[:, 0, 0]) * (p[:, 1, 1] - p[:, 0, 1]))

    a3 = area2(pos[tri][:, :, [0, 2]])
    a2 = area2(uv[tri])
    ok = a3 > 1e-9
    r = a2[ok] / a3[ok]
    r = r[np.isfinite(r)]
    if not len(r):
        print("   无有效面")
        return
    print("   密度比 min=%.5f  中位=%.5f  max=%.5f" % (r.min(), np.median(r), r.max()))
    print("   max/中位 = %.1f 倍（真展开通常 < 5）" % (r.max() / max(np.median(r), 1e-9)))
    print()


def main():
    path = sys.argv[1]
    b, f, u, m, tri = load(path)
    print("### %s   nv=%d  tri=%d  size=%d\n" % (path, m["nv"], len(tri), m["size"]))
    q_normals(f)
    q_u32(u, f)
    q_edges(tri, m["nv"])
    pos = f[:, 1:4]
    q_uvdensity(pos, f[:, [4, 5]], tri)


if __name__ == "__main__":
    main()
