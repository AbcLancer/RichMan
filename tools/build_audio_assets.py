#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""从原版安装目录构建**运行时音频素材**（game/assets/audio/**）与权威映射表。

原版音频分四棵树（都在 `F:\\游戏\\Rich6\\sound\\` 下，**不在 pck 里**）：

    effect/NNN.wav            151 个环境/界面音效（+107b 变体），种类见 effect/sndeffect.txt
    music/m010NN.MP3          18 首 BGM（exe 里格式串是 `%ssound\\music\\m%.5d.wav`）
    player/roleK/*.wav        12 角色配音：27 条情景对白（文件名=消息 id，如 1001.wav）
                              + card/NN.wav（42 张卡名）+ card/NNb.wav（12 张卡的"回"话）
    pet/<species>/01..09.wav  9 只宠物，各 9 句

**关键**：文件名与 `config/Info.txt` 的消息 id 一一对应，所以映射不用猜——
    player/role1/1001.wav  ←→  Info.txt  1001攻击 { 5001, ... } （钱夫人·攻击）
    player/role1/card/03.wav ←→ Info.txt `3 穷神卡 { 7503 }`  （Card.txt 第 3 张）
    pet/qiongshen/01.wav   ←→  Info.txt  101发特技 { 6001 }  （小穷神·发特技）

产出：
    game/assets/audio/effect/*.wav
    game/assets/audio/music/*.mp3
    game/assets/audio/voice/roleK/**  voice/pet/<sp>/*
    game/assets/audio/voice_map.json      ← 游戏运行时读这张表
"""
import json
import os
import shutil
import sys
import wave

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import parse_info  # noqa: E402

SRC_SND = r"F:\游戏\Rich6\sound"
SRC_CFG = r"F:\游戏\Rich6\config"
DST = os.path.join(ROOT, "game", "assets", "audio")

# 角色顺序取自 config/Role.txt 的**行序**；Info.txt 里角色段的标题名（巴克力的模型是恐龙，故叫"小恐龙"）
ROLES = [
    (1, "role1", "钱夫人", "钱夫人"),
    (2, "role2", "阿土伯", "阿土伯"),
    (3, "role3", "宫本宝藏", "宫本宝藏"),
    (4, "role4", "乌咪", "乌咪"),
    (5, "role5", "孙小美", "孙小美"),
    (6, "role6", "金贝贝", "金贝贝"),
    (7, "role7", "巴克力", "小恐龙"),
    (8, "role8", "沙隆巴斯", "沙隆巴斯"),
    (9, "role9", "舞美拉", "舞美拉"),
    (10, "rolea", "DDR", "DDR"),
    (11, "roleb", "爱丽丝", "爱丽丝"),
    (12, "rolec", "奇奇", "奇奇"),
]

# 宠物顺序取自 config/Pet.txt 行序
PETS = [
    (1, "小穷神", "qiongshen"),
    (2, "糊涂鬼", "hutu"),
    (3, "小恶魔", "emo"),
    (4, "小财神", "caishen"),
    (5, "小土神", "tushen"),
    (6, "雪精灵", "jingling"),
    (7, "花仙子", "huaxian"),
    (8, "小赌神", "dushen"),
    (9, "小怪兽", "guaishou"),
]

# 12 张卡有"回"话（Info.txt 3穷神卡回{7551} … 38均富卡回{7562}，顺序即此）
CARD_REPLY_NUMS = [3, 4, 8, 17, 19, 20, 23, 24, 35, 36, 37, 38]

# 27 条情景对白的**语义标签**（后两位 → 标签），来源 Info.txt 钱夫人段
ROLE_LINE_FALLBACK = {
    1: "攻击", 2: "攻击", 3: "自利行为", 4: "自利行为", 5: "被害", 6: "被害",
    7: "被轻罚时", 8: "被轻罚时", 9: "被重罚时", 10: "被重罚时", 11: "快破产时",
    12: "胜利", 13: "破产", 14: "住院", 15: "中乐透", 16: "一般笑",
    17: "得到金钱", 18: "得到金钱", 19: "大吉事件", 20: "大吉事件",
    21: "租金免付", 22: "租金免付", 23: "问候", 24: "问候", 25: "睡觉",
    26: "登场", 27: "选单",
}
PET_LINE_FALLBACK = {
    1: "发特技", 2: "平时", 3: "平时", 4: "平时", 5: "悲伤",
    6: "被PK", 7: "濒临逃离", 8: "PK逃离", 9: "HP逃离",
}


def read_gbk(path):
    return open(path, "rb").read().decode("gbk", errors="replace")


def wav_props(path):
    with wave.open(path, "rb") as w:
        return dict(ch=w.getnchannels(), sw=w.getsampwidth(), sr=w.getframerate(),
                    dur=round(w.getnframes() / max(1, w.getframerate()), 3))


def copy_tree(src, dst, exts=(".wav", ".mp3"), verbose=False):
    """递归复制（只挑扩展名，忽略大小写），返回 (文件数, 字节数)。"""
    n = b = 0
    for dirpath, _dirs, files in os.walk(src):
        rel = os.path.relpath(dirpath, src)
        out = dst if rel == "." else os.path.join(dst, rel)
        for fn in files:
            if not fn.lower().endswith(exts):
                continue
            os.makedirs(out, exist_ok=True)
            s = os.path.join(dirpath, fn)
            d = os.path.join(out, fn.lower())
            if os.path.exists(d) and os.path.getsize(d) == os.path.getsize(s):
                n += 1
                b += os.path.getsize(s)
                continue
            shutil.copy2(s, d)
            n += 1
            b += os.path.getsize(s)
            if verbose:
                print("   +", os.path.relpath(d, DST))
    return n, b


def parse_sndeffect(path):
    """effect/sndeffect.txt -> {id:int -> '2D'|'3D'}"""
    out = {}
    for line in read_gbk(path).splitlines():
        t = line.strip()
        if not t or t.startswith("//"):
            continue
        p = t.split()
        if len(p) >= 2 and p[0].isdigit():
            out[int(p[0])] = p[1]
    return out


def parse_card_names(path):
    lines = [l.strip() for l in read_gbk(path).splitlines() if l.strip()]
    nums = int(lines[0])
    names = lines[1:1 + nums]
    return names


def parse_pet_table(path):
    """config/Pet.txt -> [{name, dir}]（只看名字行，跳过 '15 20 25 30   //...' 这类数值行）"""
    out = []
    for line in read_gbk(path).splitlines():
        t = line.strip()
        if not t or t.startswith("//"):
            continue
        p = t.split()
        if len(p) >= 2 and not p[0][0].isdigit():
            out.append(dict(name=p[0], dir=p[1]))
    return out


def parse_roles(path):
    """config/Role.txt -> [{name, dir}]"""
    out = []
    for line in read_gbk(path).splitlines():
        t = line.strip()
        if not t or t.startswith("//"):
            continue
        p = t.split()
        # 人名  模型目录  害人积极性 ...  标志色 R G B   （约 10 栏，不同角色略有出入）
        if len(p) >= 8 and p[1].startswith("role"):
            out.append(dict(name=p[0], dir=p[1]))
    return out


def main():
    if not os.path.isdir(SRC_SND):
        print("找不到原版音频目录", SRC_SND)
        return 1
    print(f"原版音频: {SRC_SND}\n目标    : {DST}\n")
    os.makedirs(DST, exist_ok=True)

    # ---------- 1. 复制音频 ----------
    print("[1/3] 复制音频素材")
    e_n, e_b = copy_tree(os.path.join(SRC_SND, "effect"), os.path.join(DST, "effect"))
    print(f"  effect : {e_n:>4} 个  {e_b/1e6:6.1f} MB")
    m_n, m_b = copy_tree(os.path.join(SRC_SND, "music"), os.path.join(DST, "music"))
    print(f"  music  : {m_n:>4} 首  {m_b/1e6:6.1f} MB")
    p_n, p_b = copy_tree(os.path.join(SRC_SND, "player"), os.path.join(DST, "voice"))
    print(f"  player : {p_n:>4} 个  {p_b/1e6:6.1f} MB")
    t_n, t_b = copy_tree(os.path.join(SRC_SND, "pet"), os.path.join(DST, "voice", "pet"))
    print(f"  pet    : {t_n:>4} 个  {t_b/1e6:6.1f} MB")

    # ---------- 2. 读原版配置 ----------
    print("[2/3] 读原版配置生成映射表")
    msgs = parse_info.parse(os.path.join(SRC_CFG, "Info.txt"))
    kinds = parse_sndeffect(os.path.join(SRC_SND, "effect", "sndeffect.txt"))
    card_names = parse_card_names(os.path.join(SRC_CFG, "Card.txt"))
    role_tab = parse_roles(os.path.join(SRC_CFG, "Role.txt"))
    pet_tab = parse_pet_table(os.path.join(SRC_CFG, "Pet.txt"))

    # 消息表按 (分组, mid) 建索引
    by_group = {}
    for m in msgs:
        by_group.setdefault(m["group"], []).append(m)

    def lines_for(group, lo, hi):
        """取某分组里 mid%100 ∈ [lo,hi] 的条目，键 = mid%100 → 标签/配音 id"""
        r = {}
        for m in by_group.get(group, []):
            k = m["mid"] % 100
            if lo <= k <= hi and k not in r:
                r[k] = dict(label=m["label"], snd=m["snd"], text=m["text"])
        return r

    # 角色 → 目录（Role.txt 行序 = Info.txt 角色段序，用 dir 对齐）
    roles = []
    for i, (idx, rdir, name, igroup) in enumerate(ROLES):
        lines = lines_for(igroup, 1, 27)
        if len(lines) < 27:
            lines = {k: dict(label=v, snd=0, text="") for k, v in ROLE_LINE_FALLBACK.items()}
        real_dir = role_tab[i]["dir"] if i < len(role_tab) else rdir
        real_name = role_tab[i]["name"] if i < len(role_tab) else name
        # 卡片音在同一角色的第二个段里（snd 7000/7100/… 区段）
        card_lines = {}
        for m in by_group.get(igroup, []):
            if m["mid"] < 100 and 7000 <= m["snd"] < 8600 and not m["label"].endswith("回"):
                card_lines[m["mid"]] = dict(label=m["label"], snd=m["snd"])
        roles.append(dict(
            idx=idx, name=real_name, name_info=name, dir=real_dir,
            voice_dir=f"voice/{real_dir}",
            line_file_base=real_dir,   # 文件名 = mid（如 role1/1001.wav）
            lines={str(k): v for k, v in sorted(lines.items())},
            card_lines={str(k): v for k, v in sorted(card_lines.items())},
        ))

    cards = [dict(num=i + 1, name=n,
                  voice=f"voice/roleK/card/{i+1:02d}.wav",
                  reply=bool((i + 1) in CARD_REPLY_NUMS))
             for i, n in enumerate(card_names)]

    pets = []
    for idx, pname, pdir in PETS:
        # pet k 的配音 id = (60+k)*100 + 1..9，文件 pet/<dir>/01..09.wav
        base = (60 + idx) * 100
        lines = {}
        for m in msgs:
            if m["type"] == "PETSAY" and base < m["snd"] <= base + 9:
                lines[str(m["snd"] - base)] = m["label"]
        if len(lines) < 9:
            lines = {str(k): v for k, v in PET_LINE_FALLBACK.items()}
        pets.append(dict(idx=idx, name=pname, dir=pdir,
                         voice_dir=f"voice/pet/{pdir}", lines=lines))

    music = sorted(fn[:-4] for fn in os.listdir(os.path.join(DST, "music"))
                   if fn.lower().endswith(".mp3"))

    effect_dir = os.path.join(DST, "effect")
    effects = {}
    for fn in sorted(os.listdir(effect_dir)):
        if not fn.lower().endswith(".wav"):
            continue
        stem = fn[:-4]
        eid = int(stem) if stem.isdigit() else None
        pr = wav_props(os.path.join(effect_dir, fn))
        effects[stem] = dict(id=eid, kind=kinds.get(eid, "?"), file=fn, **pr)

    out = dict(
        _source="原版 F:\\游戏\\Rich6\\sound\\ + config\\{Info,Card,Pet,Role}.txt",
        _generator="tools/build_audio_assets.py",
        _note="文件名与 Info.txt 消息 id 一一对应，映射为原版权威数据，非推测",
        roles=roles,
        cards=cards,
        card_reply_nums=CARD_REPLY_NUMS,
        pets=pets,
        music=music,
        effects=effects,
    )
    dst = os.path.join(DST, "voice_map.json")
    with open(dst, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=1)

    print(f"  voice_map.json: 角色 {len(roles)} / 卡片 {len(cards)} / 宠物 {len(pets)} "
          f"/ BGM {len(music)} / 音效 {len(effects)}")

    # ---------- 3. 补进素材清单 ----------
    idx_path = os.path.join(ROOT, "game", "assets", "index.json")
    if os.path.exists(idx_path):
        d = json.load(open(idx_path, encoding="utf-8"))
        a = d.setdefault("audio", {})
        a["voice_dir"] = "audio/voice"
        a["music_dir"] = "audio/music"
        a["voice_files"] = p_n + t_n
        a["music_count"] = len(music)
        a["map"] = "audio/voice_map.json"
        a["_extra_comment"] = ("voice/ = 原版 sound/player+sound/pet 全量配音；"
                               "music/ = 原版 sound/music 的 18 首 BGM")
        with open(idx_path, "w", encoding="utf-8") as f:
            json.dump(d, f, ensure_ascii=False, indent=1)
        print("[3/3] 已更新 game/assets/index.json 的 audio 段")
    return 0


if __name__ == "__main__":
    sys.exit(main())
