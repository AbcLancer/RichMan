#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""把原版「路面物体 / 事件格图标」转成游戏素材 → `game/assets/roadobj/`。

## 三类输入

| 来源 | 是什么 | 产物 |
|---|---|---|
| `samples/event/*.tga` | **事件格的棋盘图标**（64×64 RGBA，19 个） | `event/<name>.png` |
| `samples/roadobj/<id>/*.tga` | 路面物体的贴图 | `tex/<id>/<名>.png` |
| `samples/roadobj/<id>/model.pol` | 路面物体的**静态网格**（9 个目录有） | `<id>.r6m`（R6BM，格式同建筑） |

## 事件格图标与 Roadevent.txt 的对应

`1 2 3 5 10 20 30 50` = 点券面额的球（Roadevent 11..15 是 5/10/20/30/50；
1/2/3 是更小面额）；其余按文件名直接对上 `Roadevent.txt` 的英文 key：
`platform cardshop hospital cardpt tvnews labar capital pethouse game_a game_b casino`。
`game_b_` 是 game_b 的变体（原版玩过之后再踩的形态）。

## 路面物体的中文名 / 动画属性

中文名取自 `config/scene/<map>/<map>.txt` 的「路面物体出现几率」表的注释，
**逐张地图都一致**（13 项，见 `tools/build_scene_config.py::ROAD_ITEM_KEYS`）。
目录里另有多出来的几个（救护车 / 推土机 / 金币 / 点券 / 降落伞 / 飞弹 / 核弹），
是事件或卡片触发的演出，不在随机生成表里。

`.pol` = 静态网格（可以直接渲染）；`.cvd` = **带动画的网格**（原版自有格式，
尚未逆向）→ `anim: true`，表现层先退回用贴图。

用法：

    .workbuddy/venv/Scripts/python.exe tools/build_road_assets.py
"""

from __future__ import annotations

import io
import json
import os
import struct
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pol2obj  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC_EVENT = os.path.join(ROOT, "samples", "event")
SRC_ROAD = os.path.join(ROOT, "samples", "roadobj")
OUT = os.path.join(ROOT, "game", "assets", "roadobj")

## 目录名 → (中文名, 是否在 Aiji.txt 的随机生成表里, 是否有 .cvd 动画)
## 中文名来自各图 `//路面物体出现几率` 段的注释；`san`=降落伞、`dianjuan`=点券
ITEMS: dict[str, tuple[str, str, bool]] = {
    "card":       ("卡片",   "card",       True),
    "crystal":    ("戒指",   "crystal",    True),
    "hanbao":     ("汉堡",   "hanbao",     True),
    "petegg":     ("神仙蛋", "petegg",     True),
    "robber":     ("强盗",   "robber",     True),
    "bomb":       ("炸弹人", "bomb",       False),
    "thief":      ("小偷",   "thief",      True),
    "block":      ("隔毁",   "block",      False),
    "mine":       ("地雷",   "mine",       False),
    "caishen":    ("财神",   "caishen",    True),
    "fushen":     ("福神",   "fushen",     True),
    "shuaishen":  ("衰神",   "shuaishen",  True),
    "qiongshen":  ("穷神",   "qiongshen",  True),
    # ---- 以下不在随机生成表里，是事件 / 卡片 / 异常状态的演出 ----
    "ambulance":  ("救护车", "",           False),
    "bulldozer":  ("推土机", "",           False),
    "gold":       ("金币",   "",           False),
    "dianjuan":   ("点券",   "",           True),
    "missile":    ("飞弹",   "",           False),
    "missile1":   ("核弹",   "",           False),
    "san":        ("降落伞", "",           True),
}

## 事件格图标 → Roadevent.txt 的 key（点券球按面额）
EVENT_ICONS: dict[str, str] = {
    "1": "credit1", "2": "credit2", "3": "credit3", "5": "credit5",
    "10": "credit10", "20": "credit20", "30": "credit30", "50": "credit50",
    "capital": "capital", "cardpt": "cardpt", "cardshop": "cardshop",
    "casino": "casino", "game_a": "game_a", "game_b": "game_b",
    "game_b_": "game_b_seen", "hospital": "hospital", "labar": "labar",
    "pethouse": "pethouse", "tvnews": "tvnews",
}


def png(im: Image.Image, path: str) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    im.save(path)


def pack_r6bm(g: dict, tex_png: str, out_path: str) -> tuple[float, float, float]:
    """把 load_pol 的结果写成 R6BM（与 tools/pol2obj.py::pack_meshes 同格式）。

    归一化规则一样：水平长边 = 1.0、底面 y = 0、水平居中。
    返回归一化后的 (尺寸)。
    """
    pos = np.asarray(g["pos"], dtype=np.float64)
    uv = np.asarray(g["uv"], dtype=np.float64)
    tri = np.asarray(g["tri"], dtype=np.uint32)

    mn, mx = pos.min(0), pos.max(0)
    off = np.array([(mn[0] + mx[0]) / 2.0, mn[1], (mn[2] + mx[2]) / 2.0])
    pos = pos - off
    foot = max(mx[0] - mn[0], mx[2] - mn[2], 1e-6)
    pos = pos / foot
    # ⚠ numpy 2.x 删掉了 ndarray.ptp()，用 np.ptp()
    size = (float(np.ptp(pos[:, 0])), float(np.ptp(pos[:, 1])), float(np.ptp(pos[:, 2])))
    uv_godot = np.stack([uv[:, 0], 1.0 - uv[:, 1]], axis=1)   # Godot: v=0 在顶部

    with open(out_path, "wb") as f:
        f.write(b"R6BM")
        f.write(struct.pack("<III", 1, len(pos), len(tri)))
        f.write(struct.pack("<3f", *size))
        f.write(struct.pack("<3f", *[float(v) for v in off]))
        f.write(pos.astype("<f4").tobytes())
        f.write(uv_godot.astype("<f4").tobytes())
        f.write(tri.astype("<u4").tobytes())
    return size


def main() -> int:
    os.makedirs(OUT, exist_ok=True)
    doc: dict = {
        "_source": "F:\\游戏\\Rich6\\（samples/event + samples/roadobj，tools/r6pck.py 解出）",
        "_note": "事件格图标 64×64；路面物体贴图 + 静态网格（.pol → R6BM）。"
                 ".cvd（带动画）尚未逆向 → anim=true 的项表现层先用图标兜底。",
        "event_icons": {},
        "items": {},
    }

    # ---- ① 事件格图标 ----
    n_ev = 0
    if os.path.isdir(SRC_EVENT):
        for fn in sorted(os.listdir(SRC_EVENT)):
            if not fn.lower().endswith(".tga"):
                continue
            stem = os.path.splitext(fn)[0]
            im = Image.open(os.path.join(SRC_EVENT, fn)).convert("RGBA")
            rel = "event/%s.png" % stem
            png(im, os.path.join(OUT, rel))
            doc["event_icons"][EVENT_ICONS.get(stem, stem)] = rel
            n_ev += 1

    # ---- ② 每个路面物体：贴图 + 静态网格 ----
    n_tex = n_model = 0
    for rid in sorted(os.listdir(SRC_ROAD)):
        d = os.path.join(SRC_ROAD, rid)
        if not os.path.isdir(d):
            continue
        cn, road_key, _anim = ITEMS.get(rid, (rid, "", False))
        rec: dict = {"cn": cn, "road_item": road_key or None, "tex": [], "model": None}

        for fn in sorted(os.listdir(d)):
            if fn.lower().endswith(".tga"):
                try:
                    im = Image.open(os.path.join(d, fn)).convert("RGBA")
                except Exception as e:                       # noqa: BLE001
                    print("  !! 贴图读失败 %s/%s: %s" % (rid, fn, e))
                    continue
                rel = "tex/%s/%s.png" % (rid, os.path.splitext(fn)[0].replace(" ", "_"))
                png(im, os.path.join(OUT, rel))
                rec["tex"].append(rel)
                n_tex += 1

        pol = os.path.join(d, "model.pol")
        if os.path.exists(pol):
            try:
                g = pol2obj.load_pol(pol)
                if len(g["tri"]) and len(g["pos"]):
                    # 模型自己的贴图（原版材质块里的名字）优先
                    tex_src = None
                    if g.get("tex"):
                        cand = os.path.join(d, g["tex"])
                        if os.path.exists(cand):
                            tex_src = cand
                    if tex_src is None and rec["tex"]:
                        tex_src = os.path.join(d, os.listdir(d)[0]) if False else None
                    if tex_src is None:
                        cands = [f for f in sorted(os.listdir(d)) if f.lower().endswith(".tga")]
                        if cands:
                            tex_src = os.path.join(d, cands[0])
                    tex_rel = ""
                    if tex_src:
                        im = Image.open(tex_src).convert("RGB")
                        tex_rel = "tex/%s__%s.png" % (
                            rid, os.path.splitext(os.path.basename(tex_src))[0].replace(" ", "_"))
                        png(im, os.path.join(OUT, tex_rel))
                    size = pack_r6bm(g, tex_rel, os.path.join(OUT, rid + ".r6m"))
                    rec["model"] = rid + ".r6m"
                    rec["model_tex"] = tex_rel
                    rec["size"] = [round(v, 4) for v in size]
                    n_model += 1
            except Exception as e:                           # noqa: BLE001
                print("  !! 网格打包失败 %s: %s" % (rid, e))

        rec["anim"] = bool(rec["model"] is None)
        doc["items"][rid] = rec

    with io.open(os.path.join(OUT, "index.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(doc, f, ensure_ascii=False, indent=1)
        f.write("\n")

    print("roadobj → %s" % OUT)
    print("  事件格图标 %d 个；物体 %d 个（贴图 %d 张，静态网格 %d 个）"
          % (n_ev, len(doc["items"]), n_tex, n_model))
    anim = [k for k, v in doc["items"].items() if v["anim"]]
    print("  待逆 .cvd 的（anim）: %s" % ", ".join(sorted(anim)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
