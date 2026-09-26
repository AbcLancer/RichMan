# -*- coding: utf-8 -*-
"""
r6pol.py —— 《大富翁6》R6HS (.pol) 网格解析器

格式（逆向，2026-09-25 初版 / 2026-09-26 修正索引定位）：

    offset  type        说明
    ------  ----------  ----------------------------------------------------
    0       char[4]     "R6HS"
    4       u32         版本：100 (单体模型) / 200 (地形 Plane01)
    8       char[32]    对象名（NUL 结尾，后用 0xCD 或 0x00 补齐）
    40      f32[16]     4x4 变换矩阵（多为单位阵）
    104     u32         标志
    108     f32[3]      包围盒中心 (cx, cy, cz)
    120     f32         包围半径 r
    124     u32         顶点数 nv
    144     record[nv]  顶点记录，**步长 32 字节**：
                           +0  f32    未定（多数为 0）
                           +4  f32[3] 位置 (x, y, z)
                           +16 f32[3] 法线 (nx, ny, nz)
                           +28 f32    未定（0 或 ±1）
    144+32n ???         材质块：起始固定 12 字节
                           (D3DCOLOR 0xff0b0b0b, D3DCOLOR 0xff000000, f32 32.0)
                           之后是**变长**的字符串 / 参数表（贴图名、refractionMap 等），
                           长度不固定 ⇒ 索引块位置不能写死。
     ?      u32         三角形数 tc
     ?+4    u16[3*tc]   索引（三角形列表）

索引块定位：材质块变长，所以**扫描**「u32 tc + 3*tc 个 u16 且全部 < nv」这一模式，
取 tc 最大的候选。112 个 v100 文件全部命中（2026-09-26 实测）。

用法：
    python tools/r6pol.py info  <file.pol>
    python tools/r6pol.py obj   <file.pol> <out.obj>
    python tools/r6pol.py shot  <file.pol> <out.png> [w] [h]
    python tools/r6pol.py batch <dir> <outdir> [w] [h]      # 批量渲染目录下所有 pol
"""

import math
import os
import struct
import sys

HEADER = 144
STRIDE = 32
POS_OFF = 4
NRM_OFF = 16


def f32(b, o):
    return struct.unpack_from("<f", b, o)[0]


def u16(b, o):
    return struct.unpack_from("<H", b, o)[0]


def u32(b, o):
    return struct.unpack_from("<I", b, o)[0]


def find_index_block(b, nv):
    """扫描 u32 tc + 3*tc 个 u16（全部 < nv）的模式，返回 (offset, tc) 或 None。"""
    if nv <= 0:
        return None
    best = None
    start = max(0, HEADER + STRIDE * nv - 8)
    for p in range(start, len(b) - 4, 2):
        c = u32(b, p)
        if c < 1 or c > 100000:
            continue
        end = p + 4 + 3 * c * 2
        if end > len(b):
            continue
        ok = True
        for i in range(3 * c):
            if u16(b, p + 4 + 2 * i) >= nv:
                ok = False
                break
        if ok and (best is None or c > best[1]):
            best = (p, c)
    return best


def parse(path):
    b = open(path, "rb").read()
    if b[:4] != b"R6HS":
        raise ValueError("%s: 不是 R6HS 文件" % path)
    m = {
        "path": path,
        "version": u32(b, 4),
        "name": b[8:40].split(b"\0")[0].decode("latin1", "replace"),
        "matrix": [f32(b, 40 + 4 * i) for i in range(16)],
        "flag": u32(b, 104),
        "center": (f32(b, 108), f32(b, 112), f32(b, 116)),
        "radius": f32(b, 120),
        "nv": u32(b, 124),
        "size": len(b),
    }

    nv = m["nv"]
    verts, norms = [], []
    for k in range(nv):
        o = HEADER + STRIDE * k
        if o + STRIDE > len(b):
            break
        verts.append((f32(b, o + POS_OFF), f32(b, o + POS_OFF + 4), f32(b, o + POS_OFF + 8)))
        norms.append((f32(b, o + NRM_OFF), f32(b, o + NRM_OFF + 4), f32(b, o + NRM_OFF + 8)))
    m["verts"] = verts
    m["norms"] = norms
    m["vtx_ok"] = len(verts) == nv

    blk = find_index_block(b, nv)
    if blk is None:
        m["idx_off"] = None
        m["indices"] = []
    else:
        off, tc = blk
        m["idx_off"] = off
        m["indices"] = [u16(b, off + 4 + 2 * i) for i in range(3 * tc)]
    m["tri_count"] = len(m["indices"]) // 3
    return m


def info(path):
    m = parse(path)
    cx, cy, cz = m["center"]
    print("%s" % path.replace("\\", "/"))
    print("  version   : %d" % m["version"])
    print("  name      : %s" % m["name"])
    print("  file size : %d" % m["size"])
    print("  center    : (%.3f, %.3f, %.3f)   r=%.3f" % (cx, cy, cz, m["radius"]))
    print("  verts     : %d  (parsed %d, ok=%s)" % (m["nv"], len(m["verts"]), m["vtx_ok"]))
    print("  triangles : %d   [idx@%s]" % (m["tri_count"], m["idx_off"]))
    if m["verts"]:
        xs = [v[0] for v in m["verts"]]
        ys = [v[1] for v in m["verts"]]
        zs = [v[2] for v in m["verts"]]
        print("  bbox      : x[%.2f,%.2f] y[%.2f,%.2f] z[%.2f,%.2f]"
              % (min(xs), max(xs), min(ys), max(ys), min(zs), max(zs)))
    return m


def write_obj(path, out):
    m = parse(path)
    with open(out, "w", encoding="utf-8") as f:
        f.write("# %s  (%s)  v=%d tri=%d\n" % (os.path.basename(path), m["name"],
                                               len(m["verts"]), m["tri_count"]))
        for p in m["verts"]:
            f.write("v %.6f %.6f %.6f\n" % p)
        for p in m["norms"]:
            f.write("vn %.6f %.6f %.6f\n" % p)
        for i in range(m["tri_count"]):
            a, bb, c = m["indices"][i * 3], m["indices"][i * 3 + 1], m["indices"][i * 3 + 2]
            f.write("f %d//%d %d//%d %d//%d\n" % (a + 1, a + 1, bb + 1, bb + 1, c + 1, c + 1))
    print("-> %s" % out)


def render(m, out, w=520, h=420, ry=35.0, rx=22.0):
    """极简软件渲染（正交 + 画家算法），肉眼验证网格。返回是否成功。"""
    from PIL import Image, ImageDraw

    v = m["verts"]
    if not v or m["tri_count"] == 0:
        return False
    a, b2 = math.radians(ry), math.radians(rx)

    def rot(p):
        x, y, z = p
        x, z = x * math.cos(a) - z * math.sin(a), x * math.sin(a) + z * math.cos(a)
        y, z = y * math.cos(b2) - z * math.sin(b2), y * math.sin(b2) + z * math.cos(b2)
        return (x, -z, y)

    rv = [rot(p) for p in v]
    xs = [p[0] for p in rv]
    ys = [p[1] for p in rv]
    span = max(max(xs) - min(xs), max(ys) - min(ys), 1e-6)
    s = (min(w, h) * 0.84) / span
    ox = (w - (max(xs) + min(xs)) * s) / 2.0
    oy = (h + (max(ys) + min(ys)) * s) / 2.0

    img = Image.new("RGB", (w, h), (26, 28, 34))
    d = ImageDraw.Draw(img)
    tris = []
    for i in range(m["tri_count"]):
        ia, ib, ic = m["indices"][i * 3], m["indices"][i * 3 + 1], m["indices"][i * 3 + 2]
        if max(ia, ib, ic) >= len(rv):
            continue
        p0, p1, p2 = rv[ia], rv[ib], rv[ic]
        tris.append(((p0[2] + p1[2] + p2[2]) / 3.0, p0, p1, p2))
    if not tris:
        return False
    tris.sort()
    for _, p0, p1, p2 in tris:
        pts = [(p0[0] * s + ox, p0[1] * s + oy),
               (p1[0] * s + ox, p1[1] * s + oy),
               (p2[0] * s + ox, p2[1] * s + oy)]
        ux, uy = p1[0] - p0[0], p1[1] - p0[1]
        vx, vy = p2[0] - p0[0], p2[1] - p0[1]
        nz = abs(ux * vy - uy * vx)
        lit = 0.30 + 0.70 * min(1.0, nz / (span * span * 0.015 + 1e-9))
        d.polygon(pts, fill=(int(90 + 140 * lit), int(90 + 130 * lit), int(105 + 130 * lit)),
                  outline=(18, 18, 24))
    img.save(out)
    return True


def shot(path, out, w=520, h=420):
    m = parse(path)
    if render(m, out, w, h):
        print("-> %s  (v=%d tri=%d)" % (out, len(m["verts"]), m["tri_count"]))
    else:
        print("!! %s 渲染失败 (v=%d tri=%d)" % (path, len(m["verts"]), m["tri_count"]))


def batch(src, outdir, w=340, h=280):
    from PIL import Image, ImageDraw
    os.makedirs(outdir, exist_ok=True)
    files = []
    for dp, _, fn in os.walk(src):
        for f in fn:
            if f.lower().endswith(".pol"):
                files.append(os.path.join(dp, f))
    files.sort()
    tiles = []
    ok = fail = 0
    for i, f in enumerate(files):
        try:
            m = parse(f)
            tmp = os.path.join(outdir, "_t.png")
            if render(m, tmp, w, h):
                tiles.append((os.path.relpath(f, src).replace("\\", "/"),
                              Image.open(tmp).copy()))
                ok += 1
            else:
                fail += 1
        except Exception as e:
            print("  !! %s : %s" % (f, e))
            fail += 1
    if tiles:
        cols = min(6, max(1, int(math.ceil(math.sqrt(len(tiles))))))
        rows = (len(tiles) + cols - 1) // cols
        sheet = Image.new("RGB", (cols * w, rows * (h + 16)), (16, 16, 20))
        dd = ImageDraw.Draw(sheet)
        for i, (name, im) in enumerate(tiles):
            r, c = divmod(i, cols)
            sheet.paste(im, (c * w, r * (h + 16) + 16))
            dd.text((c * w + 4, r * (h + 16) + 3), name[:44], fill=(200, 200, 210))
        sheet.save(os.path.join(outdir, "_sheet.png"))
        print("-> %s/_sheet.png  (%d tiles, ok=%d fail=%d)" % (outdir, len(tiles), ok, fail))
    else:
        print("没有可渲染的文件 (fail=%d)" % fail)


if __name__ == "__main__":
    from PIL import ImageDraw  # noqa
    cmd = sys.argv[1] if len(sys.argv) > 1 else "info"
    if cmd == "info":
        info(sys.argv[2])
    elif cmd == "obj":
        write_obj(sys.argv[2], sys.argv[3])
    elif cmd == "shot":
        shot(sys.argv[2], sys.argv[3],
             int(sys.argv[4]) if len(sys.argv) > 4 else 520,
             int(sys.argv[5]) if len(sys.argv) > 5 else 420)
    elif cmd == "batch":
        batch(sys.argv[2], sys.argv[3],
              int(sys.argv[4]) if len(sys.argv) > 4 else 340,
              int(sys.argv[5]) if len(sys.argv) > 5 else 280)
    else:
        print(__doc__)
