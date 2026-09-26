# -*- coding: utf-8 -*-
"""check_minimap_uv.py —— 判定小地图 (m_<map>.png) 的 UV 方向。

背景
----
`board_view.gd` 画地面贴图时曾把 `v` 写成 `0.5 - z/S`（沿 Z 镜像），
2026-09-25 修正为 `v = z/S + 0.5`。`minimap.gd` 的 `_uv()` 里有**同一个**写法，
需要**独立**判定它到底该用哪个方向。

⚠️ 旧的「点位落在小地图深色路径上」验证是**循环论证**：
   旧的 111 格 tilepos 本身就是从 `m_aiji` 拟合出来的，拿它去验 `m_aiji` 必然对。
   现在的 94 格 tilepos 来自 `ditu.tga` 的步道中心线，与 `m_aiji` **独立** → 可反推方向。

三个判据（**C、E 无自由参数、翻不了盘**；A/D 只作旁证）
-------------------------------------------------------
C. **左右环高度序**：`ditu.tga` 步道的左环质心 y=478、右环 y=615
   → **左环比右环高**。量小地图左右两半路线的平均行：左半 46.4 < 右半 59.2
   → 小地图也是左高右低。只有 `v = z/S + 0.5` 能复现这个先后关系。
E. **IoU**（固定内容矩形 rows 4..96 / cols 4..251，无自由参数，不会被「塌缩」作弊）：
   `v = z/S + 0.5` IoU 0.129 / 覆盖 0.629；`v = 0.5 - z/S` IoU 0.121 / 覆盖 0.592。
A. 点→线距离：❌ 不具判别力（两方向都 ≈7 px），只作参考。
D. 4 方向自由仿射拟合（只吸收「内容矩形未知」，不吸收翻转）：
   `u=x/S+.5 v=z/S+.5` mean 1.13 px ← 最优；其余 1.35 / 1.36 / 1.38。
   ⚠️ 若拿**整块步道形状**（2504 点）去拟，会因「细线 vs 宽带」退化成
   `sy` 贴搜索下界（≈0.29）而翻盘 —— **别用那个版本**，它不可信。

⚠️ 数值注意：加权亮度必须用 **int32**（int16 会让 `r*299` 溢出，
   掩码会误吞 62% 的像素，两个方向就量不出差别）。

用法
----
  python tools/check_minimap_uv.py [--map aiji]
产物
----
  .workbuddy/tmp/mm_uv_check.png   两套方向的对照图（上=0.5-z/S，下=z/S+0.5）
"""

import argparse
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import walkway_mask as WM  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MM = os.path.join(ROOT, "game", "assets", "uitex", "subc", "m_%s.png")
TPOS = os.path.join(ROOT, "game", "data", "maps", "%s_tilepos.json")
OUT = os.path.join(ROOT, ".workbuddy", "tmp", "mm_uv_check.png")
BOARD_SIZE = 200.0
NAMES = {True: "0.5 - z/S  (旧写法)", False: "z/S + 0.5  (与棋盘地面一致)"}


# ------------------------------------------------------------------ 数据

def load_tiles(map_name):
    with open(TPOS % map_name, "r", encoding="utf-8") as f:
        d = json.load(f)
    ts = d.get("tiles", d)
    bs = float(d.get("_board_size", BOARD_SIZE))
    pts = []
    for t in ts:
        if "x" in t and "z" in t:
            pts.append((float(t["x"]), float(t["z"])))
        else:
            pts.append(((float(t["px"]) / 1024.0 - 0.5) * bs,
                        (float(t["py"]) / 1024.0 - 0.5) * bs))
    return pts, bs


def route_mask(img):
    """小地图上的深棕路线线条 → 布尔掩码（必须 int32，见文件头）"""
    a = np.asarray(img.convert("RGB")).astype(np.int32)
    r, g, b = a[:, :, 0], a[:, :, 1], a[:, :, 2]
    lum = (r * 299 + g * 587 + b * 114) // 1000
    # 实测：路线 ≈ (102,70,26)；沙地 (190,161,110)、橄榄 (137,139,80)、河 (28,74,120)
    return (lum < 135) & (r > b + 25) & (r > 60)


def project(pts, bs, W, H, flip_v):
    xs, ys = [], []
    for (x, z) in pts:
        ux = x / bs + 0.5
        uy = (0.5 - z / bs) if flip_v else (z / bs + 0.5)
        xs.append(ux * (W - 1))
        ys.append(uy * (H - 1))
    return np.array(xs), np.array(ys)


def walkway_mask_1024(map_name):
    _a, raw, _sd = WM.build(map_name, "ditu")
    m, _info, _lab, _n = WM.clean(raw)
    return m


# ------------------------------------------------------------------ 判据 C（最硬）
def crit_c(map_name, rmask):
    """左右环高度序：两张图上「左环比右环高」是否一致"""
    m = walkway_mask_1024(map_name)
    lab, n = ndimage.label(m, np.ones((3, 3)))
    sz = np.array(ndimage.sum(np.ones_like(lab), lab, range(1, n + 1)))
    keep = [int(k) + 1 for k in np.argsort(sz)[::-1][:2]]
    comps = []
    for k in keep:
        yy, xx = np.nonzero(lab == k)
        comps.append((float(xx.mean()), float(yy.mean()), int((lab == k).sum())))
    comps.sort()                                  # 按 x 排：左环、右环
    (lx, ly, lp), (rx, ry, rp) = comps
    H, W = rmask.shape
    ys, xs = np.nonzero(rmask)
    rows = {}
    for lo, hi, tag in ((0, W // 2, "左半"), (W // 2, W, "右半")):
        k = (xs >= lo) & (xs < hi)
        rows[tag] = float(ys[k].mean())
    ground_left_higher = ly < ry                  # ditu 上左环更靠上（y 更小）
    mini_left_higher = rows["左半"] < rows["右半"]
    print("C 左右环高度序（唯一翻不了盘的判据）")
    print("   ditu.tga 步道：左环质心 y=%.1f（%d px）  右环 y=%.1f（%d px）  → 左环%s"
          % (ly, lp, ry, rp, "更高" if ground_left_higher else "更低"))
    print("   小地图路线：  左半平均行 %.1f   右半 %.1f  → 左半%s"
          % (rows["左半"], rows["右半"], "更高" if mini_left_higher else "更低"))
    if ground_left_higher == mini_left_higher:
        # 一致 → v 随 z 单调递增 → z/S + 0.5
        print("   → 一致，故小地图必须用 **z/S + 0.5**（PASS）")
        return False, mini_left_higher
    print("   → 相反，故小地图应用 **0.5 - z/S**（FAIL）")
    return True, mini_left_higher


# ------------------------------------------------------------------ 判据 A / B / D
def crit_a(pts, bs, W, H, rmask, flip):
    dt = ndimage.distance_transform_edt(~rmask)
    xs, ys = project(pts, bs, W, H, flip)
    xi = np.clip(np.round(xs).astype(int), 0, W - 1)
    yi = np.clip(np.round(ys).astype(int), 0, H - 1)
    return dt[yi, xi]


def crit_b(wmask_down, rmask):
    dt = ndimage.distance_transform_edt(~rmask)
    return dt[wmask_down]


def crit_e(map_name, rmask, content=(4, 96, 4, 251)):
    """IoU（无自由参数）：把步道掩码按**固定内容矩形**投到小地图，与路线掩码比。

    内容矩形 rows 4..96 / cols 4..251 由「路线掩码 bbox(3..97 / 4..251) + 边框宽」推出。
    因为映射固定，细线/宽带不会「塌缩对齐」作弊 → 比自由拟合可信。
    """
    m = walkway_mask_1024(map_name)
    H, W = rmask.shape
    ys, xs = np.nonzero(m)
    U = xs / 1023.0
    V = ys / 1023.0
    r0, r1, c0, c1 = content
    out = {}
    for flip in (True, False):
        vv = (1.0 - V) if flip else V
        cc = np.clip(np.round(c0 + U * (c1 - c0)).astype(int), 0, W - 1)
        rr = np.clip(np.round(r0 + vv * (r1 - r0)).astype(int), 0, H - 1)
        T = np.zeros((H, W), bool)
        T[rr, cc] = True
        best = (0.0, 0.0, 0)
        for k in (2, 3, 4, 5, 6):
            rd = ndimage.binary_dilation(rmask, np.ones((2 * k + 1, 2 * k + 1), bool))
            inter = float((T & rd).sum())
            iou = inter / float((T | rd).sum())
            cov = inter / float(T.sum())
            if iou > best[0]:
                best = (iou, cov, k)
        out[flip] = best
    return out


def crit_d(pts, bs, W, H):
    """4 种方向组合的自由仿射拟合（尺度 + 平移），返回 {flip_u, flip_v: 平均距离}"""
    P = np.array(pts)
    out = {}
    for fu in (False, True):
        u = (0.5 - P[:, 0] / bs) if fu else (P[:, 0] / bs + 0.5)
        for fv in (False, True):
            v = (0.5 - P[:, 1] / bs) if fv else (P[:, 1] / bs + 0.5)
            best = None
            for sx in np.arange(0.4, 1.85, 0.05):
                cu = u * (W - 1) * sx
                if cu.max() - cu.min() > W - 1:
                    continue
                oxs = np.arange(-cu.min(), W - cu.max(), 2.0)
                CC = cu[:, None] + oxs[None, :]
                for sy in np.arange(0.20, 1.15, 0.05):
                    cv = v * (H - 1) * sy
                    if cv.max() - cv.min() > H - 1:
                        continue
                    oys = np.arange(-cv.min(), H - cv.max(), 2.0)
                    RR = cv[:, None] + oys[None, :]
                    D = _DT[np.clip(np.round(RR).astype(int), 0, H - 1)[:, None, :],
                            np.clip(np.round(CC).astype(int), 0, W - 1)[:, :, None]].mean(axis=0)
                    m = float(D.min())
                    if best is None or m < best:
                        best = m
            out[(fu, fv)] = best
    return out


_DT = None


def overlay(img, pts, bs, W, H, flip, d, title):
    c = img.copy()
    dr = ImageDraw.Draw(c)
    xs, ys = project(pts, bs, W, H, flip)
    for i in range(len(pts)):
        x, y = float(xs[i]), float(ys[i])
        col = (255, 45, 45) if d[i] > 6 else (30, 220, 90)
        dr.ellipse([x - 2, y - 2, x + 2, y + 2], fill=col)
    dr.rectangle([0, 0, 255, 10], fill=(16, 18, 24))
    dr.text((3, 1), title, fill=(240, 240, 240))
    return c


def main():
    global _DT
    ap = argparse.ArgumentParser()
    ap.add_argument("--map", default="aiji")
    ap.add_argument("--no-fit", action="store_true", help="跳过较慢的 D 判据")
    args = ap.parse_args()

    mm_path = MM % args.map
    if not os.path.exists(mm_path):
        print("缺少小地图：%s" % mm_path)
        return 1
    img = Image.open(mm_path).convert("RGB")
    W, H = img.size
    pts, bs = load_tiles(args.map)
    rmask = route_mask(img)
    _DT = ndimage.distance_transform_edt(~rmask)
    print("小地图 %s  %dx%d | 路线像素 %d | 格点 %d"
          % (os.path.basename(mm_path), W, H, int(rmask.sum()), len(pts)))
    print("=" * 74)

    flip, _ = crit_c(args.map, rmask)

    print("-" * 74)
    print("E IoU（固定内容矩形，无自由参数，可信）")
    e = crit_e(args.map, rmask)
    for f in (True, False):
        print("   %-30s IoU %.3f / 覆盖 %.3f (dilate k=%d)" % ((NAMES[f],) + e[f]))
    print("A 点→线距离（弱判据）")
    for f in (True, False):
        da = crit_a(pts, bs, W, H, rmask, f)
        print("   %-30s 中位 %5.2f / 90%% %5.2f px"
              % (NAMES[f], np.median(da), np.percentile(da, 90)))
    print("B 步道形状→路线距离（弱判据，作废参考）")
    m = walkway_mask_1024(args.map)
    sy = m.shape[0] // H
    sx = m.shape[1] // W
    wmask_down = m[:H * sy, :W * sx].reshape(H, sy, W, sx).mean(axis=(1, 3)) > 0.30
    for f in (True, False):
        wm = np.flipud(wmask_down) if f else wmask_down
        db = crit_b(wm, rmask)
        print("   %-30s 均值 %5.2f px" % (NAMES[f], np.nanmean(db)))

    if not args.no_fit:
        print("D 自由仿射拟合（有判别力，只能吸收内容矩形未知）")
        r = crit_d(pts, bs, W, H)
        for (fu, fv), v in sorted(r.items(), key=lambda kv: kv[1]):
            tag = ("u=x/S+.5 " if not fu else "u=.5-x/S ") + ("v=z/S+.5" if not fv else "v=.5-z/S")
            print("   %-24s mean %5.2f px%s" % (tag, v, "   ← 最优" if v == min(r.values()) else ""))

    print("=" * 74)
    print("结论：minimap.gd 的 `_uv()` 应写 **Vector2(w.x/b + 0.5, w.y/b + 0.5)**")

    da_t = crit_a(pts, bs, W, H, rmask, True)
    da_f = crit_a(pts, bs, W, H, rmask, False)
    top = overlay(img, pts, bs, W, H, True, da_t, "old: 0.5 - z/S")
    bot = overlay(img, pts, bs, W, H, False, da_f, "fixed: z/S + 0.5")
    combo = Image.new("RGB", (W, H * 2 + 6), (20, 20, 24))
    combo.paste(top, (0, 0))
    combo.paste(bot, (0, H + 6))
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    combo.save(OUT)
    print("对照图 → %s" % OUT)
    return 0 if flip is False else 2


if __name__ == "__main__":
    sys.exit(main())
