# -*- coding: utf-8 -*-
"""
pol_struct.py —— 用「几何硬判据」重新验证 .pol 的字段语义（2026-09-26）

判据（比之前的"面内角一致性"强得多）：
  Q1  三角形拓扑：退化面数 / 边共享统计（每条边被几个面用） / 顶点使用次数分布
  Q2  几何法线 vs 字段三元组：对每个三角形算 N = normalize((P1-P0)x(P2-P0))，
      再枚举 8 个字段里所有三元组，统计"三个顶点的该三元组都 ≈ N"的面占比
      → 命中率最高的三元组就是法线
  Q3  UV 候选：去掉法线字段后剩下 5 个字段，两两组合算 UV 三角形：
      - 有向面积符号是否一致（全同号 = 没翻面）
      - 退化三角形数
      - 面积和 vs |面积和|（重叠度）
      - 边长比失真（UV 边长 / 3D 边长 的离散度）

用法：
    python tools/pol_struct.py <file.pol> [norepeat]
"""

import math
import os
import struct
import sys

HEADER = 144
STRIDE = 32
FIELDS = 8
FNAME = ["f0", "f1", "f2", "f3", "f4", "f5", "f6", "f7"]


def f32(b, o):
    return struct.unpack_from("<f", b, o)[0]


def u16(b, o):
    return struct.unpack_from("<H", b, o)[0]


def u32(b, o):
    return struct.unpack_from("<I", b, o)[0]


def load(path):
    b = open(path, "rb").read()
    assert b[:4] == b"R6HS", "%s 不是 R6HS" % path
    nv = u32(b, 124)
    recs = []
    for k in range(nv):
        o = HEADER + STRIDE * k
        recs.append([f32(b, o + 4 * j) for j in range(FIELDS)])
    vtx_end = HEADER + STRIDE * nv
    # 索引块：扫描 u32 tc + 3*tc u16 < nv，取 tc 最大
    best = None
    for p in range(max(0, vtx_end - 8), len(b) - 4, 2):
        c = u32(b, p)
        if c < 1 or c > 200000:
            continue
        if p + 4 + 6 * c > len(b):
            continue
        ok = True
        for i in range(3 * c):
            if u16(b, p + 4 + 2 * i) >= nv:
                ok = False
                break
        if ok and (best is None or c > best[1]):
            best = (p, c)
    return b, nv, recs, vtx_end, best


def v3(r):
    return (r[1], r[2], r[3])


def sub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def norm(a):
    m = math.sqrt(a[0] * a[0] + a[1] * a[1] + a[2] * a[2])
    return (a[0] / m, a[1] / m, a[2] / m) if m > 1e-12 else (0.0, 0.0, 0.0)


def dot(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def main(path):
    b, nv, recs, vtx_end, blk = load(path)
    print("=" * 72)
    print("%s   size=%d  v=%d  vtx_end=%d" % (path, len(b), nv, vtx_end))
    print("  material block = %d bytes   index@%s" % (
        (blk[0] - vtx_end) if blk else -1, blk[0] if blk else None))
    if blk is None:
        print("!! 没找到索引块")
        return
    idx_off, tc = blk
    tri = []
    for i in range(tc):
        a, bb, c = (u16(b, idx_off + 4 + 6 * i),
                    u16(b, idx_off + 4 + 6 * i + 2),
                    u16(b, idx_off + 4 + 6 * i + 4))
        tri.append((a, bb, c))
    tail = len(b) - (idx_off + 4 + 6 * tc)
    print("  tri=%d   index bytes=%d   tail=%d" % (tc, 4 + 6 * tc, tail))

    # ---------- Q1 拓扑 ----------
    print("-" * 72)
    print("Q1 三角形拓扑")
    deg = 0
    areas = []
    for (a, bb, c) in tri:
        p0, p1, p2 = v3(recs[a]), v3(recs[bb]), v3(recs[c])
        n = cross(sub(p1, p0), sub(p2, p0))
        ar = 0.5 * math.sqrt(n[0] ** 2 + n[1] ** 2 + n[2] ** 2)
        areas.append(ar)
        if ar < 1e-6:
            deg += 1
        if len({a, bb, c}) < 3:
            deg += 1
    print("  退化面(面积~0 或索引重复): %d / %d" % (deg, tc))
    from collections import Counter
    ec = Counter()
    for (a, bb, c) in tri:
        for e in ((a, bb), (bb, c), (c, a)):
            ec[tuple(sorted(e))] += 1
    dist = Counter(ec.values())
    print("  每条边被几个面共享的分布: %s" % dict(sorted(dist.items())))
    print("  → 闭合流形应几乎全是 2")
    vc = Counter()
    for t in tri:
        for v in t:
            vc[v] += 1
    unused = [i for i in range(nv) if vc[i] == 0]
    print("  顶点使用次数: min=%d max=%d  未使用顶点=%d %s"
          % (min(vc.values()), max(vc.values()), len(unused), unused[:12]))

    # ---------- Q2 几何法线 vs 字段三元组 ----------
    print("-" * 72)
    print("Q2 几何法线 vs 字段三元组（命中率 = 三顶点该三元组都 ≈ N 的面占比）")
    import itertools
    gnorms = []
    for (a, bb, c) in tri:
        p0, p1, p2 = v3(recs[a]), v3(recs[bb]), v3(recs[c])
        gnorms.append(norm(cross(sub(p1, p0), sub(p2, p0))))
    scores = []
    for comb in itertools.combinations(range(FIELDS), 3):
        hit = 0
        for ti, (a, bb, c) in enumerate(tri):
            gn = gnorms[ti]
            if gn == (0, 0, 0):
                continue
            good = True
            for v in (a, bb, c):
                fv = (recs[v][comb[0]], recs[v][comb[1]], recs[v][comb[2]])
                if math.sqrt(sum(x * x for x in fv)) < 1e-6:
                    good = False
                    break
                if dot(norm(fv), gn) < 0.9:
                    good = False
                    break
            if good:
                hit += 1
        scores.append((hit / float(tc), comb))
    scores.sort(reverse=True)
    for s, comb in scores[:8]:
        print("   %-14s  %.1f%%" % ("(" + ",".join(FNAME[i] for i in comb) + ")", s * 100))
    normal_comb = scores[0][1]
    print("  → 法线字段 = (%s)" % ",".join(FNAME[i] for i in normal_comb))
    print("  → 位置字段 = (f1,f2,f3)")
    rest = [i for i in range(FIELDS) if i not in normal_comb and i not in (1, 2, 3)]
    print("  → 剩下的字段 = (%s)  只剩 2 个 → 必然是 UV" % ",".join(FNAME[i] for i in rest))
    if len(rest) != 2:
        print("  ⚠️ 剩余字段不是 2 个，说明位置字段假设或法线字段不对")

    # ---------- Q3 UV 质量 ----------
    print("-" * 72)
    print("Q3 UV 三角形质量（候选 = 剩余两字段）")
    for pair in [tuple(rest)] if len(rest) == 2 else list(itertools.combinations(rest, 2)):
        pos_s = neg_s = zero_s = 0
        sarea = 0.0
        ratios = []
        for (a, bb, c) in tri:
            uv = [(recs[v][pair[0]], recs[v][pair[1]]) for v in (a, bb, c)]
            (u0, v0), (u1, v1), (u2, v2) = uv
            ar = 0.5 * ((u1 - u0) * (v2 - v0) - (u2 - u0) * (v1 - v0))
            if abs(ar) < 1e-9:
                zero_s += 1
            elif ar > 0:
                pos_s += 1
            else:
                neg_s += 1
            sarea += ar
            p0, p1, p2 = v3(recs[a]), v3(recs[bb]), v3(recs[c])
            for (P, Q) in ((p0, p1), (p1, p2), (p2, p0)):
                d3 = math.sqrt(sum(x * x for x in sub(Q, P)))
                d2 = math.hypot((uv[1][0] - uv[0][0]), (uv[1][1] - uv[0][1]))
                if d3 > 1e-6:
                    ratios.append(d2 / d3)
        ratios.sort()
        lab = "(" + ",".join(FNAME[i] for i in pair) + ")"
        print("  %-10s  有向面积 正/负/零=%d/%d/%d   净面积=%.3f"
              % (lab, pos_s, neg_s, zero_s, sarea))
        if ratios:
            med = ratios[len(ratios) // 2]
            print("             边长比(uv/3d) 中位=%.5f  min=%.5f max=%.5f  max/med=%.1f"
                  % (med, ratios[0], ratios[-1], (ratios[-1] / med) if med > 0 else 0))
        print("             判据: 理想展开 → 全同号 / 零退化 / 净面积≈Σ|面积| / max-med 小")


if __name__ == "__main__":
    main(sys.argv[1])
