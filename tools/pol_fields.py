# -*- coding: utf-8 -*-
"""
pol_fields.py —— 把 R6HS(.pol) 顶点记录的 8 个 float 逐字段体检，
用来定位「真正的 UV 到底在哪两个字段」。

背景：tools/r6pol.py 与 tools/pol2obj.py 对同一段数据给了互相矛盾的解释
      （前者说 f4f5f6 = 法线，后者说 f4f5 = UV），得用数值判据一次性定死。

判据（对每个候选字段对 (a,b)）：
  1. 值域是否落在 [0,1]（或某个小正整数倍）—— UV 的典型特征
  2. 面内角一致性：同一个三角面在 3D 空间的内角 vs 在 (a,b) 空间的内角，
     两者偏差应 < 8°（真 UV）；随机数据约 45°（完全无关联）。
     这是最强判据，与平移/缩放/旋转无关。

用法：
  python tools/pol_fields.py dump   <file.pol> [n]      # 前 n 个顶点的 8 字段
  python tools/pol_fields.py stat   <file.pol>          # 每字段的分布体检
  python tools/pol_fields.py uvscan <file.pol> [glob]   # 扫描所有字段对，找真 UV
"""
import os
import struct
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import r6pol  # noqa: E402

HEADER = 144


def load(path):
    b = open(path, "rb").read()
    nv = struct.unpack_from("<I", b, 124)[0]
    n = min(nv, max(0, (len(b) - HEADER) // 32))
    raw = np.frombuffer(b, dtype="<f4", count=n * 8, offset=HEADER).reshape(n, 8).astype(np.float64)
    m = r6pol.parse(path)
    tri = np.asarray(m["indices"], dtype=np.int64).reshape(-1, 3)
    tri = tri[(tri < n).all(axis=1)] if len(tri) else np.zeros((0, 3), np.int64)
    return b, raw, tri, m


def cmd_dump(path, k=12):
    b, raw, tri, m = load(path)
    print("%s  nv=%d tri=%d vert_ok=%s" % (path, m["nv"], len(tri), m.get("vtx_ok")))
    np.set_printoptions(precision=4, suppress=True, linewidth=220)
    print("\n前 %d 个顶点（列 = f0..f7）:" % k)
    print(raw[:k])
    if len(tri):
        print("\n前 5 个三角面：")
        for t in tri[:5]:
            print("  tri %s" % (list(t),))
            print(raw[t])


def cmd_stat(path):
    b, raw, tri, m = load(path)
    print("%s  nv=%d tri=%d" % (path, m["nv"], len(tri)))
    print("%-4s %11s %11s %7s %7s %7s" % ("字段", "min", "max", "为0%", "唯一值", "面内恒定%"))
    for i in range(8):
        col = raw[:, i]
        uniq = len(np.unique(np.round(col, 5)))
        # 面内恒定比例：同一三角面的 3 个顶点该字段是否相等
        const = 0.0
        if len(tri):
            sub = raw[tri, i]
            const = float(np.mean((np.abs(sub[:, 0] - sub[:, 1]) < 1e-5) &
                                  (np.abs(sub[:, 1] - sub[:, 2]) < 1e-5))) * 100.0
        print("f%-3d %11.4f %11.4f %6.1f%% %7d %8.1f%%"
              % (i, col.min(), col.max(), 100 * float((col == 0).mean()), uniq, const))
    print()
    # f0 的取值分布
    vals, cnts = np.unique(np.round(raw[:, 0], 4), return_counts=True)
    order = np.argsort(-cnts)
    print("f0 的取值分布（前 12 个）:")
    for k in order[:12]:
        print("   %10.4f  ×%d" % (vals[k], cnts[k]))


def _angles(P):
    """P[N,3] -> 每个点相对质心的极角，用于比较形状是否被同一变换保角。"""
    return P


def angle_err(pos, uv, tri):
    """对每个三角面算 3D 内角与 UV 内角的平均绝对差（度）。返回 (中位误差, 匹配率<8°)。"""
    if len(tri) == 0:
        return 999.0, 0.0
    a, b_, c = tri[:, 0], tri[:, 1], tri[:, 2]

    def angs(V):
        p0, p1, p2 = V[a], V[b_], V[c]
        out = []
        for q, r, s in ((p0, p1, p2), (p1, p2, p0), (p2, p0, p1)):
            e1, e2 = q - r, s - r
            n1 = np.linalg.norm(e1, axis=1)
            n2 = np.linalg.norm(e2, axis=1)
            cos = np.clip(np.sum(e1 * e2, 1) / np.maximum(n1 * n2, 1e-12), -1, 1)
            out.append(np.degrees(np.arccos(cos)))
        return np.stack(out, 1)

    A3 = angs(pos[:, :3])
    A2 = angs(uv)
    err = np.abs(A3 - A2).mean(axis=1)
    err = err[np.isfinite(err)]
    if not len(err):
        return 999.0, 0.0
    return float(np.median(err)), float((err < 8.0).mean() * 100.0)


def cmd_uvscan(path):
    b, raw, tri, m = load(path)
    print("%s  nv=%d tri=%d" % (path, m["nv"], len(tri)))
    pos = raw[:, 1:4]
    base = angle_err(pos, pos[:, :2], tri)[0]
    print("基准（位置自身投影，无意义）: %.1f°" % base)
    print("\n%-10s %8s %9s %9s  %s" % ("字段对", "值域ok", "中位角差", "<8°占比", "判定"))
    rows = []
    for i in range(8):
        for j in range(8):
            if i == j:
                continue
            uv = raw[:, [i, j]]
            lo, hi = uv.min(), uv.max()
            ok = bool(lo >= -0.01 and hi <= 1.01) or bool(lo >= -1 and hi <= 8.01)
            med, hit = angle_err(pos, uv, tri)
            rows.append((med, i, j, ok, hit, lo, hi))
    rows.sort()
    for med, i, j, ok, hit, lo, hi in rows[:16]:
        tag = "★ 可能是 UV" if (med < 12 and hit > 50) else ("~ 弱关联" if med < 25 else "")
        print("f%-2d,f%-2d   %6s   %7.1f°  %7.1f%%  %s  [%.3f, %.3f]"
              % (i, j, "是" if ok else "否", med, hit, tag, lo, hi))


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "dump"
    p = sys.argv[2]
    if cmd == "dump":
        cmd_dump(p, int(sys.argv[3]) if len(sys.argv) > 3 else 12)
    elif cmd == "stat":
        cmd_stat(p)
    elif cmd == "uvscan":
        cmd_uvscan(p)
    else:
        print(__doc__)
