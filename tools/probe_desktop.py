# -*- coding: utf-8 -*-
"""探测当前会话是否有可抓取的桌面，并列出可见顶层窗口。"""
import sys
from PIL import ImageGrab
import win32gui
import win32api

out = []
try:
    sm = win32api.GetSystemMetrics
    out.append(f"屏幕尺寸: {sm(0)}x{sm(1)}  虚拟桌面: {sm(78)}x{sm(79)}")
    sm_cxv = sm(0)
except Exception as e:
    out.append(f"GetSystemMetrics 失败: {e}")

wins = []
def cb(h, _):
    if win32gui.IsWindowVisible(h):
        t = win32gui.GetWindowText(h)
        r = win32gui.GetWindowRect(h)
        cls = win32gui.GetClassName(h)
        if t.strip():
            wins.append((h, t, cls, r))
    return True

win32gui.EnumWindows(cb, None)
out.append(f"可见且有标题的顶层窗口: {len(wins)}")
for h, t, cls, r in wins[:25]:
    out.append(f"  hwnd={h}  [{cls}]  {t!r}  rect={r}")

try:
    img = ImageGrab.grab(all_screens=True)
    out.append(f"全屏截图: {img.size}  mode={img.mode}")
    px = img.convert("RGB").resize((8, 8)).getdata()
    nonblack = sum(1 for p in px if sum(p) > 30)
    out.append(f"缩略 64 像素中非黑像素: {nonblack}/64")
    img.save(r"D:\Projects\RichMan\.workbuddy\_screen_probe.png")
    out.append("已保存 .workbuddy\\_screen_probe.png")
except Exception as e:
    out.append(f"截图失败: {type(e).__name__}: {e}")

open(r"D:\Projects\RichMan\.workbuddy\_probe.txt", "w", encoding="utf-8").write("\n".join(out))
print("\n".join(out))
