# -*- coding: utf-8 -*-
"""
原版《大富翁6》脚本化会话：一次调用内启动 → 按时间轴发键/截图 → 收尾。
原因：跨工具调用进程会被回收，所以整段会话必须在同一次进程生命周期内完成。

时间轴文件：tools/r6_steps.txt
每行格式： <等待秒数> <动作>[:<参数>]
动作：
    start            启动游戏
    shot:<名称>      截图游戏窗口 -> docs/screenshots/orig/<名称>.png
    fullshot:<名称>  截图整个虚拟桌面
    key:<KEY>        发送一次按键
    keys:<K,K,..>    依次发送按键（间隔 0.6s）
    click:<x>,<y>    在游戏窗口内相对坐标点击
    log              打印 r6log.txt
    end              结束游戏进程并退出
'#' 开头为注释；空行忽略。
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
import numpy as np
from PIL import ImageGrab

EXE = r"F:\游戏\Rich6run\rich6.exe"
CWD = r"F:\游戏\Rich6run"
OUTDIR = r"D:\Projects\RichMan\docs\screenshots\orig"
STEPS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "r6_steps.txt")

try:
    ctypes.windll.shcore.SetProcessDpiAwareness(2)
except Exception:
    pass

VK = {
    "ENTER": 0x0D, "ESC": 0x1B, "SPACE": 0x20, "TAB": 0x09,
    "UP": 0x26, "DOWN": 0x28, "LEFT": 0x25, "RIGHT": 0x27,
    "BACKSPACE": 0x08, "PAUSE": 0x13,
}
for c in "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789":
    VK[c] = ord(c)


def find_game_window():
    target = os.path.basename(EXE).lower()
    hits = []

    def cb(h, _):
        if not win32gui.IsWindowVisible(h):
            return True
        _, pid = win32process.GetWindowThreadProcessId(h)
        try:
            hp = win32api.OpenProcess(0x1000, False, pid)
            path = win32process.GetModuleFileNameEx(hp, 0)
            win32api.CloseHandle(hp)
        except Exception:
            return True
        if os.path.basename(path).lower() == target:
            hits.append((h, pid, win32gui.GetWindowRect(h), win32gui.GetWindowText(h)))
        return True

    win32gui.EnumWindows(cb, None)
    hits.sort(key=lambda t: (t[2][2] - t[2][0]) * (t[2][3] - t[2][1]), reverse=True)
    return hits


def game_rect(wait=25.0):
    t0 = time.time()
    while time.time() - t0 < wait:
        hits = find_game_window()
        if hits:
            return hits[0]
        time.sleep(0.5)
    return None


def focus(hwnd):
    try:
        if win32gui.IsIconic(hwnd):
            win32gui.ShowWindow(hwnd, win32con.SW_RESTORE)
            time.sleep(0.3)
        win32gui.SetForegroundWindow(hwnd)
    except Exception as e:
        print("   置前失败:", e)
    time.sleep(0.25)


def act_start():
    p = subprocess.Popen([EXE], cwd=CWD)
    print(f"   启动 rich6.exe pid={p.pid}")
    return p


def act_shot(name, full=False):
    os.makedirs(OUTDIR, exist_ok=True)
    path = os.path.join(OUTDIR, name + ".png")
    if full:
        img = ImageGrab.grab(all_screens=True)
    else:
        hit = find_game_window()
        if not hit:
            print("   !! 未找到窗口，改抓全屏")
            img = ImageGrab.grab(all_screens=True)
        else:
            h, pid, rect, title = hit[0]
            focus(h)
            img = ImageGrab.grab(bbox=rect, all_screens=True)
    img.save(path)
    print(f"   截图 {name}.png {img.size}")


def act_key(name):
    hit = find_game_window()
    if not hit:
        print("   !! 无窗口")
        return
    focus(hit[0][0])
    vk = VK.get(name.upper())
    if vk is None:
        print("   !! 未知键", name)
        return
    win32api.keybd_event(vk, 0, 0, 0)
    time.sleep(0.07)
    win32api.keybd_event(vk, 0, win32con.KEYEVENTF_KEYUP, 0)
    print("   按键", name.upper())


def _grab(hit):
    if hit:
        return ImageGrab.grab(bbox=hit[2], all_screens=True)
    return ImageGrab.grab(all_screens=True)


def _frame_diff(a, b):
    if a is None or b is None or a.size != b.size:
        return -1.0
    aa = np.asarray(a.convert("L"), dtype=np.int16)
    bb = np.asarray(b.convert("L"), dtype=np.int16)
    return float(np.abs(aa - bb).mean())


def _sendinput_click(tx, ty):
    """用 SendInput 以绝对归一化坐标注入一次完整的左键点击。"""
    import ctypes
    from ctypes import wintypes

    sw = ctypes.windll.user32.GetSystemMetrics(0)
    sh = ctypes.windll.user32.GetSystemMetrics(1)

    class MOUSEINPUT(ctypes.Structure):
        _fields_ = [("dx", wintypes.LONG), ("dy", wintypes.LONG),
                    ("mouseData", wintypes.DWORD), ("dwFlags", wintypes.DWORD),
                    ("time", wintypes.DWORD), ("dwExtraInfo", ctypes.POINTER(wintypes.ULONG))]

    class _INPUTunion(ctypes.Union):
        _fields_ = [("mi", MOUSEINPUT)]

    class INPUT(ctypes.Structure):
        _fields_ = [("type", wintypes.DWORD), ("u", _INPUTunion)]

    nx = int(tx * 65535 / (sw - 1))
    ny = int(ty * 65535 / (sh - 1))
    MOVE, DOWN, UP, ABS = 0x0001, 0x0002, 0x0004, 0x8000
    seq = [
        INPUT(0, _INPUTunion(mi=MOUSEINPUT(nx, ny, 0, MOVE | ABS, 0, None))),
        INPUT(0, _INPUTunion(mi=MOUSEINPUT(0, 0, 0, DOWN, 0, None))),
    ]
    ctypes.windll.user32.SendInput(2, ctypes.byref(seq[0]), ctypes.sizeof(INPUT))
    time.sleep(0.12)
    seq2 = [INPUT(0, _INPUTunion(mi=MOUSEINPUT(0, 0, 0, UP, 0, None)))]
    ctypes.windll.user32.SendInput(1, ctypes.byref(seq2[0]), ctypes.sizeof(INPUT))


def act_click(xy, variant="p"):
    parts = [p.strip() for p in xy.split(",") if p.strip()]
    detect = "c" in parts
    parts = [p for p in parts if p != "c"]
    x, y = int(parts[0]), int(parts[1])
    variant = parts[2] if len(parts) > 2 else variant
    hit = find_game_window()
    if not hit:
        print("   !! 无窗口")
        return
    h, pid, rect, title = hit[0]
    focus(h)
    tx, ty = rect[0] + x, rect[1] + y

    before = _grab(hit[0]) if detect else None
    v = variant

    if v in ("p", "m", "l", "d"):
        win32api.SetCursorPos((tx, ty))
        time.sleep(0.20)
        win32api.mouse_event(win32con.MOUSEEVENTF_MOVE, 1, 1, 0, 0)
        win32api.mouse_event(win32con.MOUSEEVENTF_MOVE, -1, -1, 0, 0)
        time.sleep(0.25)
        reps = 2 if v == "d" else 1
        for _ in range(reps):
            win32api.mouse_event(win32con.MOUSEEVENTF_LEFTDOWN, 0, 0, 0, 0)
            if v == "l":
                time.sleep(0.45)
            elif v == "m":
                for _ in range(3):
                    win32api.mouse_event(win32con.MOUSEEVENTF_MOVE, 1, 0, 0, 0)
                    time.sleep(0.04)
                win32api.mouse_event(win32con.MOUSEEVENTF_MOVE, -3, 0, 0, 0)
            else:
                time.sleep(0.12)
            win32api.mouse_event(win32con.MOUSEEVENTF_LEFTUP, 0, 0, 0, 0)
            if reps == 2:
                time.sleep(0.07)
    elif v == "s":
        _sendinput_click(tx, ty)
    else:
        print("   !! 未知点击变体", variant)
        return

    print(f"   点击[{variant}] ({x},{y}) origin=({rect[0]},{rect[1]})")
    if before is not None:
        time.sleep(1.6)
        after = _grab(find_game_window()[0] if find_game_window() else None)
        print(f"      -> 帧变化={_frame_diff(before, after):.2f}"
              f"{'  ★画面已变化' if _frame_diff(before, after) > 0.5 else '  (无变化)'}")


def act_move(xy):
    x, y = (int(v) for v in xy.split(","))
    hit = find_game_window()
    if not hit:
        print("   !! 无窗口")
        return
    h, pid, rect, title = hit[0]
    focus(h)
    win32api.SetCursorPos((rect[0] + x, rect[1] + y))
    time.sleep(0.2)
    win32api.mouse_event(win32con.MOUSEEVENTF_MOVE, 1, 1, 0, 0)
    win32api.mouse_event(win32con.MOUSEEVENTF_MOVE, -1, -1, 0, 0)
    time.sleep(0.35)
    print(f"   移动 ({x},{y})")


def act_info():
    hit = find_game_window()
    if not hit:
        print("   !! 无窗口")
        return
    for h, pid, rect, title in hit:
        cr = win32gui.GetClientRect(h)
        o = win32gui.ClientToScreen(h, (0, 0))
        print(f"   hwnd={h} pid={pid} title={title!r}")
        print(f"   window rect={rect}  {rect[2]-rect[0]}x{rect[3]-rect[1]}")
        print(f"   client rect={cr} {cr[2]}x{cr[3]}  client origin(screen)={o}")


def act_log():
    p = os.path.join(CWD, "r6log.txt")
    if not os.path.exists(p):
        print("   (无日志)")
        return
    with open(p, "rb") as f:
        print("---- r6log.txt ----")
        print(f.read().decode("gbk", "replace"))
        print("-------------------")


def main():
    steps = []
    with open(STEPS, encoding="utf-8") as f:
        for ln in f:
            s = ln.strip()
            if not s or s.startswith("#"):
                continue
            parts = s.split(None, 1)
            # 前导数字可选：写了就是等待秒数，没写则立即执行
            try:
                delay = float(parts[0])
                action = parts[1].strip() if len(parts) > 1 else ""
            except ValueError:
                delay = 0.0
                action = s
            steps.append((delay, action))

    proc = None
    t0 = time.time()
    for delay, action in steps:
        if delay > 0:
            time.sleep(delay)
        print(f"[t={time.time()-t0:5.1f}s] {action}")
        if action == "start":
            proc = act_start()
        elif action.startswith("shot:"):
            act_shot(action[5:])
        elif action.startswith("fullshot:"):
            act_shot(action[9:], full=True)
        elif action.startswith("key:"):
            act_key(action[4:])
        elif action.startswith("keys:"):
            for k in action[5:].split(","):
                act_key(k.strip())
                time.sleep(0.6)
        elif action.startswith("click:"):
            act_click(action[6:])
        elif action.startswith("move:"):
            act_move(action[5:])
        elif action == "info":
            act_info()
        elif action == "log":
            act_log()
        elif action == "end":
            subprocess.run(["taskkill", "/F", "/IM", "rich6.exe"], capture_output=True)
            print("   已结束游戏")
        else:
            print("   !! 未知动作", action)

    if proc is not None and proc.poll() is None:
        subprocess.run(["taskkill", "/F", "/IM", "rich6.exe"], capture_output=True)
        print("会话结束，已清理进程")
    return 0


if __name__ == "__main__":
    sys.exit(main())
