#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""原版音效声学分析 —— 把"听一遍"变成可复现的量化报告。

用法:
    python tools/sfx_analyze.py report   # 打印/写出每个音效的特征表
    python tools/sfx_analyze.py sheets   # 渲染波形+频谱图接触表（供人眼比对）
    python tools/sfx_analyze.py all

数据来源: F:/游戏/Rich6/sound/effect/*.wav
分类表:   F:/游戏/Rich6/sound/effect/sndeffect.txt  (2D=界面音 / 3D=空间音)
"""
import os
import re
import sys
import json
import wave
import math

import numpy as np

SRC = r"F:\游戏\Rich6\sound\effect"
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "docs")


def read_kinds():
    """解析 sndeffect.txt -> {id:int -> '2D'|'3D'}"""
    p = os.path.join(SRC, "sndeffect.txt")
    kinds, order = {}, []
    for line in open(p, encoding="gbk", errors="replace"):
        line = line.strip()
        if not line or line.startswith("//"):
            continue
        m = re.match(r"^(\d{3})\s+(2D|3D)$", line, re.I)
        if m:
            i = int(m.group(1))
            kinds[i] = m.group(2).upper()
            order.append(i)
    return kinds, order


def load_wav(path):
    """返回 (float32 mono 归一化, sr, nch)。多声道取均值。"""
    with wave.open(path, "rb") as w:
        nch = w.getnchannels()
        sr = w.getframerate()
        sw = w.getsampwidth()
        n = w.getnframes()
        raw = w.readframes(n)
    if sw == 2:
        a = np.frombuffer(raw, dtype="<i2").astype(np.float32) / 32768.0
    elif sw == 1:
        a = (np.frombuffer(raw, dtype=np.uint8).astype(np.float32) - 128.0) / 128.0
    elif sw == 4:
        a = np.frombuffer(raw, dtype="<i4").astype(np.float32) / 2147483648.0
    else:
        raise ValueError(f"unsupported sampwidth {sw}")
    if nch > 1:
        a = a.reshape(-1, nch).mean(axis=1)
    return a, sr, nch


def features(a, sr):
    """一组用于"猜音色/功能"的描述量。"""
    n = len(a)
    dur = n / sr
    if n == 0:
        return dict(dur=0.0)
    peak = float(np.abs(a).max())
    rms = float(np.sqrt((a ** 2).mean()))
    # 帧化（约 20ms 一帧）
    fl = max(64, int(sr * 0.02))
    hop = max(16, fl // 2)
    nf = max(1, 1 + (n - fl) // hop) if n >= fl else 1
    frames = np.lib.stride_tricks.sliding_window_view(
        np.pad(a, (0, max(0, fl - n))), fl)[::hop][:nf] if n >= fl else a[None, :]
    win = np.hanning(frames.shape[1]).astype(np.float32)
    S = np.abs(np.fft.rfft(frames * win, axis=1)) + 1e-12
    freqs = np.fft.rfftfreq(frames.shape[1], 1.0 / sr)
    pow_ = S ** 2
    tot = pow_.sum(axis=1) + 1e-20
    centroid = (pow_ * freqs).sum(axis=1) / tot
    bw = np.sqrt((pow_ * (freqs[None, :] - centroid[:, None]) ** 2).sum(axis=1) / tot)
    # 谱平坦度（几何均值/算术均值）：噪声→1，乐音→0
    flat = np.exp(np.log(S).mean(axis=1)) / (S.mean(axis=1) + 1e-20)
    # 85% 滚降
    cs = np.cumsum(pow_, axis=1)
    roll = np.array([
        freqs[min(len(freqs) - 1, int(np.searchsorted(cs[i], 0.85 * cs[i, -1])))]
        for i in range(pow_.shape[0])
    ])
    # 帧能量包络 -> 起音数 & 是否"打击型"
    env = np.sqrt((frames.astype(np.float64) ** 2).mean(axis=1))
    env = env / (env.max() + 1e-20)
    d = np.diff(env)
    onsets = int(((d > 0.12) & (env[:-1] < 0.45)).sum())
    ie = int(np.argmax(env)) / max(1, len(env) - 1)
    # 打击型：能量峰值出现在前 15% 且后段衰减
    tail = float(env[int(len(env) * 0.6):].mean()) if len(env) > 4 else 0.0
    percussive = int(ie < 0.18 and tail < 0.35)
    # 过零率（噪声/摩擦音高）
    zcr = float((np.diff(np.sign(a)) != 0).mean())
    # 谐波性：自相关最大峰（0.5ms~20ms 滞后）
    seg = a[: min(len(a), sr * 2)]
    if len(seg) > 256:
        seg = seg - seg.mean()
        ac = np.correlate(seg, seg, "full")[len(seg) - 1:]
        ac = ac / (ac[0] + 1e-20)
        lo, hi = max(1, int(sr / 2000)), min(len(ac) - 1, int(sr / 50))
        harmonic = float(ac[lo:hi].max()) if hi > lo else 0.0
    else:
        harmonic = 0.0
    return dict(
        dur=round(dur, 3), sr=int(sr), peak=round(peak, 3), rms=round(rms, 4),
        centroid=round(float(centroid.mean()), 1),
        centroid_std=round(float(centroid.std()), 1),
        bw=round(float(bw.mean()), 1), flat=round(float(flat.mean()), 4),
        roll=round(float(roll.mean()), 1), onsets=onsets,
        percussive=percussive, zcr=round(zcr, 4), harmonic=round(harmonic, 3),
        loud_db=round(20 * math.log10(rms + 1e-9), 1),
    )


def gather():
    kinds, order = read_kinds()
    rows = []
    for i in sorted(kinds):
        p = os.path.join(SRC, f"{i:03d}.wav")
        if not os.path.exists(p):  # 原版有 074/075 大写扩展名
            p = os.path.join(SRC, f"{i:03d}.WAV")
        if not os.path.exists(p):
            rows.append(dict(id=i, kind=kinds[i], missing=True))
            continue
        a, sr, nch = load_wav(p)
        f = features(a, sr)
        f.update(id=i, kind=kinds[i], ch=nch, kb=round(os.path.getsize(p) / 1024, 1))
        rows.append(f)
    return rows, kinds, order


def guess(row):
    """基于特征给一个粗糙的"音色/功能"猜测标签（仅作线索，最终人工判定）。"""
    if row.get("missing"):
        return "缺文件"
    t = []
    if row["dur"] < 0.22:
        t.append("极短")
    elif row["dur"] < 0.6:
        t.append("短")
    elif row["dur"] < 1.5:
        t.append("中")
    else:
        t.append("长")
    if row["percussive"]:
        t.append("打击")
    if row["flat"] > 0.25 and row["zcr"] > 0.08:
        t.append("噪声/爆炸")
    elif row["harmonic"] > 0.5 and row["flat"] < 0.15:
        t.append("乐音/铃声")
    if row["centroid"] > 3500:
        t.append("高频脆")
    elif row["centroid"] < 900:
        t.append("低频厚")
    if row["onsets"] >= 4:
        t.append(f"多击({row['onsets']})")
    return "/".join(t)


def cmd_report():
    rows, kinds, order = gather()
    os.makedirs(OUT, exist_ok=True)
    json.dump(rows, open(os.path.join(OUT, "sfx-analysis.json"), "w", encoding="utf-8"),
              ensure_ascii=False, indent=1)
    hdr = f"{'id':>4} {'kind':>4} {'kb':>6} {'ch':>2} {'dur':>6} {'rms':>6} {'cent':>7} {'bw':>6} {'flat':>6} {'zcr':>6} {'harm':>5} {'ons':>3} {'P':>1}  猜测"
    lines = [hdr, "-" * 130]
    for r in rows:
        if r.get("missing"):
            lines.append(f"{r['id']:>4} {r['kind']:>4}   缺失")
            continue
        lines.append(
            f"{r['id']:>4} {r['kind']:>4} {r['kb']:>6} {r['ch']:>2} {r['dur']:>6.2f} "
            f"{r['rms']:>6.3f} {r['centroid']:>7.0f} {r['bw']:>6.0f} {r['flat']:>6.3f} "
            f"{r['zcr']:>6.3f} {r['harmonic']:>5.2f} {r['onsets']:>3} {r['percussive']:>1}  {guess(r)}")
    txt = "\n".join(lines)
    print(txt)
    open(os.path.join(OUT, "sfx-analysis.txt"), "w", encoding="utf-8").write(txt + "\n")
    n3 = sum(1 for r in rows if r.get("kind") == "3D")
    n2 = sum(1 for r in rows if r.get("kind") == "2D")
    print(f"\n共 {len(rows)} 条: 2D={n2} 3D={n3}")


def cmd_sheets(per=40):
    """把波形+频谱画成接触表，用眼睛代替耳朵做二次确认。"""
    from PIL import Image, ImageDraw, ImageFont
    rows, kinds, order = gather()
    base = os.path.join(os.path.dirname(OUT), ".workbuddy", "sfx")
    os.makedirs(base, exist_ok=True)
    ids = [r["id"] for r in rows]
    try:
        font = ImageFont.truetype("C:/Windows/Fonts/consola.ttf", 11)
    except Exception:
        font = ImageFont.load_default()
    for ci in range(0, len(ids), per):
        chunk = ids[ci:ci + per]
        cols, rowsn = 5, (len(chunk) + 4) // 5
        cw, chh = 250, 110
        im = Image.new("RGB", (cols * cw, rowsn * chh), (18, 18, 22))
        dr = ImageDraw.Draw(im)
        for k, i in enumerate(chunk):
            cx, cy = (k % cols) * cw, (k // cols) * chh
            p = os.path.join(SRC, f"{i:03d}.wav")
            if not os.path.exists(p):
                continue
            a, sr, nch = load_wav(p)
            # 波形
            ww, wh = cw - 20, 34
            step = max(1, len(a) // ww)
            for x in range(ww):
                seg = a[x * step:(x + 1) * step]
                if len(seg) == 0:
                    continue
                lo, hi = float(seg.min()), float(seg.max())
                y0 = cy + 16 + wh / 2 - lo * wh / 2
                y1 = cy + 16 + wh / 2 - hi * wh / 2
                dr.line([cx + 10 + x, y0, cx + 10 + x, y1], fill=(120, 200, 255))
            # 频谱
            fl = 512
            nf2 = max(1, len(a) // fl)
            S = np.abs(np.fft.rfft(
                (a[: nf2 * fl].reshape(nf2, fl) * np.hanning(fl)).astype(np.float32), axis=1))
            S = 20 * np.log10(S + 1e-6)
            S = S[:, :200]
            S = (S - S.min()) / (np.ptp(S) + 1e-9) * 255
            spec = Image.fromarray(S.T[::-1].astype(np.uint8)).resize((ww, 40)).convert("RGB")
            spec = spec.point(lambda v: min(255, int(v * 1.15)))
            px = np.asarray(spec).copy()
            px[..., 0] = np.clip(px[..., 0] * 1.0 + 0, 0, 255)
            spec = Image.fromarray(px)
            im.paste(spec, (cx + 10, cy + 56))
            kind = kinds.get(i, "?")
            dr.text((cx + 10, cy + 2), f"{i:03d} [{kind}] {len(a)/sr:.2f}s", fill=(230, 230, 120), font=font)
        out = os.path.join(base, f"sheet_{ci//per}.png")
        im.save(out)
        print("wrote", out)


if __name__ == "__main__":
    what = sys.argv[1] if len(sys.argv) > 1 else "report"
    if what in ("report", "all"):
        cmd_report()
    if what in ("sheets", "all"):
        cmd_sheets()
