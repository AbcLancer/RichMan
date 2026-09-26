# -*- coding: utf-8 -*-
"""
pol2obj.py —— 把《大富翁6》的 R6HS(.pol) 建筑网格转成通用格式，并做贴图验证。

顶点块从文件偏移 128 开始，步长 32 字节：
    f0,f1 UV；f2,f3,f4 法线；f5,f6,f7 位置。
旧版偏移 144 虽然能读出位置，却把 UV 读到了下一个顶点。

贴图名从「顶点块之后、索引块之前的材质块」里提取（形如 a1.tga / b0201.tga）。

用法：
    python tools/pol2obj.py export <src_building_dir> <out_dir>
    python tools/pol2obj.py check  <src.pol> <out.png> [tex.tga]
    python tools/pol2obj.py sheet  <src_building_dir> <out.png>
"""

import math
import os
import re
import struct
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import r6pol  # noqa: E402

F0, F1 = 0, 32          # 顶点记录偏移与步长
O_POS = 20
O_UV = 0
O_NRM = 8


def read_verts(b, nv):
    # R6HS v100: vertices begin at 128, UV2 + normal3 + position3.
    # The previous 144 offset accidentally read the NEXT vertex's UV.
    raw = np.frombuffer(b, dtype="<f4", count=nv * 8, offset=128).reshape(nv, 8)
    return raw[:, 5:8].astype(np.float64), raw[:, :2].astype(np.float64)


TGA_RE = re.compile(rb"([^\x00-\x20\x7f-\xff]{1,40}\.tga)", re.I)


def read_texture_name(b, nv):
    """材质块里第一个 *.tga。"""
    start = 144 + 32 * nv
    blk = b[start:]
    m = TGA_RE.search(blk)
    if not m:
        return None
    try:
        return m.group(1).decode("gbk")
    except UnicodeDecodeError:
        return m.group(1).decode("latin1")


def load_pol(path):
    b = open(path, "rb").read()
    m = r6pol.parse(path)
    nv = m["nv"]
    pos, uv = read_verts(b, nv)
    tri = np.asarray(m["indices"], dtype=np.int64).reshape(-1, 3)
    tri = tri[(tri < len(pos)).all(axis=1)]
    return {
        "path": path,
        "name": m["name"],
        "pos": pos,
        "uv": uv,
        "tri": tri,
        "tex": read_texture_name(b, nv),
        "center": m["center"],
    }


# ------------------------------------------------------------------ 导出

def face_normal(pos, tri):
    a, b, c = pos[tri[:, 0]], pos[tri[:, 1]], pos[tri[:, 2]]
    n = np.cross(b - a, c - a)
    ln = np.linalg.norm(n, axis=1, keepdims=True)
    return n / np.maximum(ln, 1e-12)


def export_dir(src, outdir, scale=1.0):
    """
    把 <src>/*/model.pol 全部导出为 outdir/<id>.obj + .mtl，
    并把贴图复制成 outdir/tex/<name>.png（Godot 直接可用）。
    返回导出清单 list[dict]。
    """
    from PIL import Image

    os.makedirs(outdir, exist_ok=True)
    texdir = os.path.join(outdir, "tex")
    os.makedirs(texdir, exist_ok=True)

    manifest = []
    ids = sorted(d for d in os.listdir(src) if os.path.isdir(os.path.join(src, d)))
    for bid in ids:
        pol = os.path.join(src, bid, "model.pol")
        if not os.path.exists(pol):
            continue
        g = load_pol(pol)
        if len(g["tri"]) == 0 or len(g["pos"]) == 0:
            print("  !! %s 无三角面" % bid)
            continue

        pos = g["pos"] * scale
        # 统一：把模型放到脚底 y=0、水平中心对齐原点
        mn = pos.min(axis=0)
        mx = pos.max(axis=0)
        cx = (mn[0] + mx[0]) / 2.0
        cz = (mn[2] + mx[2]) / 2.0
        pos[:, 0] -= cx
        pos[:, 2] -= cz
        pos[:, 1] -= mn[1]
        size = (mx[0] - mn[0], mx[1] - mn[1], mx[2] - mn[2])

        # 贴图
        tex_png = None
        cand = []
        if g["tex"]:
            cand.append(os.path.join(src, bid, g["tex"]))
        for f in sorted(os.listdir(os.path.join(src, bid))):
            if f.lower().endswith(".tga") and os.path.join(src, bid, f) not in cand:
                cand.append(os.path.join(src, bid, f))
        src_tex = next((c for c in cand if os.path.exists(c)), None)
        if src_tex:
            try:
                im = Image.open(src_tex)
                if im.mode != "RGB":
                    im = im.convert("RGB")
                tex_png = ("tex/" + os.path.splitext(os.path.basename(src_tex))[0] + ".png")
                im.save(os.path.join(outdir, tex_png.replace("/", os.sep)))
            except Exception as e:
                print("  !! %s 贴图失败 %s: %s" % (bid, src_tex, e))
                tex_png = None

        # 材质
        mtl = bid + ".mtl"
        with open(os.path.join(outdir, mtl), "w", encoding="utf-8") as f:
            f.write("# %s\n" % bid)
            f.write("newmtl %s\n" % bid)
            f.write("Kd 1.000 1.000 1.000\n")
            f.write("Ka 0.300 0.300 0.300\n")
            f.write("d 1.0\n")
            if tex_png:
                f.write("map_Kd %s\n" % tex_png)
            f.write("illum 1\n")

        # OBJ（vt 逐顶点，与 v 同索引）
        obj = bid + ".obj"
        with open(os.path.join(outdir, obj), "w", encoding="utf-8") as f:
            f.write("# %s  name=%s  v=%d tri=%d  tex=%s\n"
                    % (bid, g["name"], len(pos), len(g["tri"]), tex_png))
            f.write("mtllib %s\n" % mtl)
            f.write("o %s\n" % bid)
            for p in pos:
                f.write("v %.4f %.4f %.4f\n" % (p[0], p[1], p[2]))
            for t in g["uv"]:
                f.write("vt %.5f %.5f\n" % (t[0], t[1]))
            nrm = face_normal(pos, g["tri"])
            for n in nrm:
                f.write("vn %.4f %.4f %.4f\n" % (n[0], n[1], n[2]))
            f.write("usemtl %s\n" % bid)
            f.write("s off\n")
            for i, (a, b_, c) in enumerate(g["tri"]):
                f.write("f %d/%d/%d %d/%d/%d %d/%d/%d\n"
                        % (a + 1, a + 1, i + 1,
                           b_ + 1, b_ + 1, i + 1,
                           c + 1, c + 1, i + 1))

        uv = g["uv"]
        manifest.append({
            "id": bid,
            "obj": obj,
            "tex": tex_png,
            "verts": int(len(pos)),
            "tris": int(len(g["tri"])),
            "size": [round(float(v), 3) for v in size],
            "uv_min": [round(float(uv[:, 0].min()), 3), round(float(uv[:, 1].min()), 3)],
            "uv_max": [round(float(uv[:, 0].max()), 3), round(float(uv[:, 1].max()), 3)],
        })
        print("  %-8s v=%-5d tri=%-5d size=(%.1f, %.1f, %.1f) tex=%s"
              % (bid, len(pos), len(g["tri"]), size[0], size[1], size[2], tex_png))
    return manifest


# ------------------------------------------------------------------ 验证渲染

def render_textured(g, tex_path, out, w=520, h=460, ry=35.0, rx=22.0):
    """正交投影 + z-buffer + 双线性采样，肉眼验证 UV 对不对。"""
    from PIL import Image

    pos = g["pos"]
    if len(pos) == 0 or len(g["tri"]) == 0:
        return False
    P = pos - np.array([(pos[:, 0].min() + pos[:, 0].max()) / 2, pos[:, 1].min(),
                        (pos[:, 2].min() + pos[:, 2].max()) / 2])

    ca, sa = math.cos(math.radians(ry)), math.sin(math.radians(ry))
    cb, sb = math.cos(math.radians(rx)), math.sin(math.radians(rx))
    X = P[:, 0] * ca - P[:, 2] * sa
    Z = P[:, 0] * sa + P[:, 2] * ca
    Y = P[:, 1] * cb - Z * sb
    Zc = P[:, 1] * sb + Z * cb
    S = np.stack([X, -Zc], axis=1)

    span = max(float(np.ptp(S[:, 0])), float(np.ptp(S[:, 1])), 1e-6)
    s = min(w, h) * 0.86 / span
    scr = np.stack([S[:, 0] * s + (w - (S[:, 0].max() + S[:, 0].min()) * s) / 2.0,
                    S[:, 1] * s + (h - (S[:, 1].max() + S[:, 1].min()) * s) / 2.0], axis=1)

    if tex_path and os.path.exists(tex_path):
        T = np.asarray(Image.open(tex_path).convert("RGB")).astype(np.float64)
    else:
        T = np.full((8, 8, 3), 200.0)

    img = np.zeros((h, w, 3), dtype=np.float64)
    img[:] = 24
    zbuf = np.full((h, w), 1e18)

    uv = g["uv"]
    tri = g["tri"]
    for k in range(len(tri)):
        i0, i1, i2 = tri[k]
        p0, p1, p2 = scr[i0], scr[i1], scr[i2]
        z0, z1, z2 = Zc[i0], Zc[i1], Zc[i2]
        minx = max(int(math.floor(min(p0[0], p1[0], p2[0]))), 0)
        maxx = min(int(math.ceil(max(p0[0], p1[0], p2[0]))), w - 1)
        miny = max(int(math.floor(min(p0[1], p1[1], p2[1]))), 0)
        maxy = min(int(math.ceil(max(p0[1], p1[1], p2[1]))), h - 1)
        if minx > maxx or miny > maxy:
            continue
        xs, ys = np.meshgrid(np.arange(minx, maxx + 1), np.arange(miny, maxy + 1))
        d = ((p1[1] - p2[1]) * (p0[0] - p2[0]) + (p2[0] - p1[0]) * (p0[1] - p2[1]))
        if abs(d) < 1e-9:
            continue
        l0 = ((p1[1] - p2[1]) * (xs - p2[0]) + (p2[0] - p1[0]) * (ys - p2[1])) / d
        l1 = ((p2[1] - p0[1]) * (xs - p2[0]) + (p0[0] - p2[0]) * (ys - p2[1])) / d
        l2 = 1.0 - l0 - l1
        inside = (l0 >= -1e-6) & (l1 >= -1e-6) & (l2 >= -1e-6)
        if not inside.any():
            continue
        z = l0 * z0 + l1 * z1 + l2 * z2
        sub = zbuf[miny:maxy + 1, minx:maxx + 1]
        upd = inside & (z < sub)
        if not upd.any():
            continue
        sub[upd] = z[upd]
        u = l0 * uv[i0, 0] + l1 * uv[i1, 0] + l2 * uv[i2, 0]
        v = l0 * uv[i0, 1] + l1 * uv[i1, 1] + l2 * uv[i2, 1]
        th, tw = T.shape[:2]
        tx = np.mod((u * tw).astype(np.int64), tw)
        ty = np.mod(((1.0 - v) * th).astype(np.int64), th)   # GL 约定：v=0 在图像底部
        col = T[ty, tx]
        # 简单朗伯光照
        e1 = P[i1] - P[i0]
        e2 = P[i2] - P[i0]
        n = np.cross(e1, e2)
        nl = np.linalg.norm(n)
        shade = 0.55 + 0.45 * abs(n[1] / nl) if nl > 1e-9 else 0.8
        block = img[miny:maxy + 1, minx:maxx + 1]
        m = upd[..., None]
        block[:] = np.where(m, np.clip(col * shade, 0, 255), block)
    Image.fromarray(img.astype(np.uint8)).resize((w, h)).save(out)
    return True


def find_tex(src_dir, bid, name):
    if name:
        p = os.path.join(src_dir, bid, name)
        if os.path.exists(p):
            return p
    d = os.path.join(src_dir, bid)
    if os.path.isdir(d):
        for f in sorted(os.listdir(d)):
            if f.lower().endswith(".tga"):
                return os.path.join(d, f)
    return None


def bleed_atlas(im, iters=10):
    """
    图集四周与图块之间是纯白/透明底。模型里有少量面的 UV 会落到这些空白上，
    直接采样会得到刺眼的白色。这里做一次【边缘外扩】(texture bleed)：
    反复用非空白邻居的颜色填充空白像素，让任何 UV 都能采到合理的颜色。
    """
    from PIL import Image
    a = np.asarray(im.convert("RGB")).astype(np.float32)
    H, W = a.shape[:2]
    lum = a.mean(2)
    sat = a.max(2) - a.min(2)
    hole = (lum > 243) & (sat < 12)
    if hole.all():
        return im
    for _ in range(iters):
        if not hole.any():
            break
        nb = np.zeros((H, W, 3), dtype=np.float32)
        cnt = np.zeros((H, W), dtype=np.float32)
        for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1), (-1, -1), (-1, 1), (1, -1), (1, 1)):
            src = np.roll(np.roll(a, dy, 0), dx, 1)
            ok = np.roll(np.roll(~hole, dy, 0), dx, 1)
            nb += src * ok[..., None]
            cnt += ok.astype(np.float32)
        fill = (cnt > 0) & hole
        if not fill.any():
            break
        a[fill] = nb[fill] / cnt[fill][..., None]
        hole = hole & ~fill
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))


def snap_uv_to_content(uv, im, bg_lum=243, bg_sat=12):
    """
    模型里有约 27% 的顶点 UV 落在图集的空白底上（原版 UV 被 Max 旋转打包过，
    我们只能取回其中一部分）。这里把这些顶点的 UV 吸附到**最近的有效图块像素**，
    让每个面至少都落在真实美术上，消除刺眼的白色/杂色。
    """
    try:
        from scipy import ndimage as ndi
    except Exception:
        return uv, 0
    a = np.asarray(im.convert("RGB")).astype(np.int32)
    H, W = a.shape[:2]
    bg = (a.mean(2) > bg_lum) & ((a.max(2) - a.min(2)) < bg_sat)
    if not bg.any() or bg.all():
        return uv, 0
    _, inds = ndi.distance_transform_edt(bg, return_indices=True)
    uv = np.array(uv, dtype=np.float64)
    x = np.clip((uv[:, 0] * W).astype(np.int64), 0, W - 1)
    y = np.clip(((1.0 - uv[:, 1]) * H).astype(np.int64), 0, H - 1)
    hit = bg[y, x]
    n = int(hit.sum())
    if n:
        ny = inds[0][y[hit], x[hit]]
        nx = inds[1][y[hit], x[hit]]
        uv[hit, 0] = (nx + 0.5) / W
        uv[hit, 1] = 1.0 - (ny + 0.5) / H
    return uv, n


def parse_id(bid):
    """把目录名拆成 (风格组, 类型, 等级)。如 a0101 → ('a', 1, 1)；d101 → ('d', 1, 1)；e1 → ('e', 1, 1)。"""
    import re
    m = re.fullmatch(r"([a-e])(\d)(\d{2})", bid)
    if m:
        return m.group(1), int(m.group(2)), int(m.group(3))
    m = re.fullmatch(r"([a-e])(\d)", bid)
    if m:
        return m.group(1), int(m.group(2)), 1
    m = re.fullmatch(r"([a-e])(\d)(\d)", bid)
    if m:
        return m.group(1), int(m.group(2)), int(m.group(3))
    return bid[:1], 0, 1


def pack_meshes(src, outdir):
    """
    把 <src>/<id>/model.pol 打包成引擎自带的极简二进制 <id>.r6m：
        char[4] "R6BM" | u32 ver | u32 n_vert | u32 n_tri
        f32[3] 归一化包围盒尺寸（max(x,z) == 1.0）
        f32[3] 归一化时减掉的偏移（原始单位）
        f32[3*n_vert] 位置（Y 朝上，底面 y=0，水平居中）
        f32[2*n_vert] UV（已转成 Godot 约定：v=0 在贴图顶部）
        u32[3*n_tri]  索引
    同时把贴图转成 PNG 放到 <outdir>/tex/，并写 index.json。
    """
    from PIL import Image
    import json
    import struct as _s

    os.makedirs(outdir, exist_ok=True)
    texdir = os.path.join(outdir, "tex")
    os.makedirs(texdir, exist_ok=True)

    manifest = []
    bleeded = 0
    snap_total = 0
    for bid in sorted(os.listdir(src)):
        d = os.path.join(src, bid)
        pol = os.path.join(d, "model.pol")
        if not os.path.isdir(d) or not os.path.exists(pol):
            continue
        g = load_pol(pol)
        if len(g["tri"]) == 0 or len(g["pos"]) == 0:
            print("  !! %s 空网格" % bid)
            continue
        pos = np.array(g["pos"], dtype=np.float64)
        uv = np.array(g["uv"], dtype=np.float64)
        tri = np.array(g["tri"], dtype=np.uint32)

        mn, mx = pos.min(0), pos.max(0)
        off = np.array([(mn[0] + mx[0]) / 2.0, mn[1], (mn[2] + mx[2]) / 2.0])
        pos = pos - off
        foot = max(mx[0] - mn[0], mx[2] - mn[2], 1e-6)
        k = 1.0 / foot
        pos = pos * k
        size = (pos[:, 0].max() - pos[:, 0].min(),
                pos[:, 1].max() - pos[:, 1].min(),
                pos[:, 2].max() - pos[:, 2].min())

        # 贴图
        tex_png = None
        cands = []
        if g["tex"]:
            cands.append(os.path.join(d, g["tex"]))
        for f in sorted(os.listdir(d)):
            if f.lower().endswith(".tga") and os.path.join(d, f) not in cands:
                cands.append(os.path.join(d, f))
        src_tex = next((c for c in cands if os.path.exists(c)), None)
        if src_tex:
            im = Image.open(src_tex)
            if im.mode != "RGB":
                im = im.convert("RGB")
            # Preserve original UV and texture pixels; atlas snapping hid parser errors.
            tex_png = "tex/%s__%s.png" % (bid, os.path.splitext(os.path.basename(src_tex))[0])
            im.save(os.path.join(outdir, tex_png.replace("/", os.sep)))
            bleeded += 1

        uv_godot = np.stack([uv[:, 0], 1.0 - uv[:, 1]], axis=1)   # Godot: v=0 在顶部

        outp = os.path.join(outdir, bid + ".r6m")
        with open(outp, "wb") as f:
            f.write(b"R6BM")
            f.write(_s.pack("<III", 1, len(pos), len(tri)))
            f.write(_s.pack("<3f", float(size[0]), float(size[1]), float(size[2])))
            f.write(_s.pack("<3f", float(off[0]), float(off[1]), float(off[2])))
            f.write(pos.astype("<f4").tobytes())
            f.write(uv_godot.astype("<f4").tobytes())
            f.write(tri.astype("<u4").tobytes())

        style, btype, lvl = parse_id(bid)
        manifest.append({
            "id": bid, "style": style, "type": btype, "level": lvl,
            "mesh": bid + ".r6m", "tex": tex_png,
            "size": [round(float(v), 4) for v in size],
            "verts": int(len(pos)), "tris": int(len(tri)),
            "src_pol": "samples/building/%s/model.pol" % bid,
            "src_tex": os.path.basename(src_tex) if src_tex else None,
        })
        print("  %-8s v=%-5d tri=%-5d size=(%.3f, %.3f, %.3f) tex=%s"
              % (bid, len(pos), len(tri), size[0], size[1], size[2], tex_png))

    with open(os.path.join(outdir, "index.json"), "w", encoding="utf-8") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=1)
    print("打包 %d 个模型（%d 张图集已外扩，%d 个顶点 UV 已吸附到有效图块）-> %s" % (len(manifest), bleeded, snap_total, outdir))
    return manifest


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd == "pack":
        pack_meshes(sys.argv[2], sys.argv[3])
    elif cmd == "export":
        src, out = sys.argv[2], sys.argv[3]
        man = export_dir(src, out)
        import json
        with open(os.path.join(out, "index.json"), "w", encoding="utf-8") as f:
            json.dump(man, f, ensure_ascii=False, indent=1)
        print("导出 %d 个模型 -> %s" % (len(man), out))
    elif cmd == "check":
        g = load_pol(sys.argv[2])
        tex = sys.argv[4] if len(sys.argv) > 4 else find_tex(os.path.dirname(os.path.dirname(
            sys.argv[2])), os.path.basename(os.path.dirname(sys.argv[2])), g["tex"])
        ok = render_textured(g, tex, sys.argv[3])
        print("%s  v=%d tri=%d tex=%s -> %s"
              % (sys.argv[2], len(g["pos"]), len(g["tri"]), tex, sys.argv[3]) if ok else "fail")
    elif cmd == "sheet":
        from PIL import Image, ImageDraw
        src, out = sys.argv[2], sys.argv[3]
        ids = sorted(d for d in os.listdir(src)
                     if os.path.isdir(os.path.join(src, d))
                     and os.path.exists(os.path.join(src, d, "model.pol")))
        w, h = 300, 260
        cols = 6
        rows = (len(ids) + cols - 1) // cols
        sheet = Image.new("RGB", (cols * w, rows * (h + 16)), (14, 14, 18))
        dr = ImageDraw.Draw(sheet)
        tmp = os.path.join(os.path.dirname(out), "_tmp_chk.png")
        for i, bid in enumerate(ids):
            g = load_pol(os.path.join(src, bid, "model.pol"))
            tex = find_tex(src, bid, g["tex"])
            render_textured(g, tex, tmp, w, h)
            r, c = divmod(i, cols)
            sheet.paste(Image.open(tmp), (c * w, r * (h + 16) + 16))
            t = os.path.basename(tex) if tex else "-"
            dr.text((c * w + 4, r * (h + 16) + 3), "%s  %s" % (bid, t), fill=(210, 210, 225))
        sheet.save(out)
        print("-> %s (%d 个)" % (out, len(ids)))
    else:
        print(__doc__)


if __name__ == "__main__":
    main()
