# -*- coding: utf-8 -*-
"""
r6uv.py —— 为 R6HS(.pol) 建筑模型生成可用 UV。

背景（2026-09-26 逆向记录）
---------------------------
`.pol` 顶点记录 32 字节 = 8 个 float：

    f0  ∈ {0, ±1, ±0.65, ±0.75}   面级常量（疑似切线/标志位）
    f1  x      f2 y      f3 z     位置
    f4  f5                        数值域 0..1.2，是「某种」贴图坐标
    f6  f7  ∈ {0, ±1, ±0.66, ±0.76}  成对构成单位向量

f4/f5 确实是贴图坐标（它的取值都落在 <贴图>.tga 里图块的角点上），
但它是 3ds Max「Flatten Mapping」把 UV 岛**旋转打包**后的结果，
直接采样会得到斜向拉丝的错图。原版用的是 DirectX8 固定管线 + geom.gbf，
推测真实映射依赖已丢失的中间步骤，**无法从 .pol 复原**。

因此本模块改用「按面角色贴原版图集」的方案：
    ① 把 <贴图>.tga 分割成若干矩形图块（绿=草地/地面、橙=瓦片/屋顶、浅色=墙面…）
    ② 把网格按法线聚成平面片
    ③ 按角色（地面 / 屋顶 / 墙面）把每个面片整体映射到对应图块

这样既用了原版美术，又能得到干净的三维建筑。
"""

import numpy as np

try:
    from scipy import ndimage as ndi
    _HAS_SCIPY = True
except Exception:                                    # pragma: no cover
    _HAS_SCIPY = False


# ------------------------------------------------------------------ 图集分割

def _label(mask):
    if _HAS_SCIPY:
        lab, n = ndi.label(mask)
        return lab, n
    return None, 0


def _largest_box(mask):
    """返回 mask 中最大连通域的 bbox (x0,y0,x1,y1)，无则 None。"""
    if _HAS_SCIPY:
        lab, n = ndi.label(mask)
        if n == 0:
            return None
        sizes = ndi.sum(mask.astype(np.int32), lab, range(1, n + 1))
        k = int(np.argmax(sizes)) + 1
        sl = ndi.find_objects(lab, max_label=k)[k - 1]
        if sl is None:
            return None
        return (sl[1].start, sl[0].start, sl[1].stop, sl[0].stop)
    ys, xs = np.nonzero(mask)
    if len(xs) == 0:
        return None
    return (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1)


def _grow_rect(mask, box, min_frac=0.55, pad=2):
    """
    把 bbox 扩展成「矩形填充率高」的最大矩形（图块在贴图里是整齐矩形，
    但按颜色分割时会被图块内部的图案打洞，这里做一次矩形化）。
    """
    x0, y0, x1, y1 = box
    H, W = mask.shape
    for _ in range(24):
        grown = False
        cands = []
        if x0 - 1 >= 0:
            cands.append(("L", (x0 - 1, y0, x1, y1)))
        if x1 + 1 <= W:
            cands.append(("R", (x0, y0, x1 + 1, y1)))
        if y0 - 1 >= 0:
            cands.append(("T", (x0, y0 - 1, x1, y1)))
        if y1 + 1 <= H:
            cands.append(("B", (x0, y0, x1, y1 + 1)))
        best, bestf = None, None
        for _, (a, b, c, d) in cands:
            sub = mask[b:d, a:c]
            if sub.size == 0:
                continue
            f = float(sub.mean())
            if f >= min_frac and (bestf is None or f > bestf):
                best, bestf = (a, b, c, d), f
        if best is not None:
            x0, y0, x1, y1 = best
            grown = True
        if not grown:
            break
    return (max(0, x0 - pad), max(0, y0 - pad), min(W, x1 + pad), min(H, y1 + pad))


def _rect_grow(mask, box, thr=0.55, iters=30, max_frac=0.40):
    """把连通域 bbox 长成尽量大的矩形（图集图块内部有图案，颜色分割会打洞）。"""
    x0, y0, x1, y1 = box
    H, W = mask.shape
    cap = max_frac * W * H
    for _ in range(iters):
        best, bestv = None, thr
        cands = []
        if x0 - 1 >= 0:
            cands.append((x0 - 1, y0, x1, y1))
        if x1 + 1 <= W:
            cands.append((x0, y0, x1 + 1, y1))
        if y0 - 1 >= 0:
            cands.append((x0, y0 - 1, x1, y1))
        if y1 + 1 <= H:
            cands.append((x0, y0, x1, y1 + 1))
        for c in cands:
            a, b, cc, d = c
            if (cc - a) * (d - b) > cap:
                continue
            sub = mask[b:d, a:cc]
            if sub.size == 0:
                continue
            f = float(sub.mean())
            if f > bestv:
                best, bestv = c, f
        if best is None:
            break
        x0, y0, x1, y1 = best
    return (x0, y0, x1, y1)


def atlas_regions(img):
    """
    把建筑图集切成「角色图块」。返回 {role: (u0,v0,u1,v1)}，v=0 在图片底部。
    角色：ground(草地/地面) / roof(瓦片屋顶) / wall(墙面) / door(门)
    做法：按颜色分类 → 取最大连通域 → 向外长成矩形。
    """
    a = np.asarray(img.convert("RGB")).astype(np.int32)
    H, W = a.shape[:2]
    R, G, B = a[..., 0], a[..., 1], a[..., 2]
    mx = a.max(2)
    mn = a.min(2)
    sat = mx - mn
    lum = a.mean(2)
    bg = (lum > 244) & (sat < 10)

    masks = {
        "ground": (G > R + 18) & (G > B + 18) & (G > 70),
        "roof": (R > G + 30) & (G > B + 12) & (R > 135),
        "wall": (lum > 168) & (lum < 248) & (sat > 12) & (sat < 95) & ~bg,
        "door": (lum < 125) & (sat > 35),
    }

    regs = {}
    for name, m in masks.items():
        mm = m.copy()
        if _HAS_SCIPY:
            mm = ndi.binary_opening(mm, np.ones((3, 3)))
            mm = ndi.binary_closing(mm, np.ones((5, 5)))
        ys, xs = np.nonzero(mm)
        if len(xs) < 40:
            continue
        if _HAS_SCIPY:
            lab, n = ndi.label(mm)
            if n == 0:
                continue
            objs = ndi.find_objects(lab)
            sizes = ndi.sum(mm.astype(np.int32), lab, range(1, n + 1))
            best, bests = None, -1.0
            for k in range(n):
                sl = objs[k]
                if sl is None:
                    continue
                h = sl[0].stop - sl[0].start
                w = sl[1].stop - sl[1].start
                if w < 8 or h < 8:
                    continue
                area = float(sizes[k])
                score = area * (area / float(w * h))     # 又大又方
                if score > bests:
                    bests, best = score, (sl[1].start, sl[0].start, sl[1].stop, sl[0].stop)
            if best is None:
                continue
            box = best
        else:
            box = (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1)
        if name in ("wall", "roof", "ground"):
            box = _rect_grow(mm, box, thr=0.42 if name == "wall" else 0.5)
        x0, y0, x1, y1 = box
        if (x1 - x0) < 5 or (y1 - y0) < 5:
            continue
        regs[name] = (x0 / W, 1.0 - y1 / H, x1 / W, 1.0 - y0 / H)

    if "wall" not in regs:
        regs["wall"] = (0.0, 0.0, 1.0, 1.0)
    if "roof" not in regs:
        regs["roof"] = regs["wall"]
    if "ground" not in regs:
        regs["ground"] = regs["roof"]
    return regs




# ------------------------------------------------------------------ 网格分片

def face_groups(pos, tri, angle_cos=0.985):
    """按共享边 + 法线相近把三角形并成平面片，返回 list[list[int]]（三角形下标）。"""
    n = len(tri)
    if n == 0:
        return []
    nrm = np.cross(pos[tri[:, 1]] - pos[tri[:, 0]], pos[tri[:, 2]] - pos[tri[:, 0]])
    ln = np.linalg.norm(nrm, axis=1, keepdims=True)
    nrm = nrm / np.maximum(ln, 1e-12)

    from collections import defaultdict
    edge = defaultdict(list)
    for k, (a, b, c) in enumerate(tri):
        for e in ((a, b), (b, c), (c, a)):
            edge[(min(e), max(e))].append(k)

    parent = list(range(n))

    def find(x):
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x

    def uni(x, y):
        rx, ry = find(x), find(y)
        if rx != ry:
            parent[rx] = ry

    for _, ks in edge.items():
        for i in range(len(ks)):
            for j in range(i + 1, len(ks)):
                k1, k2 = ks[i], ks[j]
                if float(np.dot(nrm[k1], nrm[k2])) >= angle_cos:
                    uni(k1, k2)

    out = defaultdict(list)
    for k in range(n):
        out[find(k)].append(k)
    return list(out.values())


# ------------------------------------------------------------------ 自动 UV

def auto_uv(pos, tri, regs, up=np.array([0.0, 1.0, 0.0])):
    """
    返回 uv[N,2]。规则：
        · 法线朝上且靠下  → ground（地面/草坪）
        · 法线朝上        → roof（屋顶）
        · 法线朝下        → ground
        · 其余            → wall（墙面）
        每个面片整体映射到对应图块的一次重复（不拼接，避免露缝）。
    """
    uv = np.zeros((len(pos), 2), dtype=np.float64)
    have = set()
    ymin, ymax = float(pos[:, 1].min()), float(pos[:, 1].max())
    hgt = max(ymax - ymin, 1e-6)
    miss = set()

    default = regs.get("wall") or (0.0, 0.0, 1.0, 1.0)

    for ks in face_groups(pos, tri):
        vids = sorted({int(i) for k in ks for i in tri[k]})
        if len(vids) < 3:
            continue
        P = pos[vids]
        e1 = P[1] - P[0]
        e2 = P[2] - P[0]
        n = np.cross(e1, e2)
        ln = np.linalg.norm(n)
        if ln < 1e-9:
            continue
        n = n / ln
        cy = float(P[:, 1].mean())
        d = float(np.dot(n, up))
        if d > 0.86 and cy < ymin + 0.18 * hgt:
            role = "ground"
        elif d > 0.35:
            role = "roof"
        elif d < -0.5:
            role = "ground"
        else:
            role = "wall"
        reg = regs.get(role)
        if reg is None:
            miss.add(role)
            reg = regs.get("roof") or default

        # 面片局部 2D 基（面内两个正交方向）
        t1 = e1 / max(np.linalg.norm(e1), 1e-9)
        t2 = np.cross(n, t1)
        S = P - P.mean(axis=0)
        s = S @ t1
        t = S @ t2
        sr = max(s.max() - s.min(), 1e-6)
        tr = max(t.max() - t.min(), 1e-6)
        u0, v0, u1, v1 = reg
        us = (s - s.min()) / sr * (u1 - u0) + u0
        vs = (t - t.min()) / tr * (v1 - v0) + v0
        for i, vi in enumerate(vids):
            uv[vi] = (us[i], vs[i])
            have.add(vi)

    # 没有归属的顶点（孤立点）给个安全值
    for i in range(len(pos)):
        if i not in have:
            uv[i] = ((default[0] + default[2]) * 0.5, (default[1] + default[3]) * 0.5)
    return uv, miss


def auto_uv_for(pol_path, atlas_path, r6pol_mod, pos_offset=1):
    """便捷封装：读 .pol + 图集，返回 (pos, tri, uv, regs)。"""
    import struct
    from PIL import Image
    b = open(pol_path, "rb").read()
    m = r6pol_mod.parse(pol_path)
    nv = m["nv"]
    raw = np.frombuffer(b, dtype="<f4", count=nv * 8, offset=144).reshape(nv, 8)
    pos = np.stack([raw[:, 1], raw[:, 2], raw[:, 3]], axis=1).astype(np.float64)
    tri = np.asarray(m["indices"], dtype=np.int64).reshape(-1, 3)
    tri = tri[(tri < len(pos)).all(axis=1)]
    regs = atlas_regions(Image.open(atlas_path))
    uv, miss = auto_uv(pos, tri, regs)
    return pos, tri, uv, regs, miss
