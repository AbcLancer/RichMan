#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""实证会话操作助手 —— 从 stdin 读动作脚本，逐步驱动原版并记录时间戳。

动作脚本每行一条：
    M x y            光标移到窗口内 (x,y)
    H x y [秒]       悬停（默认 1.2s）
    C x y [dx dy]    点击
    S 名称           截图到 .workbuddy/sfx/shots/<名称>.png
    W 秒             等待
    K 按键           发按键（ENTER/ESC/SPACE/...）
    L 说明           仅往 actions.log 写一条带时间戳的说明
每行都会以 UTC 时间戳写入 .workbuddy/sfx/actions.log，供与录音对齐。
"""
import io
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import r6_drive as D  # noqa: E402  复用其中的窗口查找/输入/截图原语

LOG = os.path.join(r"D:\Projects\RichMan", ".workbuddy", "sfx", "actions.log")


def log(msg):
    t = time.time()
    # UTC hh:mm:ss.mmm
    s = time.strftime("%H:%M:%S", time.gmtime(t)) + f".{int((t % 1) * 1000):03d}"
    with open(LOG, "a", encoding="utf-8") as f:
        f.write(f"[{s}] {msg}\n")
    print(f"[{s}] {msg}", flush=True)


def main():
    os.makedirs(D.OUTDIR, exist_ok=True)
    hits = D.find_window()
    if not hits:
        print("!! 找不到游戏窗口")
        return 1
    h, pid, rect = hits[0]
    ox, oy = rect[0], rect[1]
    print(f"窗口 rect={rect} 原点=({ox},{oy})", flush=True)
    D.force_foreground(h)
    for raw in sys.stdin.read().splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        p = line.split()
        c = p[0].upper()
        if c == "L":
            log(" ".join(p[1:]))
        elif c == "M":
            x, y = int(p[1]) + ox, int(p[2]) + oy
            D.win32api.SetCursorPos((x, y))
            D.win32api.mouse_event(D.win32con.MOUSEEVENTF_MOVE, 1, 1, 0, 0)
            D.win32api.mouse_event(D.win32con.MOUSEEVENTF_MOVE, -1, -1, 0, 0)
            log(f"MOVE {p[1]},{p[2]}")
            time.sleep(0.25)
        elif c == "H":
            secs = float(p[3]) if len(p) > 3 else 1.2
            x, y = int(p[1]) + ox, int(p[2]) + oy
            D.win32api.SetCursorPos((x, y))
            D.win32api.mouse_event(D.win32con.MOUSEEVENTF_MOVE, 1, 1, 0, 0)
            D.win32api.mouse_event(D.win32con.MOUSEEVENTF_MOVE, -1, -1, 0, 0)
            log(f"HOVER {p[1]},{p[2]} {secs}s")
            time.sleep(secs)
        elif c == "C":
            x = int(p[1]) + ox
            y = int(p[2]) + oy
            before = D.grab(h)
            D._do_click(x, y)
            log(f"CLICK {p[1]},{p[2]}")
            time.sleep(1.8)
            after = D.grab(h)
            print(f"   帧变化={D.diff(before, after):.2f}", flush=True)
        elif c == "S":
            time.sleep(0.4)
            path = os.path.join(D.OUTDIR, p[1] + ".png")
            D.grab(h).save(path)
            log(f"SHOT {p[1]}")
        elif c == "W":
            log(f"WAIT {p[1]}s")
            time.sleep(float(p[1]))
        elif c == "K":
            D.cmd_key(p[1])
            log(f"KEY {p[1]}")
            time.sleep(0.8)
        else:
            print("未知动作:", line)
    return 0


if __name__ == "__main__":
    sys.exit(main())
