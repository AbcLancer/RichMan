#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""遍历「選地圖」里 7 张地图，逐个进对局并停留，配合一次性录音读出每张图的 BGM。

前提：已用 tools/make_bgm_probe.py 造出 BGM 标记副本（BGM 换成 420…1100Hz 长纯音）。
本脚本只负责**点击导航 + 打时间戳**，录音请另开一条命令（先起录音、再跑本脚本）。

用法：
    python tools/r6_audio_probe.py record .workbuddy/sfx/bgm_sweep.wav 420 &
    python tools/bgm_map_sweep.py
然后：
    python tools/r6_audio_probe.py align .workbuddy/sfx/bgm_sweep.wav
    python tools/bgm_identify_timeline.py .workbuddy/sfx/bgm_sweep.wav
"""
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import r6_drive as D          # noqa: E402
import probe_act as A         # noqa: E402
import r6_audio_probe as P    # noqa: E402

EXE = os.environ.get("R6_EXE", r"F:\游戏\Rich6bgm\rich6.exe")
CWD = os.environ.get("R6_CWD", r"F:\游戏\Rich6bgm")

# 「選地圖」六角格中心（**1200×900 窗口坐标**，已在实机校准）
MAPS = [
    ("aiji",   "埃及",   300, 294),
    ("island", "未来",   544, 272),
    ("paris",  "法国",   178, 472),
    ("space",  "太空",   428, 483),
    ("train",  "美国",   656, 478),
    ("japan",  "日本",   322, 667),
    ("china",  "中国",   511, 667),
]

MENU_SOLO = (262, 588)
SUB_NEW = (350, 470)
MAP_OK = (1030, 700)
START = (331, 820)

BOARD_WAIT = 26          # 到棋盘后停留（读 BGM）


def wait_window(timeout=60.0):
    t0 = time.time()
    while time.time() - t0 < timeout:
        if D.find_window():
            return True
        time.sleep(1.0)
    return False


def click(x, y, wait=1.6):
    hits = D.find_window()
    if not hits:
        return False
    h = hits[0][0]
    ox, oy = hits[0][2][0], hits[0][2][1]
    D.force_foreground(h)
    time.sleep(0.25)
    D._do_click(x + ox, y + oy)
    time.sleep(wait)
    return True


def main():
    only = sys.argv[1:] if len(sys.argv) > 1 else None
    for key, cn, hx, hy in MAPS:
        if only and key not in only:
            continue
        P.cmd_kill()
        time.sleep(1.5)
        P.cmd_launch(CWD)
        if not wait_window():
            A.log(f"MAP {key} 窗口超时，跳过")
            continue
        time.sleep(7.0)                      # 等主菜单
        A.log(f"MAP {key} LAUNCH {cn}")
        click(*MENU_SOLO)
        click(*SUB_NEW)
        click(hx, hy)                        # 点六角格选图
        A.log(f"MAP {key} PICK {cn} @{hx},{hy}")
        click(*MAP_OK)
        click(*START, wait=3.0)
        A.log(f"MAP {key} BOARD_AT {cn}")
        time.sleep(BOARD_WAIT)
        A.log(f"MAP {key} DONE {cn}")
        # 留一小段间隙，避免切歌边界打架
        time.sleep(3.0)
    P.cmd_kill()
    A.log("SWEEP END")
    return 0


if __name__ == "__main__":
    sys.exit(main())
