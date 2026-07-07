#!/usr/bin/env bash
# =====================================================================
# stop.sh - 停掉 start.sh 启的所有进程 (不动 sandbox docker 镜像)
# =====================================================================
set -euo pipefail

echo "[stop] 杀 backend (java jar) ..."
pkill -f "health-management-1.0.0.jar" 2>/dev/null || true

echo "[stop] 杀 frontend (python http.server) ..."
pkill -f "http.server 5173" 2>/dev/null || true

echo "[stop] 杀 mariadbd (sandbox quickstart) ..."
pkill -f "/usr/sbin/mariadbd\|mariadbd " 2>/dev/null || true

sleep 1
echo "[stop] ✅ 完成"
