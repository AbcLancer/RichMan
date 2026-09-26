#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""音效深度分析 v2 —— 在 sfx_analyze 基础上加"乐音/语音/噪声"判别 + 家族聚类。

用法:
    python tools/sfx_cluster.py            # 打印特征表 + 聚类结果
    python tools/sfx_cluster.py sheets     # 渲染高对比度频谱接触表
    python tools/sfx_cluster.py mel        # 渲染梅尔式对数频谱表

设计动机：原版把 151 个音效的用途写死在 exe 代码里，数据层无表可查。
因此改用"声学测量 + 结构聚类"作为替代证据：
  * 包络调制率 4~8Hz  -> 说话/唱（音节率）
  * 调制率 1~3Hz      -> 音乐片段
  * 起音 <30ms + 宽带 -> 打击/爆炸
  * 基频稳定 + 谱平坦度低 -> 乐音/铃声
  * 相邻 id 之间特征相近的成组出现 -> 同族（角色/卡片/宠物）
"""
import os
import sys
import json
import math
import wave
import re

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = r"F:\游戏\Rich6\sound\effect"
DOCS = os.path.join(ROOT, "docs")


# ---------------------------------------------------------------- 读取
def read_kinds():
    kinds, order, groups = {}, [], []
    cur = []
    for line in open(os.path.join(SRC, "sndeffect.txt"), encoding="gbk", errors="replace"):
        s = line.strip()
        if s.startswith("//"):
            if cur:
                groups.append(cur)
                cur = []
            continue
        m = re.match(r"^(\d{3})\s+(2D|3D)$", s, re.I)
        if m:
            i = int(m.group(1))
            kinds[i] = m.group(2).upper()
            order.append(i)
            cur.append(i)
    if cur:
        groups.append(cur)
    return kinds, order, groups


def load_wav(path):
    with wave.open(path, "rb") as w:
        nch, sr, sw, n = w.getnchannels(), w.getframerate(), w.getsampwidth(), w.getnframes()
        raw = w.readframes(n)
    if sw == 2:
        a = np.frombuffer(raw, dtype="<i2").astype(np.float32) / 32768.0
    elif sw == 1:
        a = (np.frombuffer(raw, dtype=np.uint8).astype(np.float32) - 128) / 128
    elif sw == 4:
        a = np.frombuffer(raw, dtype="<i4").astype(np.float32) / 2147483648.0
    else:
        raise ValueError(sw)
    if nch > 1:
        a = a.reshape(-1, nch).mean(axis=1)
    return a, sr, nch


# ---------------------------------------------------------------- 特征
def frame_env(a, sr, win_ms=20, hop_ms=5):
    fl, hop = int(sr * win_ms / 1000), int(sr * hop_ms / 1000)
    fl, hop = max(fl, 32), max(hop, 8)
    if len(a) < fl:
        a = np.pad(a, (0, fl - len(a)))
    nf = 1 + (len(a) - fl) // hop
    idx = np.arange(fl)[None, :] + hop * np.arange(nf)[:, None]
    fr = a[idx]
    env = np.sqrt((fr.astype(np.float64) ** 2).mean(axis=1))
    return fr, env, sr / hop


def stft_feats(a, sr, fl=1024, hop=256):
    if len(a) < fl:
        a = np.pad(a, (0, fl - len(a)))
    nf = 1 + (len(a) - fl) // hop
    idx = np.arange(fl)[None, :] + hop * np.arange(nf)[:, None]
    fr = a[idx] * np.hanning(fl)
    S = np.abs(np.fft.rfft(fr, axis=1)) + 1e-10
    freqs = np.fft.rfftfreq(fl, 1.0 / sr)
    return S, freqs


def analyze(a, sr):
    dur = len(a) / sr
    if dur <= 0:
        return None
    peak = float(np.abs(a).max())
    rms = float(np.sqrt((a ** 2).mean()))
    fr, env, env_sr = frame_env(a, sr)
    e = env / (env.max() + 1e-20)

    # --- 起音时间：从能量首次 >5% 到达到 95% 峰值
    nz = np.where(e > 0.05)[0]
    pk = int(np.argmax(e))
    if len(nz) and pk > nz[0]:
        atk = (pk - nz[0]) / env_sr
    else:
        atk = pk / env_sr
    # --- 衰减：后半段/前半段能量比
    h = max(1, len(e) // 2)
    d1 = float((e[:h] ** 2).mean())
    d2 = float((e[h:] ** 2).mean())
    decay_db = 10 * math.log10((d2 + 1e-12) / (d1 + 1e-12))

    # --- 包络调制谱：找 1~10Hz 的峰值（音节/音符率）
    if len(e) >= 16:
        es = e - e.mean()
        n = 1 << int(np.ceil(np.log2(max(16, len(es)))))
        E = np.abs(np.fft.rfft(es, n))
        f = np.fft.rfftfreq(n, 1.0 / env_sr)
        band = (f >= 0.8) & (f <= 12)
        if band.any():
            mod_f = float(f[band][np.argmax(E[band])])
            mod_r = float(E[band].max() / (E[1:].mean() + 1e-12))
        else:
            mod_f, mod_r = 0.0, 0.0
    else:
        mod_f, mod_r = 0.0, 0.0

    # --- 谱特征
    S, freqs = stft_feats(a, sr)
    P = S ** 2
    tot = P.sum(1) + 1e-20
    cen = (P * freqs).sum(1) / tot
    flat = np.exp(np.log(S).mean(1)) / (S.mean(1) + 1e-20)
    cs = np.cumsum(P, 1)
    roll = np.array([freqs[min(len(freqs) - 1, int(np.searchsorted(cs[i], 0.85 * cs[i, -1])))]
                     for i in range(len(P))])
    flux = float(np.abs(np.diff(S, axis=0)).mean() / (S.mean() + 1e-12)) if len(S) > 1 else 0.0

    # --- 基频轨迹（自相关），判断乐音/语音
    f0s = []
    for i in range(0, len(S), max(1, len(S) // 40)):
        seg = a[i * 256: i * 256 + 2048]
        if len(seg) < 512:
            break
        seg = seg - seg.mean()
        if np.sqrt((seg ** 2).mean()) < 0.01:
            continue
        ac = np.correlate(seg, seg, "full")[len(seg) - 1:]
        ac /= (ac[0] + 1e-20)
        lo, hi = int(sr / 500), min(len(ac) - 1, int(sr / 60))
        if hi <= lo:
            continue
        k = lo + int(np.argmax(ac[lo:hi]))
        if ac[k] > 0.3:
            f0s.append(sr / k)
    f0_med = float(np.median(f0s)) if f0s else 0.0
    f0_std = float(np.std(12 * np.log2(np.array(f0s) / f0_med))) if len(f0s) > 3 and f0_med else 0.0

    zcr = float((np.diff(np.sign(a)) != 0).mean())
    return dict(
        dur=round(dur, 3), sr=int(sr), peak=round(peak, 3), rms=round(rms, 4),
        attack=round(atk, 3), decay_db=round(decay_db, 1),
        mod_f=round(mod_f, 2), mod_r=round(mod_r, 1),
        centroid=round(float(np.mean(cen)), 0), roll=round(float(np.mean(roll)), 0),
        flat=round(float(np.mean(flat)), 4), flux=round(flux, 3),
        f0=round(f0_med, 1), f0_std=round(f0_std, 2), zcr=round(zcr, 4),
        nframes=len(e),
    )


def classify(r):
    """把测量结果翻成可读的"音色族"，用于人工判定。"""
    tag = []
    if r["dur"] < 0.12:
        tag.append("瞬态")
    elif r["dur"] < 0.5:
        tag.append("短促")
    elif r["dur"] < 1.5:
        tag.append("中长")
    else:
        tag.append("长")

    speech = r["dur"] > 0.5 and 2.5 <= r["mod_f"] <= 8.0 and r["mod_r"] > 8 and r["f0"] > 0
    music = r["dur"] > 1.0 and r["mod_r"] > 6 and r["flat"] < 0.25 and r["f0_std"] < 1.2 and r["f0"] > 0
    if speech:
        tag.append("疑似人声")
    if music and not speech:
        tag.append("疑似乐句")
    if r["attack"] < 0.03:
        tag.append("硬起音")
    if r["decay_db"] < -8:
        tag.append("衰减型")
    if r["flat"] > 0.3 and r["zcr"] > 0.15:
        tag.append("宽带噪声")
    if r["flat"] < 0.12 and r["f0"] > 0:
        tag.append("乐音")
    if r["centroid"] > 3500:
        tag.append("高频脆")
    if r["centroid"] < 700:
        tag.append("低频厚")
    return "/".join(tag)


def gather():
    kinds, order, groups = read_kinds()
    out = []
    for i in order:
        p = os.path.join(SRC, f"{i:03d}.wav")
        if not os.path.exists(p):
            p = os.path.join(SRC, f"{i:03d}.WAV")
        a, sr, nch = load_wav(p)
        r = analyze(a, sr)
        r.update(id=i, kind=kinds[i], ch=nch, kb=round(os.path.getsize(p) / 1024, 1))
        r["tag"] = classify(r)
        out.append(r)
    return out, groups


FEATS = ["dur", "attack", "decay_db", "mod_f", "mod_r", "centroid", "roll",
         "flat", "flux", "f0_std", "zcr"]


def cmd_report():
    rows, groups = gather()
    json.dump({"rows": rows, "groups": groups},
              open(os.path.join(DOCS, "sfx-features.json"), "w", encoding="utf-8"),
              ensure_ascii=False, indent=1)
    hdr = (f"{'id':>4} {'kd':>3} {'dur':>6} {'atk':>5} {'dec':>6} {'modF':>5} {'modR':>6} "
           f"{'cent':>6} {'flat':>5} {'flux':>5} {'f0':>6} {'f0sd':>5}  tag")
    print(hdr)
    print("-" * 132)
    for r in rows:
        print(f"{r['id']:>4} {r['kind']:>3} {r['dur']:>6.2f} {r['attack']:>5.3f} {r['decay_db']:>6.1f} "
              f"{r['mod_f']:>5.1f} {r['mod_r']:>6.1f} {r['centroid']:>6.0f} {r['flat']:>5.3f} "
              f"{r['flux']:>5.2f} {r['f0']:>6.0f} {r['f0_std']:>5.2f}  {r['tag']}")

    # ---- 聚类：找"同类音家族"
    X = np.array([[r[f] for f in FEATS] for r in rows], dtype=np.float64)
    X = np.log1p(np.abs(X)) * np.sign(X)
    mu, sd = X.mean(0), X.std(0) + 1e-9
    Z = (X - mu) / sd
    try:
        from scipy.cluster.vq import kmeans2
        for k in (6, 10, 14):
            cen, lab = kmeans2(Z, k, minit="++", seed=7, iter=60)
            print(f"\n===== kmeans k={k} =====")
            for c in range(k):
                mem = [rows[i]["id"] for i in range(len(rows)) if lab[i] == c]
                if not mem:
                    continue
                kinds_c = {rows[i]["kind"] for i in range(len(rows)) if lab[i] == c}
                print(f"  C{c:>2} n={len(mem):>3} {'/'.join(sorted(kinds_c))}: {mem}")
    except Exception as ex:
        print("cluster skipped:", ex)
    return rows, groups


def cmd_sheets(per=20, cols=5):
    from PIL import Image, ImageDraw, ImageFont
    rows, groups = gather()
    base = os.path.join(ROOT, ".workbuddy", "sfx")
    os.makedirs(base, exist_ok=True)
    try:
        f9 = ImageFont.truetype("C:/Windows/Fonts/consola.ttf", 9)
    except Exception:
        f9 = ImageFont.load_default()
    ids = [r["id"] for r in rows]
    # 蓝→青→黄→白 色标
    ramp = np.zeros((256, 3), np.uint8)
    for i in range(256):
        t = i / 255.0
        ramp[i] = (np.clip(t * 3, 0, 1) * 255,
                   np.clip(t * 3 - 1, 0, 1) * 255,
                   np.clip(t * 3 - 2, 0, 1) * 255)
    for ci in range(0, len(ids), per):
        chunk = ids[ci:ci + per]
        rown = (len(chunk) + cols - 1) // cols
        cw, chh = 336, 168
        im = Image.new("RGB", (cols * cw, rown * chh), (12, 12, 16))
        dr = ImageDraw.Draw(im)
        for k, i in enumerate(chunk):
            cx, cy = (k % cols) * cw, (k // cols) * chh
            r = next(x for x in rows if x["id"] == i)
            p = os.path.join(SRC, f"{i:03d}.wav")
            if not os.path.exists(p):
                continue
            a, sr, nch = load_wav(p)
            # 波形
            ww, wh = cw - 16, 30
            step = max(1, len(a) // ww)
            for x in range(ww):
                seg = a[x * step:(x + 1) * step]
                if not len(seg):
                    continue
                lo, hi = float(seg.min()), float(seg.max())
                dr.line([cx + 8 + x, cy + 14 + wh / 2 - lo * wh / 2,
                         cx + 8 + x, cy + 14 + wh / 2 - hi * wh / 2], fill=(110, 190, 255))
            # 频谱（对数频率，改善低频可见度）
            S, freqs = stft_feats(a, sr, fl=512, hop=max(1, len(a) // (cw - 16)))
            db = 20 * np.log10(S.T + 1e-6)
            db -= db.max()
            db = np.clip((db + 70) / 70, 0, 1)
            nf_ = db.shape[0]
            # 取 40~12000Hz 的对数频段
            sel = (freqs >= 60) & (freqs <= 12000)
            idxs = np.linspace(0, sel.sum() - 1, 46).astype(int)
            sub = db[sel][idxs]
            img = ramp[(sub * 255).astype(np.uint8)][::-1]
            spec = Image.fromarray(img).resize((ww, 96), Image.BILINEAR)
            im.paste(spec, (cx + 8, cy + 52))
            dr.text((cx + 8, cy + 2), f"{i:03d} [{r['kind']}] {r['dur']:.2f}s {r['tag'][:44]}",
                    fill=(235, 225, 120), font=f9)
        out = os.path.join(base, f"spec_{ci // per}.png")
        im.save(out)
        print("wrote", out)


if __name__ == "__main__":
    what = sys.argv[1] if len(sys.argv) > 1 else "report"
    if what in ("report", "all"):
        cmd_report()
    if what in ("sheets", "mel", "all"):
        cmd_sheets()
