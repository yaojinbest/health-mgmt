#!/usr/bin/env python3
"""
spa-server.py - 单文件 SPA (Vue 3 history mode) HTTP server
替代 `python3 -m http.server`, 因为后者不支持 SPA fallback:
  GET /dashboard → 404 (找不到 dashboard 文件)
  GET /medical   → 404
应该返回 dist/index.html 让 Vue router 处理

用法:
  python3 spa-server.py <port> <dist-dir>
例如:
  python3 spa-server.py 5173 ./frontend-pc/dist
"""

import sys
import os
import re
import socketserver
import http.server
from pathlib import Path

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 5173
DIST_DIR = sys.argv[2] if len(sys.argv) > 2 else "./frontend-pc/dist"
DIST_DIR = Path(DIST_DIR).resolve()

if not DIST_DIR.is_dir():
    print(f"[FAIL] {DIST_DIR} 不是目录")
    sys.exit(1)

os.chdir(DIST_DIR)


class SPAHandler(http.server.SimpleHTTPRequestHandler):
    """SPA fallback: 找不到文件时返回 index.html"""

    def send_head(self):
        # 用户访问的 path (URL 解码)
        path = self.translate_path(self.path)
        if os.path.isfile(path):
            return super().send_head()
        # SPA fallback: 任何非 .html / 静态资源的 path 都返 index.html
        if not re.search(r"\.[a-zA-Z0-9]+$", self.path):
            self.path = "/index.html"
        return super().send_head()

    def log_message(self, format, *args):
        # 静默 (或简单打印)
        return  # 不打印每条访问日志


print(f"🥟 SPA server 启在 http://0.0.0.0:{PORT} (root: {DIST_DIR})")

with socketserver.TCPServer(("", PORT), SPAHandler) as httpd:
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\n[stop] SPA server 停了")
