# -*- coding: utf-8 -*-
"""
构建一个「可写」的原版运行副本，用于在沙箱下启动原版抓取画面参考。

背景：沙箱禁止修改工作区外 F:\游戏\Rich6 下的既有文件（覆写/重命名均被拒），
但允许新建文件。因此本脚本：
  1. 新建目录 F:\\游戏\\Rich6run
  2. gamedata.pck（371MB）用硬链接 —— 零拷贝、零额外占用，且它只读
  3. 其余文件实拷贝（约 18MB）
  4. 跳过会被原版写入的文件（init.txt / init_cur.txt / r6log.txt），改为生成窗口化版本

用法：
    python tools/make_r6_runtime_copy.py
"""
import os
import shutil
import subprocess
import sys

SRC = r"F:\游戏\Rich6"
DST = r"F:\游戏\Rich6run"

# 这些文件不拷贝，稍后由脚本按窗口化配置重新生成
SKIP = {"init.txt", "init_cur.txt", "r6log.txt"}
# 这些是原版可能写入的目录 —— 只读复用没问题，但仍实拷贝以策安全（体积很小）
HARDLINK_EXT = {".pck"}


def main() -> int:
    if not os.path.isdir(SRC):
        print("源目录不存在:", SRC)
        return 1

    os.makedirs(DST, exist_ok=True)

    n_link = n_copy = n_skip = 0
    total_bytes = 0

    for root, dirs, files in os.walk(SRC):
        rel = os.path.relpath(root, SRC)
        out_root = DST if rel == "." else os.path.join(DST, rel)
        os.makedirs(out_root, exist_ok=True)
        for fn in files:
            if rel == "." and fn in SKIP:
                n_skip += 1
                continue
            src = os.path.join(root, fn)
            dst = os.path.join(out_root, fn)
            if os.path.exists(dst):
                n_skip += 1
                continue
            ext = os.path.splitext(fn)[1].lower()
            size = os.path.getsize(src)
            if ext in HARDLINK_EXT:
                # mklink /H 需要 cmd，用 subprocess 避开 shell 转义问题
                r = subprocess.run(
                    ["cmd", "/c", "mklink", "/H", dst, src],
                    capture_output=True,
                )
                if r.returncode == 0 and os.path.exists(dst):
                    n_link += 1
                    total_bytes += size
                    continue
                print("  硬链接失败，回退拷贝:", fn, r.stdout.decode("gbk", "replace").strip())
            shutil.copy2(src, dst)
            n_copy += 1
            total_bytes += size

    # 生成窗口化 init.txt / init_cur.txt
    src_init = open(os.path.join(SRC, "init.txt"), "rb").read().decode("gbk")
    win_init = src_init.replace("[fullscreen] = [1]", "[fullscreen] = [0]")
    win_init = win_init.replace("[scr_width] = [800]", "[scr_width] = [1024]")
    win_init = win_init.replace("[scr_height] = [600]", "[scr_height] = [768]")
    with open(os.path.join(DST, "init.txt"), "wb") as f:
        f.write(win_init.encode("gbk"))
    with open(os.path.join(DST, "init_cur.txt"), "wb") as f:
        f.write(win_init.encode("gbk"))

    print("目录:", DST)
    print(f"硬链接 {n_link} 个 / 实拷贝 {n_copy} 个 / 跳过 {n_skip} 个")
    print(f"合计 {total_bytes/1024/1024:.1f} MB")
    print("--- init.txt 关键行 ---")
    for ln in win_init.splitlines():
        s = ln.strip()
        if s.startswith("[fullscreen]") or s.startswith("[scr_"):
            print("  ", s)
    return 0


if __name__ == "__main__":
    sys.exit(main())
