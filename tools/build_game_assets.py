# -*- coding: utf-8 -*-
"""
把原版素材落进 Godot 工程（game/assets/）。

来源：
  samples/scene/<map>/ditu*.tga        地形贴图（整张棋盘）
  samples/scene/<map>/ditan.tga        地块地毯贴花
  samples/scene/<map>/gravel*.tga      碎石路质感
  samples/actor/rolemark/*.tga         12 个角色地面标记
  samples/actor/role*/<tex>.tga        12 个角色贴图（做头像/身体用）
  F:/游戏/Rich6/sound/effect/*.wav     音效（含 sndeffect.txt 的 2D/3D 分类）
产物：PNG（Godot 稳定支持）+ WAV + index.json

版权：素材属软星科技，仅限个人学习研究，不得商用分发。
"""
import json
import os
import re
import shutil

from PIL import Image

ROOT = r"D:\Projects\RichMan"
SAMPLES = os.path.join(ROOT, "samples")
ASSETS = os.path.join(ROOT, "game", "assets")
SND = r"F:\游戏\Rich6\sound\effect"

ROLE_DIRS = ["role1", "role2", "role3", "role4", "role5", "role6",
             "role7", "role8", "role9", "rolea", "roleb", "rolec"]


def conv(src, dst, size=None):
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    try:
        im = Image.open(src)
        mode = im.mode
        if size:
            im = im.resize(size, Image.LANCZOS)
        if im.mode != "RGBA":
            im = im.convert("RGBA")
        im.save(dst)
    except Exception as e:
        # 部分原版 tga 文件被截断（少几字节），单独跳过而不是整体失败
        print(f"    !! 跳过 {os.path.basename(src)}: {type(e).__name__}: {e}")
        return None
    return {"src": src, "dst": dst, "size": list(im.size), "src_mode": mode}


def conv_tree(src_dir, rel_prefix, bucket, index, size=None):
    """把一整棵素材目录（含子目录）转成 PNG，保留相对路径。
    跳过 descript.ion / *copy* / 非 .tga。"""
    n = 0
    if not os.path.isdir(src_dir):
        return 0
    for dirpath, _dirnames, filenames in os.walk(src_dir):
        for fn in sorted(filenames):
            if not fn.lower().endswith(".tga"):
                continue
            low = fn.lower()
            if "copy" in low or low.startswith("descript"):
                continue
            rel_src = os.path.relpath(os.path.join(dirpath, fn), src_dir)
            rel = os.path.join(rel_prefix, rel_src).replace("\\", "/")
            rel = os.path.splitext(rel)[0] + ".png"
            info = conv(os.path.join(dirpath, fn), os.path.join(ASSETS, rel), size)
            if info is None:
                continue
            index.setdefault(bucket, {})[rel] = info
            n += 1
    return n


def main():
    index = {"terrain": {}, "decals": {}, "ui": {}, "markers": {}, "roles": {},
             "audio": {}, "uitex": {}, "subc": {}}

    # 1) 地形 / 贴花 / 质感（只用埃及，其余地图无 ditu* 资源）
    tex_root = os.path.join(SAMPLES, "scene", "aiji")
    mapping = [
        ("ditu.tga", "terrain/aiji_ground.png", None),
        ("ditu_noshadow.tga", "terrain/aiji_ground_noshadow.png", None),
        ("ditu2_1024.tga", "terrain/aiji_ground_editor.png", None),
        ("ditan.tga", "decals/rug.png", None),
        ("gravel.tga", "terrain/gravel.png", None),
        ("platform/mtlplat2.tga", "terrain/aiji_plot_border.png", None),
        ("m_aiji.tga", "ui/aiji_preview.png", (368, 184)),
        ("sketch.tga", "terrain/aiji_sketch.png", None),
    ]
    for src_name, rel, size in mapping:
        src = os.path.join(tex_root, src_name)
        if not os.path.exists(src):
            src = os.path.join(SAMPLES, "scene", "aiji", src_name)
        if os.path.exists(src):
            info = conv(src, os.path.join(ASSETS, rel), size)
            if info is None:
                continue
            bucket = "terrain" if rel.startswith("terrain") else (
                "decals" if rel.startswith("decals") else "ui")
            index[bucket][rel] = info
            print("  贴图", src_name, "->", rel)

    # 2) 角色地面标记
    mk = os.path.join(SAMPLES, "actor", "rolemark")
    if os.path.isdir(mk):
        for fn in sorted(os.listdir(mk)):
            if fn.lower().endswith(".tga"):
                stem = re.sub(r"\s+", "", os.path.splitext(fn)[0])
                rel = f"markers/{stem}.png"
                info = conv(os.path.join(mk, fn), os.path.join(ASSETS, rel))
                if info:
                    index["markers"][stem] = info
        print("  地面标记", len(index["markers"]), "个")

    # 3) 角色贴图
    for d in ROLE_DIRS:
        p = os.path.join(SAMPLES, "actor", d)
        if not os.path.isdir(p):
            continue
        tg = [f for f in os.listdir(p) if f.lower().endswith(".tga")]
        if not tg:
            continue
        rel = f"roles/{d}.png"
        info = conv(os.path.join(p, tg[0]), os.path.join(ASSETS, rel))
        if not info:
            continue
        info["tex_name"] = tg[0]
        index["roles"][d] = info
    print("  角色贴图", len(index["roles"]), "个")

    # 3.5) UI 素材整棵树（uitex/，含子目录 subc / house / effect / player …）
    n_ui = conv_tree(os.path.join(SAMPLES, "uitex"), "uitex", "uitex", index)
    print("  UI 贴图", n_ui, "个")

    # 3.6) 骰子图集切片：uitex/labar/骰子.tga = 3 列 × 2 行共 6 面
    #      列起点 11/45/78，面 33×32，行高 32（实测 alpha 连通区）
    dice_src = os.path.join(SAMPLES, "uitex", "labar", "骰子.tga")
    if os.path.exists(dice_src):
        try:
            sheet = Image.open(dice_src).convert("RGBA")
            for r in range(2):
                for c in range(3):
                    face = r * 3 + c + 1
                    box = (11 + 34 * c, 32 * r, 11 + 34 * c + 33, 32 * r + 32)
                    cell = sheet.crop(box)
                    rel = f"dice/{face}.png"
                    dst = os.path.join(ASSETS, rel)
                    os.makedirs(os.path.dirname(dst), exist_ok=True)
                    cell.save(dst)
                    index.setdefault("dice", {})[rel] = {
                        "src": dice_src, "box": list(box), "size": list(cell.size)}
            print("  骰子面 6 张")
        except Exception as e:
            print("    !! 骰子切片失败:", e)

    # 4) 音效 + 2D/3D 分类
    if os.path.isdir(SND):
        dst_dir = os.path.join(ASSETS, "audio", "effect")
        os.makedirs(dst_dir, exist_ok=True)
        kinds = {}
        lst = os.path.join(SND, "sndeffect.txt")
        if os.path.exists(lst):
            txt = open(lst, "rb").read().decode("gbk", "replace")
            for ln in txt.splitlines():
                m = re.match(r"\s*(\d+)\s+(\S+)", ln)
                if m:
                    kinds[m.group(1)] = m.group(2)
        n = 0
        for fn in sorted(os.listdir(SND)):
            if fn.lower().endswith(".wav"):
                shutil.copy2(os.path.join(SND, fn), os.path.join(dst_dir, fn))
                n += 1
        index["audio"] = {
            "dir": "audio/effect",
            "count": n,
            "kinds": kinds,
            "_comment": "kinds 来自原版 sound/effect/sndeffect.txt：2D 为界面音，3D 为空间音",
        }
        print("  音效", n, "个")

    with open(os.path.join(ASSETS, "index.json"), "w", encoding="utf-8") as f:
        json.dump({
            "_comment": "由 tools/build_game_assets.py 从原版素材生成",
            "_copyright": "素材版权属软星科技，仅限个人学习研究，不得商用分发",
            **index,
        }, f, ensure_ascii=False, indent=1)
    print("索引 ->", os.path.join(ASSETS, "index.json"))


if __name__ == "__main__":
    main()
