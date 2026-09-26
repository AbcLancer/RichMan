#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""原版音效实证探针 —— 用"标记音替换 + 系统回环录音"反推「哪个动作播了哪个音效 ID」。

原理：
  原版把「音效 ID → 播放时机」写死在 exe 代码里，数据层无表可查。
  于是把运行副本 sound/effect/NNN.wav 全部换成**唯一频率的纯音标记**
  （保留原文件的声道数/采样率/位深，避免 3D 音被判为 stereo 拒载），
  再抓系统回环音频跑游戏。录音里出现哪个频率，就说明 ID=NNN 被触发了。

子命令：
    record <wav> <秒数> [设备索引]   录制系统回环音频
    prepare [目标目录]               生成标记音运行副本 F:\\游戏\\Rich6probe
    analyze <wav>                    检测录音中的标记音 -> 时间线

依赖：pyaudiowpatch（已在 .workbuddy/venv 安装）
"""
import json
import math
import os
import sys
import time
import wave

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC_GAME = r"F:\游戏\Rich6"
RUN_GAME = r"F:\游戏\Rich6run"
PROBE = r"F:\游戏\Rich6probe"
EFFECT_REL = os.path.join("sound", "effect")
MARKER_MAP = os.path.join(ROOT, ".workbuddy", "sfx", "marker_map.json")

# 标记音：400~4000Hz 之间均匀分布，步长足够 FFT 分辨
F0, F1 = 420.0, 4020.0


def marker_freq(eid, n=151):
    return F0 + (F1 - F0) * (eid - 1) / max(1, n - 1)


def read_props(path):
    with wave.open(path, "rb") as w:
        return dict(ch=w.getnchannels(), sw=w.getsampwidth(), sr=w.getframerate())


def write_tone(path, freq, props, secs=0.45, amp=0.72):
    """生成标记音：保持原文件的声道数/位深/采样率，只把内容换成纯正弦。"""
    sr, ch, sw = props["sr"], props["ch"], props["sw"]
    n = max(1, int(sr * secs))
    t = np.arange(n) / sr
    x = np.sin(2 * np.pi * freq * t)
    env = np.ones(n)
    a = max(1, int(sr * 0.004))
    env[:a] = np.linspace(0, 1, a)
    d = max(1, int(sr * 0.03))
    env[-d:] = np.linspace(1, 0, d)
    x = x * env * amp
    if sw == 2:
        q = np.clip(x * 32767, -32768, 32767).astype("<i2")
    elif sw == 1:
        q = np.clip(x * 127 + 128, 0, 255).astype(np.uint8)
    else:
        q = np.clip(x * 2147483647, -2147483648, 2147483647).astype("<i4")
    data = np.repeat(q, ch) if ch > 1 else q
    with wave.open(path, "wb") as w:
        w.setnchannels(ch)
        w.setsampwidth(sw)
        w.setframerate(sr)
        w.writeframes(data.tobytes())


def cmd_prepare(dst=PROBE):
    import shutil
    kinds = {}
    p = os.path.join(SRC_GAME, EFFECT_REL, "sndeffect.txt")
    import re
    for line in open(p, encoding="gbk", errors="replace"):
        m = re.match(r"^\s*(\d{3})\s+(2D|3D)\s*$", line.strip(), re.I)
        if m:
            kinds[int(m.group(1))] = m.group(2).upper()

    os.makedirs(dst, exist_ok=True)
    # 1) 复制运行副本（pck 用硬链接省空间/时间）
    for root, dirs, files in os.walk(RUN_GAME):
        rel = os.path.relpath(root, RUN_GAME)
        out = os.path.join(dst, rel) if rel != "." else dst
        os.makedirs(out, exist_ok=True)
        for f in files:
            s, d = os.path.join(root, f), os.path.join(out, f)
            if os.path.exists(d):
                continue
            if f.lower().endswith(".pck"):
                try:
                    os.link(s, d)
                except OSError:
                    shutil.copy2(s, d)
            else:
                shutil.copy2(s, d)
    print("副本就绪:", dst)

    # 2) 关掉 BGM，音量拉满（避免标记音被音乐掩盖）
    ic = os.path.join(dst, "init_cur.txt")
    if os.path.exists(ic):
        t = open(ic, encoding="gbk", errors="replace").read()
        t = t.replace("[musicvol] = [5]", "[musicvol] = [0]")
        t = t.replace("[sndvol] = [5]", "[sndvol] = [10]")
        if "musicvol" not in t:
            t += "\n[musicvol] = [0]\n[sndvol] = [10]\n"
        open(ic, "w", encoding="gbk", errors="replace").write(t)
    it = os.path.join(dst, "init.txt")
    if os.path.exists(it):
        t = open(it, encoding="gbk", errors="replace").read()
        t = t.replace("[musicvol] = [5]", "[musicvol] = [0]")
        t = t.replace("[sndvol] = [5]", "[sndvol] = [10]")
        open(it, "w", encoding="gbk", errors="replace").write(t)

    # 3) 备份原音效并替换为标记音
    ed = os.path.join(dst, EFFECT_REL)
    bak = os.path.join(dst, "sound", "_effect_orig")
    os.makedirs(bak, exist_ok=True)
    m = {}
    for f in sorted(os.listdir(os.path.join(SRC_GAME, EFFECT_REL))):
        if not f.lower().endswith(".wav"):
            continue
        eid = int(f[:3])
        src = os.path.join(SRC_GAME, EFFECT_REL, f)
        shutil.copy2(src, os.path.join(bak, f))
        props = read_props(src)
        fr = marker_freq(eid)
        tgt = os.path.join(ed, f)
        try:
            os.remove(tgt)
        except OSError:
            pass
        write_tone(tgt, fr, props)
        m[str(eid)] = dict(freq=round(fr, 2), kind=kinds.get(eid, "?"),
                           ch=props["ch"], sr=props["sr"], file=f)
    os.makedirs(os.path.dirname(MARKER_MAP), exist_ok=True)
    json.dump(m, open(MARKER_MAP, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(f"已替换 {len(m)} 个标记音 -> {MARKER_MAP}")
    return 0


def _pick_loopback(p):
    """优先选与「默认输出设备」同名的回环端点，避免抓到空闲端点导致 read() 阻塞。"""
    import pyaudiowpatch as pa
    wasapi = p.get_host_api_info_by_type(pa.paWASAPI)
    spk = p.get_device_info_by_index(wasapi["defaultOutputDevice"])
    base = spk["name"].split("(")[0].strip().lower()
    cands = [d for d in p.get_loopback_device_info_generator()]
    for d in cands:
        if base and base in d["name"].lower():
            return d["index"], spk["name"]
    if cands:
        return cands[0]["index"], spk["name"]
    raise RuntimeError("没有可用的 WASAPI 回环端点")


def cmd_record(out, secs, dev=None):
    import pyaudiowpatch as pa
    p = pa.PyAudio()
    if dev is None:
        dev, spkname = _pick_loopback(p)
        print("默认输出:", spkname, "-> loopback 设备", dev)
    d = p.get_device_info_by_index(dev)
    sr, ch = int(d["defaultSampleRate"]), 2
    t0 = time.time()
    open(out + ".start", "w").write(f"{t0:.6f}\n")
    print(f"START_EPOCH={t0:.6f}", flush=True)
    print(f"录制 {secs}s  {sr}Hz x{ch}  [{d['name']}]", flush=True)
    st = p.open(format=pa.paFloat32, channels=ch, rate=sr, input=True,
                input_device_index=dev, frames_per_buffer=1024)
    frames, guard = [], time.time()
    try:
        while time.time() - t0 < secs:
            frames.append(st.read(1024, exception_on_overflow=False))
            if not frames[-1]:
                if time.time() - guard > 4.0:
                    print("!! 回环端点持续无数据，可能是该端点未激活", flush=True)
                    break
            else:
                guard = time.time()
    finally:
        st.stop_stream()
        st.close()
        p.terminate()
    a = np.frombuffer(b"".join(frames), dtype=np.float32)
    if ch > 1 and a.size:
        a = a.reshape(-1, ch).mean(1)
    if a.size == 0:
        print("没有录到任何数据")
        return 2
    with wave.open(out, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes((np.clip(a, -1, 1) * 32767).astype("<i2").tobytes())
    dur = len(a) / sr
    print(f"已保存 {out}  {dur:.2f}s  rms={np.sqrt((a**2).mean()):.5f}  peak={np.abs(a).max():.4f}")
    return 0


def cmd_launch(gamedir=PROBE):
    """脱离父进程启动游戏（DETACHED），避免非交互会话结束时被连带杀掉。"""
    import subprocess
    exe = os.path.join(gamedir, "rich6.exe")
    if not os.path.exists(exe):
        print("找不到", exe)
        return 1
    DETACHED = 0x00000008 | 0x00000200  # DETACHED_PROCESS | CREATE_NEW_PROCESS_GROUP
    p = subprocess.Popen([exe], cwd=gamedir, creationflags=DETACHED,
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    print("已启动", exe, "pid", p.pid)
    return 0


def cmd_kill(name="rich6.exe"):
    import subprocess
    r = subprocess.run(["taskkill", "/F", "/IM", name], capture_output=True, text=True,
                       encoding="gbk", errors="replace")
    print((r.stdout or "") + (r.stderr or ""))
    return 0


def cmd_analyze(path, snr_min=12.0, min_frames=3, floor_db=-52.0):
    """严格版：窄带能量比 + 邻频抑制 + 最短持续时长，避免宽带音的频谱泄漏误命中。

    每个标记音是纯正弦，若被触发，应表现为：
      * 该频点能量远高于全谱中位数（snr）
      * 该频点是标记频率序列中的局部极大（邻频抑制）
      * 至少连续 min_frames 帧都成立（排除瞬时串扰）
    """
    m = json.load(open(MARKER_MAP, encoding="utf-8"))
    ids = np.array([int(k) for k in sorted(m, key=int)])
    freqs = np.array([m[str(i)]["freq"] for i in ids])
    with wave.open(path, "rb") as w:
        sr = w.getframerate()
        a = np.frombuffer(w.readframes(w.getnframes()), dtype="<i2").astype(np.float32) / 32768.0
    print(f"{path}: {len(a)/sr:.2f}s @ {sr}Hz")
    fl, hop = 8192, 256          # 8192/48000 = 171ms 窗 -> 5.9Hz 分辨率
    if len(a) < fl:
        a = np.pad(a, (0, fl - len(a)))
    nfr = 1 + (len(a) - fl) // hop
    idx = np.arange(fl)[None, :] + hop * np.arange(nfr)[:, None]
    S = np.abs(np.fft.rfft(a[idx] * np.hanning(fl), axis=1))
    win = float(np.hanning(fl).sum() / 2.0) or 1.0
    S = S / win * 2.0                                 # 近似单边幅度（满幅正弦=1.0）
    bins = np.round(freqs / sr * fl).astype(int)
    nb = S.shape[1]
    stack = np.stack([S[:, np.clip(bins + d, 0, nb - 1)] for d in (-2, -1, 0, 1, 2)], axis=0)
    band = stack.max(axis=0)                           # (nfr, nids)
    med = np.median(S, axis=1, keepdims=True)          # 每帧本底
    snr = band / (med + 1e-9)
    absdb = 20 * np.log10(band + 1e-9)
    absfloor = 10 ** (floor_db / 20.0)
    ok = (snr > snr_min) & (band > absfloor) & (absdb > floor_db)
    # 邻频抑制：只保留标记序列中的局部极大
    keep = ok.copy()
    for i in range(1, len(ids) - 1):
        keep[:, i] &= (band[:, i] >= band[:, i - 1]) & (band[:, i] >= band[:, i + 1])
    # 连续帧合并
    events = []
    for i in range(len(ids)):
        col = keep[:, i]
        if not col.any():
            continue
        runs = np.flatnonzero(np.diff(np.concatenate(([0], col.view(np.int8), [0]))))
        for k in range(0, len(runs), 2):
            s, e = int(runs[k]), int(runs[k + 1]) - 1
            if e - s + 1 < min_frames:
                continue
            seg = band[s:e + 1, i]
            events.append([int(ids[i]), s * hop / sr, e * hop / sr,
                           round(20 * float(np.log10(seg.max() + 1e-9)), 1)])
    events.sort(key=lambda x: x[1])
    print(f"检测到 {len(events)} 次触发:")
    for eid, t0, t1, db in events:
        print(f"  t={t0:8.3f}s~{t1:8.3f}s  音效 {eid:>3d} [{m[str(eid)]['kind']}] "
              f"f={m[str(eid)]['freq']:7.1f}Hz  {db:6.1f}dB  {t1-t0:.2f}s")
    return events


def cmd_align(wav, logpath=None):
    """把 actions.log 的时间戳换算成录音内相对秒，便于与检测结果对齐。"""
    import calendar
    import datetime as dt
    logpath = logpath or os.path.join(ROOT, ".workbuddy", "sfx", "actions.log")
    t0 = float(open(wav + ".start").read().strip())
    day = dt.datetime.fromtimestamp(t0, dt.timezone.utc).date()
    print(f"录音 {wav} 起始 UTC {dt.datetime.fromtimestamp(t0, dt.timezone.utc):%H:%M:%S}")
    print(f"{'相对秒':>9}  {'UTC':>13}  动作")
    for line in open(logpath, encoding="utf-8"):
        line = line.strip()
        if not line.startswith("["):
            continue
        head, _, msg = line.partition("] ")
        hh, mm, rest = head[1:].split(":")
        ss, ms = rest.split(".")
        t = calendar.timegm((day.year, day.month, day.day, int(hh), int(mm),
                             int(ss), 0, 0, 0)) + int(ms) / 1000.0
        print(f"{t - t0:9.2f}  {hh}:{mm}:{ss}.{ms}  {msg}")
    return 0


if __name__ == "__main__":
    c = sys.argv[1] if len(sys.argv) > 1 else "record"
    if c == "record":
        cmd_record(sys.argv[2], float(sys.argv[3]),
                   int(sys.argv[4]) if len(sys.argv) > 4 else None)
    elif c == "prepare":
        cmd_prepare(sys.argv[2] if len(sys.argv) > 2 else PROBE)
    elif c == "launch":
        cmd_launch(sys.argv[2] if len(sys.argv) > 2 else PROBE)
    elif c == "kill":
        cmd_kill(sys.argv[2] if len(sys.argv) > 2 else "rich6.exe")
    elif c == "analyze":
        cmd_analyze(sys.argv[2])
    elif c == "align":
        cmd_align(sys.argv[2])
