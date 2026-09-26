# -*- coding: utf-8 -*-
"""
原版《大富翁6》运行控制器 —— 用于在沙箱内启动原版、抓取画面参考、发送按键导航。

子命令：
    start              启动 F:\\游戏\\Rich6run\\rich6.exe（若未运行）
    wait [秒]          轮询等待游戏窗口出现（默认 20 秒）
    shot <名称>        截图游戏窗口 -> docs/screenshots/orig/<名称>.png
    fullshot <名称>    截图整个虚拟桌面
    key <KEY>          向游戏窗口发送一次按键
    keys <KEY,KEY,..>  依次发送多个按键（每个间隔 0.6s）
    click <x> <y>      在游戏窗口客户区相对坐标处点击
    log                输出 F:\\游戏\\Rich6run\\r6log.txt
    kill               结束游戏进程

KEY 取值：ENTER ESC SPACE UP DOWN LEFT RIGHT TAB 或单字符 A-Z 0-9
"""
import ctypes
import os
import subprocess
import sys
import time

import win32api
import win32con
import win32gui
import win32process
from PIL import ImageGrab

EXE = r"F:\游戏\Rich6run\rich6.exe"
CWD = r"F:\游戏\Rich6run"
OUTDIR = r"D:\Projects\RichMan\docs\screenshots\orig"

# 让本进程成为 per-monitor DPI aware，保证 GetWindowRect 与抓屏像素一致
try:
    ctypes.windll.shcore.SetProcessDpiAwareness(2)
except Exception:
    try:
        ctypes.windll.user32.SetProcessDPIAware()
    except Exception:
        pass

VK = {
    "ENTER": 0x0D, "ESC": 0x1B, "SPACE": 0x20, "TAB": 0x09,
    "UP": 0x26, "DOWN": 0x28, "LEFT": 0x25, "RIGHT": 0x27,
    "BACKSPACE": 0x08, "RETURN": 0x0D, "PAUSE": 0x13,
}
for c in "ABCDEFGHIJKLMNOPQRSTUVWXYZ":
    VK[c] = ord(c)
for c in "0123456789":
    VK[c] = ord(c)


def find_game_window():
    """返回 (hwnd, pid)。按进程名匹配，找到有标题的可见顶层窗口。"""
    target = os.path.basename(EXE).lower()
    hits = []

    def cb(h, _):
        if not win32gui.IsWindowVisible(h):
            return True
        _, pid = win32process.GetWindowThreadProcessId(h)
        try:
            hproc = win32api.OpenProcess(0x1000, False, pid)  # QUERY_LIMITED_INFORMATION
            path = win32process.GetModuleFileNameEx(hproc, 0)
            win32api.CloseHandle(hproc)
        except Exception:
            return True
        if os.path.basename(path).lower() == target:
            hits.append((h, pid, win32gui.GetWindowRect(h), win32gui.GetWindowText(h)))
        return True

    win32gui.EnumWindows(cb, None)
    return hits


def running_pids():
    r = subprocess.run(
        ["tasklist", "/FI", "IMAGENAME eq rich6.exe", "/FO", "CSV", "/NH"],
        capture_output=True,
    )
    txt = r.stdout.decode("gbk", "replace")
    pids = []
    for line in txt.splitlines():
        parts = [p.strip('"') for p in line.split('","')]
        if len(parts) >= 2 and parts[0].lower() == "rich6.exe":
            try:
                pids.append(int(parts[1]))
            except ValueError:
                pass
    return pids


def cmd_start():
    if running_pids():
        print("已在运行:", running_pids())
        return
    p = subprocess.Popen(
        [EXE],
        cwd=CWD,
        close_fds=True,
        creationflags=subprocess.DETACHED_PROCESS | subprocess.CREATE_NEW_PROCESS_GROUP,
    )
    print("已启动 rich6.exe pid=", p.pid)


def cmd_wait(sec=20.0):
    t0 = time.time()
    while time.time() - t0 < sec:
        hits = find_game_window()
        if hits:
            for h, pid, rect, title in hits:
                print(f"窗口出现 hwnd={h} pid={pid} rect={rect} title={title!r}")
            return
        time.sleep(0.5)
    print("超时未见游戏窗口；进程:", running_pids())


def _focus(hwnd):
    try:
        if win32gui.IsIconic(hwnd):
            win32gui.ShowWindow(hwnd, win32con.SW_RESTORE)
        win32gui.SetForegroundWindow(hwnd)
    except Exception as e:
        print("  置前失败(可忽略):", e)
    time.sleep(0.25)


def _game_rect():
    hits = find_game_window()
    if not hits:
        return None
    # 取面积最大的那个（排除幽灵小窗口）
    hits.sort(key=lambda t: (t[2][2] - t[2][0]) * (t[2][3] - t[2][1]), reverse=True)
    return hits[0]


def cmd_shot(name, full=False):
    os.makedirs(OUTDIR, exist_ok=True)
    path = os.path.join(OUTDIR, name + ".png")
    if full:
        img = ImageGrab.grab(all_screens=True)
    else:
        hit = _game_rect()
        if not hit:
            print("找不到游戏窗口，改为全屏截图")
            img = ImageGrab.grab(all_screens=True)
        else:
            h, pid, rect, title = hit
            _focus(h)
            l, t, r, b = rect
            img = ImageGrab.grab(bbox=(l, t, r, b), all_screens=True)
    img.save(path)
    print(f"已保存 {path}  尺寸={img.size}")


def cmd_key(name):
    hit = _game_rect()
    if not hit:
        print("找不到游戏窗口")
        return
    h = hit[0]
    _focus(h)
    vk = VK.get(name.upper())
    if vk is None:
        print("未知按键:", name)
        return
    win32api.keybd_event(vk, 0, 0, 0)
    time.sleep(0.06)
    win32api.keybd_event(vk, 0, win32con.KEYEVENTF_KEYUP, 0)
    print("已发送", name.upper())


def cmd_click(x, y):
    hit = _game_rect()
    if not hit:
        print("找不到游戏窗口")
        return
    h, pid, rect, title = hit
    _focus(h)
    l, t = rect[0], rect[1]
    win32api.SetCursorPos((l + int(x), t + int(y)))
    time.sleep(0.15)
    win32api.mouse_event(win32con.MOUSEEVENTF_LEFTDOWN, 0, 0, 0, 0)
    time.sleep(0.08)
    win32api.mouse_event(win32con.MOUSEEVENTF_LEFTUP, 0, 0, 0, 0)
    print(f"已点击 ({x},{y})  窗口左上角=({l},{t})")


def cmd_log():
    p = os.path.join(CWD, "r6log.txt")
    if not os.path.exists(p):
        print("(无 r6log.txt)")
        return
    with open(p, "rb") as f:
        print(f.read().decode("gbk", "replace"))


def cmd_kill():
    r = subprocess.run(["taskkill", "/F", "/IM", "rich6.exe"], capture_output=True)
    print(r.stdout.decode("gbk", "replace").strip() or r.stderr.decode("gbk", "replace").strip())


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 1
    c = sys.argv[1]
    if c == "start":
        cmd_start()
    elif c == "wait":
        cmd_wait(float(sys.argv[2]) if len(sys.argv) > 2 else 20.0)
    elif c == "shot":
        cmd_shot(sys.argv[2])
    elif c == "fullshot":
        cmd_shot(sys.argv[2], full=True)
    elif c == "key":
        cmd_key(sys.argv[2])
    elif c == "keys":
        for k in sys.argv[2].split(","):
            cmd_key(k.strip())
            time.sleep(0.6)
    elif c == "click":
        cmd_click(sys.argv[2], sys.argv[3])
    elif c == "log":
        cmd_log()
    elif c == "kill":
        cmd_kill()
    else:
        print("未知子命令:", c)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
