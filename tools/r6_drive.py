# -*- coding: utf-8 -*-
"""
原版《大富翁6》交互式驱动器 —— 游戏保持常开，通过子命令一步步操作。

子命令：
    keepalive [分钟]        启动游戏并保活（建议用后台方式运行；默认 30 分钟）
    info                    打印窗口/客户区/DPI 等坐标信息
    shot <名称>             截图游戏窗口 -> docs/screenshots/orig/<名称>.png
    fullshot <名称>         截图整个虚拟桌面
    click <x> <y> [偏移]    点击窗口内坐标（偏移默认取 OFFSET_DEFAULT）
    sweep <x> <y>           在 (x,y) 右侧扫描 dx，找第一个能让画面变化的偏移
    move <x> <y>            仅移动光标
    key <KEY>               发送按键
    log                     输出 F:\\游戏\\Rich6run\\r6log.txt
    close                   显式结束游戏进程

坐标模型（实测修正）：原版自绘光标的「热点」并不落在 SetCursorPos 指定点上，
需要整体右移一段距离（OFFSET_DEFAULT）。sweep 可实测出精确值。
"""
import ctypes
import os
import subprocess
import sys
import time

import numpy as np
import win32api
import win32con
import win32gui
import win32process
from PIL import ImageGrab

EXE = os.environ.get("R6_EXE", r"F:\游戏\Rich6run\rich6.exe")
CWD = os.environ.get("R6_CWD", r"F:\游戏\Rich6run")
OUTDIR = os.environ.get("R6_OUTDIR", r"D:\Projects\RichMan\docs\screenshots\orig")

# 实测得到的点击偏移：请求坐标 + 该偏移 = 游戏真正认定的光标位置
OFFSET_DEFAULT = (0, 0)

try:
    ctypes.windll.shcore.SetProcessDpiAwareness(2)
except Exception:
    pass

VK = {
    "ENTER": 0x0D, "ESC": 0x1B, "SPACE": 0x20, "TAB": 0x09,
    "UP": 0x26, "DOWN": 0x28, "LEFT": 0x25, "RIGHT": 0x27,
    "BACKSPACE": 0x08, "PAUSE": 0x13,
}
for _c in "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789":
    VK[_c] = ord(_c)


# ---------------------------------------------------------------- 窗口

def find_window():
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
            hits.append((h, pid, win32gui.GetWindowRect(h)))
        return True

    win32gui.EnumWindows(cb, None)
    hits.sort(key=lambda t: (t[2][2] - t[2][0]) * (t[2][3] - t[2][1]), reverse=True)
    return hits


def pids_of(exe="rich6.exe"):
    r = subprocess.run(["tasklist", "/FI", f"IMAGENAME eq {exe}", "/FO", "CSV", "/NH"],
                       capture_output=True)
    out = []
    for line in r.stdout.decode("gbk", "replace").splitlines():
        p = [q.strip('"') for q in line.split('","')]
        if len(p) >= 2 and p[0].lower() == exe:
            try:
                out.append(int(p[1]))
            except ValueError:
                pass
    return out


def force_foreground(hwnd):
    """尽最大努力把窗口置前并提到最顶层。

    注意：本机主屏上有 NVIDIA GeForce Overlay（class = CEF-OSC-WIDGET，占据
    0,0-2559,1440），它可能截走鼠标按键消息（光标位置仍靠 GetCursorPos 轮询，
    所以悬停正常但点击丢失）。用 TOPMOST 把游戏提到覆盖层之上。
    """
    try:
        win32gui.SetWindowPos(hwnd, win32con.HWND_TOPMOST, 0, 0, 0, 0,
                              win32con.SWP_NOMOVE | win32con.SWP_NOSIZE |
                              win32con.SWP_SHOWWINDOW | win32con.SWP_NOACTIVATE)
    except Exception as e:
        print("   置顶失败:", e)
    if win32gui.GetForegroundWindow() == hwnd:
        return True
    for attempt in range(3):
        try:
            if attempt == 1:
                # 先按一下 ALT：解除 Windows 对 SetForegroundWindow 的调用方限制
                win32api.keybd_event(0x12, 0, 0, 0)
                win32api.keybd_event(0x12, 0, win32con.KEYEVENTF_KEYUP, 0)
            if attempt == 2:
                win32gui.ShowWindow(hwnd, win32con.SW_MINIMIZE)
                time.sleep(0.25)
                win32gui.ShowWindow(hwnd, win32con.SW_RESTORE)
            win32gui.SetForegroundWindow(hwnd)
        except Exception as e:
            print("   置前尝试", attempt, "异常:", e)
        time.sleep(0.3)
        if win32gui.GetForegroundWindow() == hwnd:
            return True
    return False


def grab(hwnd=None):
    if hwnd:
        return ImageGrab.grab(bbox=win32gui.GetWindowRect(hwnd), all_screens=True)
    hits = find_window()
    if hits:
        return ImageGrab.grab(bbox=hits[0][2], all_screens=True)
    return ImageGrab.grab(all_screens=True)


def diff(a, b):
    if a is None or b is None or a.size != b.size:
        return -1.0
    x = np.asarray(a.convert("L"), dtype=np.int16)
    y = np.asarray(b.convert("L"), dtype=np.int16)
    return float(np.abs(x - y).mean())


# ---------------------------------------------------------------- 输入

def _do_click(tx, ty, hold=0.12):
    win32api.SetCursorPos((tx, ty))
    time.sleep(0.18)
    win32api.mouse_event(win32con.MOUSEEVENTF_MOVE, 1, 1, 0, 0)
    win32api.mouse_event(win32con.MOUSEEVENTF_MOVE, -1, -1, 0, 0)
    time.sleep(0.22)
    win32api.mouse_event(win32con.MOUSEEVENTF_LEFTDOWN, 0, 0, 0, 0)
    time.sleep(hold)
    win32api.mouse_event(win32con.MOUSEEVENTF_LEFTUP, 0, 0, 0, 0)


def cmd_click_retry(x, y, max_try=10):
    """反复尝试点击同一目标直到画面变化。

    固定命中偏移（否则光标精灵自身位移会污染差分），只更换交互方式：
    先悬停再按 / 长按 / 双击 / 分步逼近 / 按住拖动 / 连击。
    """
    hits = find_window()
    if not hits:
        print("!! 找不到游戏窗口")
        return False
    h, pid, rect = hits[0]
    force_foreground(h)
    DX = 40
    tx, ty = rect[0] + int(x) + DX, rect[1] + int(y)

    def press(hold=0.15, jiggle=False):
        win32api.mouse_event(win32con.MOUSEEVENTF_LEFTDOWN, 0, 0, 0, 0)
        if jiggle:
            for _ in range(4):
                win32api.mouse_event(win32con.MOUSEEVENTF_MOVE, 1, 0, 0, 0)
                time.sleep(0.03)
            win32api.mouse_event(win32con.MOUSEEVENTF_MOVE, -4, 0, 0, 0)
        else:
            time.sleep(hold)
        win32api.mouse_event(win32con.MOUSEEVENTF_LEFTUP, 0, 0, 0, 0)

    plans = [
        ("悬停0.8s后按", lambda: (_hover(tx, ty, 0.8), press(0.15))),
        ("悬停1.2s长按0.5s", lambda: (_hover(tx, ty, 1.2), press(0.5))),
        ("双击", lambda: (_hover(tx, ty, 0.6), press(0.12), time.sleep(0.08), press(0.12))),
        ("分步逼近后按", lambda: (_approach(tx, ty), _hover(tx, ty, 0.9), press(0.2))),
        ("按住横向抖动", lambda: (_hover(tx, ty, 0.6), press(0, jiggle=True))),
        ("三连击", lambda: (_hover(tx, ty, 0.5),
                            [ (press(0.08), time.sleep(0.06)) for _ in range(3) ])),
        ("悬停2s后按", lambda: (_hover(tx, ty, 2.0), press(0.2))),
        ("先移开再回来按", lambda: (win32api.SetCursorPos((tx + 200, ty)),
                                    time.sleep(0.5), _hover(tx, ty, 0.5), press(0.15))),
    ]
    for i in range(min(max_try, len(plans))):
        name, fn = plans[i]
        before = grab(h)
        fn()
        time.sleep(1.7)
        after = grab(h)
        d = diff(before, after)
        print(f"  第{i+1}次 [{name}] 帧变化={d:6.2f} {'★画面已变化' if d > 0.5 else ''}")
        if d > 0.5:
            return True
    print("  重试完毕，画面始终未变化")
    return False


def _hover(tx, ty, secs):
    win32api.SetCursorPos((tx, ty))
    win32api.mouse_event(win32con.MOUSEEVENTF_MOVE, 1, 1, 0, 0)
    win32api.mouse_event(win32con.MOUSEEVENTF_MOVE, -1, -1, 0, 0)
    time.sleep(secs)


def _approach(tx, ty, steps=6):
    cur = win32api.GetCursorPos()
    for i in range(1, steps + 1):
        nx = cur[0] + (tx - cur[0]) * i // steps
        ny = cur[1] + (ty - cur[1]) * i // steps
        win32api.SetCursorPos((nx, ny))
        time.sleep(0.05)


def cmd_scan(x0, x1, y, step=10, dx=0):
    """在给定 y 上横扫 x，逐点点击并报告哪些 x 能触发画面变化。"""
    hits = find_window()
    if not hits:
        print("!! 找不到游戏窗口")
        return
    h, pid, rect = hits[0]
    force_foreground(h)
    print(f"横扫 x={x0}..{x1} step={step} y={y} dx={dx}  (窗口origin={rect[:2]})")
    for x in range(int(x0), int(x1) + 1, int(step)):
        before = grab(h)
        _do_click(rect[0] + x + int(dx), rect[1] + int(y))
        time.sleep(1.5)
        d = diff(before, grab(h))
        print(f"  x={x:5d} (实际{x+int(dx)}) 帧变化={d:6.2f} {'★命中' if d > 0.5 else ''}")
        if d > 0.5:
            print(f"  ==> 命中 x={x} dx={dx}")
            return
    print("  未命中任何点")


def cmd_probe(x, y):
    """用多种完全不同的注入通道点击同一目标，逐一报告是否生效。

    通道：
      msg   —— PostMessage 直接投递 WM_*BUTTON 消息（走窗口过程）
      smsg  —— SendMessage 同步投递
      rel   —— 纯相对位移移动光标后按键（模拟真实鼠标的运动路径）
      flush —— 先补发若干次抬起（清掉可能卡住的按键状态）再点击
    """
    hits = find_window()
    if not hits:
        print("!! 找不到游戏窗口")
        return
    h, pid, rect = hits[0]
    force_foreground(h)
    x, y = int(x), int(y)
    cx, cy = x, y  # 客户区坐标（窗口 origin 为 0,0 时等同屏幕坐标）

    def ok(before, after, tag):
        d = diff(before, after)
        print(f"  [{tag}] 帧变化={d:6.2f} {'★画面已变化' if d > 0.5 else ''}")
        return d > 0.5

    # 1) PostMessage 直投
    before = grab(h)
    lp = win32api.MAKELONG(cx, cy)
    win32gui.PostMessage(h, win32con.WM_MOUSEMOVE, 0, lp)
    time.sleep(0.2)
    win32gui.PostMessage(h, win32con.WM_LBUTTONDOWN, win32con.MK_LBUTTON, lp)
    time.sleep(0.15)
    win32gui.PostMessage(h, win32con.WM_LBUTTONUP, 0, lp)
    time.sleep(1.6)
    if ok(before, grab(h), "msg/PostMessage"):
        return

    # 2) SendMessage 同步
    before = grab(h)
    win32api.SetCursorPos((rect[0] + cx, rect[1] + cy))
    time.sleep(0.3)
    win32gui.SendMessage(h, win32con.WM_MOUSEMOVE, 0, lp)
    win32gui.SendMessage(h, win32con.WM_LBUTTONDOWN, win32con.MK_LBUTTON, lp)
    time.sleep(0.15)
    win32gui.SendMessage(h, win32con.WM_LBUTTONUP, 0, lp)
    time.sleep(1.6)
    if ok(before, grab(h), "smsg/SendMessage"):
        return

    # 3) 纯相对位移
    before = grab(h)
    cur = win32api.GetCursorPos()
    tx, ty = rect[0] + cx, rect[1] + cy
    dx, dy = tx - cur[0], ty - cur[1]
    step = 20
    while dx or dy:
        mx = max(-step, min(step, dx))
        my = max(-step, min(step, dy))
        win32api.mouse_event(win32con.MOUSEEVENTF_MOVE, mx, my, 0, 0)
        dx -= mx
        dy -= my
        time.sleep(0.02)
    time.sleep(0.4)
    win32api.mouse_event(win32con.MOUSEEVENTF_LEFTDOWN, 0, 0, 0, 0)
    time.sleep(0.15)
    win32api.mouse_event(win32con.MOUSEEVENTF_LEFTUP, 0, 0, 0, 0)
    time.sleep(1.6)
    if ok(before, grab(h), "rel/相对位移"):
        return

    # 4) 先清按键状态
    for _ in range(5):
        win32api.mouse_event(win32con.MOUSEEVENTF_LEFTUP, 0, 0, 0, 0)
        win32api.mouse_event(win32con.MOUSEEVENTF_RIGHTUP, 0, 0, 0, 0)
        time.sleep(0.05)
    before = grab(h)
    win32api.SetCursorPos((tx, ty))
    time.sleep(0.4)
    win32api.mouse_event(win32con.MOUSEEVENTF_LEFTDOWN, 0, 0, 0, 0)
    time.sleep(0.15)
    win32api.mouse_event(win32con.MOUSEEVENTF_LEFTUP, 0, 0, 0, 0)
    time.sleep(1.6)
    if ok(before, grab(h), "flush/清按键后点击"):
        return

    print("  所有注入通道均无效")


def cmd_scany(x, y0, y1, dx=40, step=10):
    """固定 x 与点击偏移，纵向扫描 y，找出真正能命中的位置。"""
    hits = find_window()
    if not hits:
        print("!! 找不到游戏窗口")
        return
    h, pid, rect = hits[0]
    force_foreground(h)
    print(f"纵扫 y={y0}..{y1} step={step} x={x} dx={dx}")
    for y in range(int(y0), int(y1) + 1, int(step)):
        before = grab(h)
        _do_click(rect[0] + int(x) + int(dx), rect[1] + y)
        time.sleep(1.5)
        d = diff(before, grab(h))
        print(f"  y={y:5d} 帧变化={d:6.2f} {'★命中' if d > 0.5 else ''}")
        if d > 0.5:
            print(f"  ==> y={y} 命中")
            return
    print("  纵扫未命中")


def cmd_click(x, y, dx=OFFSET_DEFAULT[0], dy=OFFSET_DEFAULT[1], detect=True):
    hits = find_window()
    if not hits:
        print("!! 找不到游戏窗口；是否在运行？")
        return
    h, pid, rect = hits[0]
    force_foreground(h)
    before = grab(h) if detect else None
    tx, ty = rect[0] + int(x) + int(dx), rect[1] + int(y) + int(dy)
    _do_click(tx, ty)
    print(f"点击 目标=({x},{y}) 偏移=({dx},{dy}) 实际光标=({tx},{ty})")
    if before is not None:
        time.sleep(1.7)
        after = grab(h)
        d = diff(before, after)
        print(f"  帧变化={d:.2f} {'★画面已变化' if d > 0.5 else '(无变化)'}")


def cmd_sweep(x, y, detect=True):
    hits = find_window()
    if not hits:
        print("!! 找不到游戏窗口")
        return
    h, pid, rect = hits[0]
    force_foreground(h)
    print(f"扫描目标 ({x},{y}) 的点击偏移，窗口 origin={rect[:2]}")
    for dx in (0, 20, 40, 60, 75, 90, 105, 120, 140, 160):
        before = grab(h)
        _do_click(rect[0] + int(x) + dx, rect[1] + int(y))
        time.sleep(1.6)
        after = grab(h)
        d = diff(before, after)
        flag = "★画面已变化" if d > 0.5 else ""
        print(f"  dx={dx:4d}  帧变化={d:6.2f}  {flag}")
        if d > 0.5:
            print(f"  ==> 可用偏移 dx={dx}")
            return
    print("  扫描完毕，均无变化")


def cmd_move(x, y, dx=OFFSET_DEFAULT[0], dy=OFFSET_DEFAULT[1]):
    hits = find_window()
    if not hits:
        print("!! 找不到游戏窗口")
        return
    h, pid, rect = hits[0]
    force_foreground(h)
    win32api.SetCursorPos((rect[0] + int(x) + int(dx), rect[1] + int(y) + int(dy)))
    time.sleep(0.2)
    win32api.mouse_event(win32con.MOUSEEVENTF_MOVE, 1, 1, 0, 0)
    win32api.mouse_event(win32con.MOUSEEVENTF_MOVE, -1, -1, 0, 0)
    time.sleep(0.35)
    print(f"移动到 ({x},{y})")


def cmd_key(name, detect=False):
    hits = find_window()
    if not hits:
        print("!! 找不到游戏窗口")
        return
    h, pid, rect = hits[0]
    force_foreground(h)
    before = grab(h) if detect else None
    vk = VK.get(name.upper())
    if vk is None:
        print("!! 未知键", name)
        return
    win32api.keybd_event(vk, 0, 0, 0)
    time.sleep(0.08)
    win32api.keybd_event(vk, 0, win32con.KEYEVENTF_KEYUP, 0)
    print("按键", name.upper())
    if detect:
        time.sleep(1.5)
        print(f"  帧变化={diff(before, grab(h)):.2f}")


# ---------------------------------------------------------------- 其它

def cmd_start():
    if pids_of():
        print("已在运行:", pids_of())
        return
    p = subprocess.Popen([EXE], cwd=CWD)
    print("已启动 pid=", p.pid)


def cmd_keepalive(minutes=30.0):
    cmd_start()
    t_end = time.time() + float(minutes) * 60
    print(f"保活中，将在 {minutes} 分钟后自动退出（期间游戏常开）")
    while time.time() < t_end:
        time.sleep(5)


def cmd_shot(name, full=False):
    os.makedirs(OUTDIR, exist_ok=True)
    path = os.path.join(OUTDIR, name + ".png")
    if full:
        img = ImageGrab.grab(all_screens=True)
    else:
        hits = find_window()
        if not hits:
            print("!! 找不到游戏窗口，改抓全屏")
            img = ImageGrab.grab(all_screens=True)
        else:
            img = grab(hits[0][0])
    img.save(path)
    print(f"已保存 {path} {img.size}")


def cmd_info():
    hits = find_window()
    print("rich6 进程:", pids_of())
    if not hits:
        print("无可见窗口")
        return
    for h, pid, rect in hits:
        cr = win32gui.GetClientRect(h)
        org = win32gui.ClientToScreen(h, (0, 0))
        print(f"hwnd={h} pid={pid} rect={rect} client={cr[2]}x{cr[3]} client原点={org} "
              f"前景={win32gui.GetForegroundWindow() == h}")


def cmd_log():
    p = os.path.join(CWD, "r6log.txt")
    if not os.path.exists(p):
        print("(无 r6log.txt)")
        return
    with open(p, "rb") as f:
        print(f.read().decode("gbk", "replace"))


def cmd_close():
    subprocess.run(["taskkill", "/F", "/IM", "rich6.exe"], capture_output=True)
    print("已结束游戏进程")


def main():
    a = sys.argv[1:]
    if not a:
        print(__doc__)
        return 1
    c = a[0]
    if c == "keepalive":
        cmd_keepalive(a[1] if len(a) > 1 else 30.0)
    elif c == "info":
        cmd_info()
    elif c == "shot":
        cmd_shot(a[1])
    elif c == "fullshot":
        cmd_shot(a[1], True)
    elif c == "click":
        cmd_click(a[1], a[2], *(a[3:5] if len(a) > 3 else (0, 0)))
    elif c == "clickr":
        cmd_click_retry(a[1], a[2])
    elif c == "scan":
        cmd_scan(a[1], a[2], a[3], a[4] if len(a) > 4 else 10, a[5] if len(a) > 5 else 0)
    elif c == "probe":
        cmd_probe(a[1], a[2])
    elif c == "scany":
        cmd_scany(a[1], a[2], a[3], a[4] if len(a) > 4 else 40)
    elif c == "sweep":
        cmd_sweep(a[1], a[2])
    elif c == "move":
        cmd_move(a[1], a[2])
    elif c == "key":
        cmd_key(a[1], detect=True)
    elif c == "log":
        cmd_log()
    elif c == "close":
        cmd_close()
    else:
        print("未知子命令:", c)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
