#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""从「BGM 标记副本」的录音里读出**当前播放的是哪一首 BGM**。

配合 tools/make_bgm_probe.py 使用：副本里 18 首 BGM 已被换成
420 / 460 / 500 … 1100 Hz（步长 40Hz）的长纯音标记，录音里出现哪个频率就是哪一首。

用法：
    python tools/bgm_identify.py <wav> [窗长秒]
"""
import json
import os
import sys
import wave

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MAP = os.path.join(ROOT, ".workbuddy", "sfx", "bgm_map.json")


def load(path):
    with wave.open(path) as w:
        sr, ch, n = w.getframerate(), w.getnchannels(), w.getnframes()
        x = np.frombuffer(w.readframes(n), dtype="<i2").astype(np.float64)
    x = x.reshape(-1, ch).mean(axis=1) / 32768.0
    return sr, x


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 1
    wav = sys.argv[1]
    win_s = float(sys.argv[2]) if len(sys.argv) > 2 else 5.0
    m = json.load(open(MAP, encoding="utf-8"))
    tracks = sorted(m.items(), key=lambda kv: kv[1]["idx"])
    freqs = np.array([v["freq"] for _k, v in tracks])
    names = [k for k, _v in tracks]

    sr, x = load(wav)
    print(f"{wav}: {len(x)/sr:.2f}s @ {sr}Hz")
    N = 16384
    spec_f = np.fft.rfftfreq(N, 1 / sr)
    # 18 个标记音各自对应的 bin（±2 bin 取最大）
    idx = [int(round(f / (sr / N))) for f in freqs]
    win = np.hanning(N)

    def vote(seg):
        if len(seg) < N:
            return None, 0.0
        acc = np.zeros(len(spec_f))
        c = 0
        for i in range(0, len(seg) - N, N // 2):
            s = seg[i:i + N] * win
            acc += np.abs(np.fft.rfft(s))
            c += 1
        if c == 0:
            return None, 0.0
        acc /= c
        vals = []
        for b in idx:
            lo, hi = max(0, b - 2), min(len(acc), b + 3)
            vals.append(acc[lo:hi].max())
        vals = np.array(vals)
        k = int(np.argmax(vals))
        second = float(np.sort(vals)[-2]) if len(vals) > 1 else 0.0
        # 置信度 = 主峰 / 次峰（越大越干净）
        conf = float(vals[k] / second) if second > 0 else 999.0
        return names[k], conf, float(freqs[k])

    # 全程
    r = vote(x)
    if r[0] is None:
        print("  录音太短或全静音")
        return 0
    print(f"  全程主音: {r[0]}  f={r[2]:.0f}Hz  置信 {r[1]:.1f}x")

    # 分段
    step = int(win_s * sr)
    print(f"  分段（{win_s:.0f}s）:")
    for i in range(0, len(x) - step + 1, step):
        rr = vote(x[i:i + step])
        if rr[0] is None:
            continue
        t0, t1 = i / sr, (i + step) / sr
        bar = "#" * int(min(30, rr[1]))
        print(f"    {t0:7.1f}–{t1:7.1f}s  {rr[0]}  f={rr[2]:6.0f}Hz  置信 {rr[1]:6.1f}x {bar}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
