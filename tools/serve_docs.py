#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""起一个本地 HTTP 服务（根 = 项目目录）并打开音效试听页。

为什么不能直接双击 HTML：
    试听页用相对路径 `../game/assets/audio/...` 取音频。
    - 内置预览面板是把 HTML **拷到临时目录**再渲染的，相对路径必然 404；
    - file:// 下部分浏览器也会拦子资源。
所以统一走本地服务，根目录 = 项目根，`/docs/sfx-audition.html` 就能正常取到
`/game/assets/audio/...`。

用法：
    python tools/serve_docs.py            # 默认 8777
    SFX_PORT=9000 python tools/serve_docs.py
"""
import functools
import http.server
import os
import socketserver
import sys
import threading
import webbrowser

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PORT = int(os.environ.get("SFX_PORT", "8777"))
PAGE = "/docs/sfx-audition.html"


class Handler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, fmt, *args):   # 默认日志太吵，压掉
        pass


def main() -> int:
    os.chdir(ROOT)
    socketserver.TCPServer.allow_reuse_address = True
    handler = functools.partial(Handler, directory=ROOT)
    with socketserver.ThreadingTCPServer(("127.0.0.1", PORT), handler) as srv:
        srv.daemon_threads = True
        url = "http://127.0.0.1:%d%s" % (PORT, PAGE)
        print("=" * 60)
        print("  大富翁6 音效试听页")
        print("  %s" % url)
        print("  项目根：%s" % ROOT)
        print("  关掉这个窗口即停止服务。")
        print("=" * 60)
        threading.Timer(0.6, lambda: webbrowser.open(url)).start()
        try:
            srv.serve_forever()
        except KeyboardInterrupt:
            print("\n已停止。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
