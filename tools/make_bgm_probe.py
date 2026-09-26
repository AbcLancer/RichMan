#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""造一个「BGM 标记副本」，用来实证**哪一首 BGM 在哪个场景播放**。

思路与音效探针一致：把 18 首 BGM 换成**唯一频率的长纯音标记**，
抓系统回环录音，出现哪个频率就知道播的是哪一首。

细节：
  * exe 里的格式串是 `%ssound\\music\\m%.5d.wav`（0x9edb8 / 0x9ee78），
    而随游戏发的却是 `m010NN.MP3` —— 说明引擎按扩展名依次试探。
    于是本副本**不复制 MP3**，只放 `m010NN.wav`（22050Hz 立体声），
    引擎应优先命中 .wav。
  * init.txt 写 `[sndvol]=[0]` / `[musicvol]=[10]`，录音里只剩 BGM，干净。

产出：F:\\游戏\\Rich6bgm  +  .workbuddy/sfx/bgm_map.json

用法：
    python tools/make_bgm_probe.py
"""
import json
import os
import shutil
import subprocess
import sys
import wave

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = r"F:\游戏\Rich6"
DST = r"F:\游戏\Rich6bgm"
OUT = os.path.join(ROOT, ".workbuddy", "sfx")

SKIP_TOP = {"init.txt", "init_cur.txt", "r6log.txt"}
SKIP_REL = {os.path.join("sound", "music")}      # 整个 music 目录自己重建
HARDLINK_EXT = {".pck"}

TONE_SECS = 100.0                # 必须**长于一次录制**，否则引擎播完会自动切下一首
SR, CH = 22050, 1                # BGM 是 2D 音，单声道即可（总时长 100s×18 ≈ 79MB）
F0, STEP = 420.0, 40.0           # 18 首 -> 420 … 1100 Hz，步长 40Hz，FFT 易分辨


def tone_freq(track_idx: int) -> float:
    return F0 + STEP * (track_idx - 1)


def write_tone(path: str, freq: float, secs: float = TONE_SECS) -> None:
    n = int(SR * secs)
    t = np.arange(n) / SR
    x = np.sin(2 * np.pi * freq * t)
    env = np.ones(n)
    a = max(1, int(SR * 0.02))
    env[:a] = np.linspace(0, 1, a)
    env[-a:] = np.linspace(1, 0, a)
    q = np.clip(x * env * 0.6 * 32767, -32768, 32767).astype("<i2")
    if CH == 2:
        q = np.repeat(q[:, None], 2, axis=1).reshape(-1)
    with wave.open(path, "wb") as w:
        w.setnchannels(CH)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(q.tobytes())


def main() -> int:
    if not os.path.isdir(SRC):
        print("源目录不存在:", SRC)
        return 1
    os.makedirs(DST, exist_ok=True)
    os.makedirs(OUT, exist_ok=True)

    n_link = n_copy = n_skip = 0
    for root, _dirs, files in os.walk(SRC):
        rel = os.path.relpath(root, SRC)
        if rel in SKIP_REL:
            n_skip += len(files)
            continue
        out_root = DST if rel == "." else os.path.join(DST, rel)
        os.makedirs(out_root, exist_ok=True)
        for fn in files:
            if rel == "." and fn in SKIP_TOP:
                n_skip += 1
                continue
            src = os.path.join(root, fn)
            dst = os.path.join(out_root, fn)
            if os.path.exists(dst):
                n_skip += 1
                continue
            if os.path.splitext(fn)[1].lower() in HARDLINK_EXT:
                r = subprocess.run(["cmd", "/c", "mklink", "/H", dst, src],
                                   capture_output=True)
                if r.returncode == 0 and os.path.exists(dst):
                    n_link += 1
                    continue
            shutil.copy2(src, dst)
            n_copy += 1

    # 窗口化 + 只留 BGM
    src_init = open(os.path.join(SRC, "init.txt"), "rb").read().decode("gbk")
    s = src_init
    s = s.replace("[fullscreen] = [1]", "[fullscreen] = [0]")
    s = s.replace("[scr_width] = [800]", "[scr_width] = [1024]")
    s = s.replace("[scr_height] = [600]", "[scr_height] = [768]")
    s = s.replace("[sndvol] = [5]", "[sndvol] = [0]")
    s = s.replace("[musicvol] = [5]", "[musicvol] = [10]")
    for name in ("init.txt", "init_cur.txt"):
        with open(os.path.join(DST, name), "wb") as f:
            f.write(s.encode("gbk"))

    # 18 个标记音
    mdir = os.path.join(DST, "sound", "music")
    os.makedirs(mdir, exist_ok=True)
    m = {}
    for i in range(1, 19):
        # 原版文件名是 m01001 … m01018 —— 序号 1001..1018，5 位补零
        tid = "m%05d" % (1000 + i)
        f = tone_freq(i)
        write_tone(os.path.join(mdir, tid + ".wav"), f)
        m[tid] = dict(idx=i, freq=f)
    with open(os.path.join(OUT, "bgm_map.json"), "w", encoding="utf-8") as f:
        json.dump(m, f, ensure_ascii=False, indent=1)

    print(f"目录 : {DST}")
    print(f"硬链接 {n_link} / 实拷贝 {n_copy} / 跳过 {n_skip}")
    print(f"标记音 18 个 -> {os.path.join(OUT,'bgm_map.json')}")
    print(f"频率  : {F0:.0f} … {tone_freq(18):.0f} Hz 步长 {STEP:.0f}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
