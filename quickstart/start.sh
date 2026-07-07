#!/usr/bin/env bash
# =====================================================================
# start.sh - Sandbox / 无 docker 环境 fallback 启动脚本
# 跟 docker-compose up 等价, 但用本机 binary 直接拉起
# 适用: sandbox 测试 / 答辩 demo / 不想装 docker 的场景
# =====================================================================
set -eo pipefail  # 不带 -u 避免 unbound variable 报错

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
mkdir -p "$LOG_DIR"

# 默认值避免 unbound 报错
MARIADB_CLIENT="${MARIADB_CLIENT:-}"
MARIADBD_BIN="${MARIADBD_BIN:-}"

# 自适应查找 mariadbd / mariadb 客户端
MARIADBD_BIN=""
for p in /usr/sbin/mariadbd /usr/local/sbin/mariadbd /usr/bin/mariadbd /usr/local/bin/mariadbd mariadbd; do
    if command -v "$p" >/dev/null 2>&1 || [ -x "$p" ]; then
        MARIADBD_BIN="$p"
        break
    fi
done
if [ -z "$MARIADBD_BIN" ]; then
    echo "[FAIL] 找不到 mariadbd binary"
    exit 1
fi

MARIADB_CLIENT=""
for p in mariadb /usr/bin/mariadb /usr/local/bin/mariadb mysql; do
    if command -v "$p" >/dev/null 2>&1; then
        MARIADB_CLIENT="$p"
        break
    fi
done
if [ -z "$MARIADB_CLIENT" ]; then
    echo "[FAIL] 找不到 mariadb/mysql 客户端"
    exit 1
fi

DB_PORT="${DB_PORT:-3306}"
DB_USER="${DB_USER:-root}"
DB_PWD="${DB_PWD:-opck2026}"
DB_NAME="${DB_NAME:-health_management}"
BACKEND_PORT="${BACKEND_PORT:-8090}"
FRONTEND_PORT="${FRONTEND_PORT:-5173}"

echo "==============================================="
echo " 健康管理系统 Quickstart (sandbox 模式)"
echo " Root :  $ROOT_DIR"
echo " mariadbd: $MARIADBD_BIN"
echo " client :  $MARIADB_CLIENT"
echo " Logs :  $LOG_DIR"
echo "==============================================="
echo ""

# ----- 1. 启 MariaDB -----
echo "[1/4] 启 MariaDB ..."

DB_DATA="/tmp/health-mgmt-quickstart-db"
DB_RUN="/tmp/health-mgmt-quickstart-run"
DB_SOCK="$DB_RUN/mysql.sock"
mkdir -p "$DB_RUN"

if pgrep mariadbd >/dev/null 2>&1; then
    echo "    MariaDB 已在跑 (pid: $(pgrep mariadbd | head -1))"
else
    if [ ! -d "$DB_DATA/mysql" ]; then
        echo "    初始化 MariaDB data dir ..."
        mariadb-install-db --no-defaults --user="$(whoami)" --datadir="$DB_DATA" >/dev/null 2>&1 || {
            echo "[FAIL] mariadb-install-db 失败"
            exit 1
        }
    fi

    # Step 1.1: skip-grant-tables 启, 设密码
    nohup "$MARIADBD_BIN" \
        --no-defaults \
        --datadir="$DB_DATA" \
        --socket="$DB_SOCK" \
        --port="$DB_PORT" \
        --pid-file="$DB_RUN/mysql.pid" \
        --character-set-server=utf8mb4 \
        --collation-server=utf8mb4_unicode_ci \
        --skip-grant-tables \
        --user="$(whoami)" \
        > "$LOG_DIR/mariadb-init.log" 2>&1 &

    # poll 等待 socket ready
    for i in $(seq 1 20); do
        sleep 1
        if [ -S "$DB_SOCK" ]; then
            break
        fi
    done

    if [ ! -S "$DB_SOCK" ]; then
        echo "[FAIL] MariaDB skip-grant 启动失败, 看 logs/mariadb-init.log"
        tail -10 "$LOG_DIR/mariadb-init.log"
        exit 1
    fi

    # 设 root 密码 (IDENTIFIED VIA mysql_native_password USING PASSWORD 是 mariadb 11.x
    # 唯一确定能走 TCP 密码认证的方式; CREATE USER IDENTIFIED BY 默认 plugin 可能错)
    "$MARIADB_CLIENT" --socket="$DB_SOCK" -u "$DB_USER" -e "
        FLUSH PRIVILEGES;
        ALTER USER 'root'@'localhost' IDENTIFIED VIA mysql_native_password USING PASSWORD('$DB_PWD');
        ALTER USER 'root'@'127.0.0.1' IDENTIFIED VIA mysql_native_password USING PASSWORD('$DB_PWD');
        CREATE USER IF NOT EXISTS 'root'@'%' IDENTIFIED VIA mysql_native_password USING PASSWORD('$DB_PWD');
        GRANT ALL ON *.* TO 'root'@'localhost' WITH GRANT OPTION;
        GRANT ALL ON *.* TO 'root'@'127.0.0.1' WITH GRANT OPTION;
        GRANT ALL ON *.* TO 'root'@'%' WITH GRANT OPTION;
        FLUSH PRIVILEGES;
    " >/dev/null 2>&1 || echo "    (部分 GRANT 跳过, 可能用户已存在)"

    # Step 1.2: 停 skip-grant, 重启 normal
    pkill -f "$MARIADBD_BIN" 2>/dev/null || true
    sleep 2

    nohup "$MARIADBD_BIN" \
        --no-defaults \
        --datadir="$DB_DATA" \
        --socket="$DB_SOCK" \
        --port="$DB_PORT" \
        --pid-file="$DB_RUN/mysql.pid" \
        --character-set-server=utf8mb4 \
        --collation-server=utf8mb4_unicode_ci \
        --default-authentication-plugin=mysql_native_password \
        --user="$(whoami)" \
        > "$LOG_DIR/mariadb.log" 2>&1 &

    # poll 等待 TCP port ready
    for i in $(seq 1 20); do
        sleep 1
        if "$MARIADB_CLIENT" -h 127.0.0.1 -P "$DB_PORT" -u "$DB_USER" "-p$DB_PWD" -e "SELECT 1" >/dev/null 2>&1; then
            break
        fi
    done

    if ! "$MARIADB_CLIENT" -h 127.0.0.1 -P "$DB_PORT" -u "$DB_USER" "-p$DB_PWD" -e "SELECT 1" >/dev/null 2>&1; then
        echo "[FAIL] MariaDB TCP 登入失败 (root/$DB_PWD), 看 logs/mariadb.log"
        tail -10 "$LOG_DIR/mariadb.log"
        exit 1
    fi
    echo "    OK (mariadbd 启在 port $DB_PORT, socket $DB_SOCK)"
fi

# ----- 2. 初始化 health_management 库 + 导入 init.sql -----
echo "[2/4] 初始化数据库 + 导入 init.sql ..."

"$MARIADB_CLIENT" -h 127.0.0.1 -P "$DB_PORT" -u "$DB_USER" "-p$DB_PWD" \
    -e "DROP DATABASE IF EXISTS $DB_NAME; CREATE DATABASE $DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" 2>/dev/null

"$MARIADB_CLIENT" -h 127.0.0.1 -P "$DB_PORT" -u "$DB_USER" "-p$DB_PWD" "$DB_NAME" \
    --default-character-set=utf8mb4 \
    < "$ROOT_DIR/sql/init.sql" > "$LOG_DIR/init-db.log" 2>&1

if [ $? -ne 0 ]; then
    echo "[FAIL] init.sql 导入失败, 看 logs/init-db.log"
    tail -10 "$LOG_DIR/init-db.log"
    exit 3
fi
echo "    OK (root/$DB_PWD, $DB_NAME 建库 + 导入 15 表)"

# ----- 3. 启 backend jar -----
echo "[3/4] 启 backend jar ..."
JAR_FILE="$ROOT_DIR/target/health-management-1.0.0.jar"
if [ ! -f "$JAR_FILE" ]; then
    echo "[FAIL] 找不到 $JAR_FILE"
    exit 4
fi

# 杀旧 backend
pkill -f "health-management-1.0.0.jar" 2>/dev/null || true
sleep 1

nohup java -jar "$JAR_FILE" \
    --spring.datasource.url="jdbc:mysql://127.0.0.1:$DB_PORT/$DB_NAME?useSSL=false&serverTimezone=Asia/Shanghai&characterEncoding=utf8" \
    --spring.datasource.username="$DB_USER" \
    --spring.datasource.password="$DB_PWD" \
    --server.port="$BACKEND_PORT" \
    > "$LOG_DIR/backend.log" 2>&1 &

# poll 等待 backend
for i in $(seq 1 30); do
    sleep 1
    CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:$BACKEND_PORT/api/auth/login" -X POST -H "Content-Type: application/json" -d '{}' 2>/dev/null || echo "000")
    if [[ "$CODE" =~ ^(200|400|401|405)$ ]]; then
        break
    fi
done

CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:$BACKEND_PORT/api/auth/login" -X POST -H "Content-Type: application/json" -d '{}' 2>/dev/null || echo "000")
if [[ ! "$CODE" =~ ^(200|400|401|405)$ ]]; then
    echo "[WARN] Backend port $BACKEND_PORT 未响应 (code=$CODE), 看 logs/backend.log"
else
    echo "    OK (backend 启在 http://127.0.0.1:$BACKEND_PORT, http_code=$CODE)"
fi

# ----- 4. 启 frontend -----
echo "[4/4] 启 frontend (SPA-aware python server) ..."
DIST_DIR="$ROOT_DIR/frontend-pc/dist"
if [ ! -d "$DIST_DIR" ]; then
    echo "[FAIL] 找不到 $DIST_DIR"
    exit 5
fi

pkill -f "http.server $FRONTEND_PORT" 2>/dev/null || true
pkill -f "spa-server.py $FRONTEND_PORT" 2>/dev/null || true
sleep 1

nohup python3 "$SCRIPT_DIR/bin/spa-server.py" "$FRONTEND_PORT" "$DIST_DIR" \
    > "$LOG_DIR/frontend.log" 2>&1 &
sleep 2

if ! curl -s "http://127.0.0.1:$FRONTEND_PORT/" -o /dev/null -w "%{http_code}" 2>/dev/null | grep -q "^200$"; then
    echo "[WARN] Frontend port $FRONTEND_PORT 未响应, 看 logs/frontend.log"
else
    echo "    OK (frontend 启在 http://127.0.0.1:$FRONTEND_PORT)"
fi

echo ""
echo "==============================================="
echo " ✅ Quickstart 启动完成"
echo "    Frontend: http://localhost:$FRONTEND_PORT"
echo "    Backend : http://localhost:$BACKEND_PORT/api"
echo "    DB      : mariadb://$DB_USER:$DB_PWD@127.0.0.1:$DB_PORT/$DB_NAME"
echo ""
echo " 6 角色账号 (密码统一 root):"
echo "    admin         / root     # 管理员"
echo "    doctor_zhang  / root     # 医生"
echo "    doctor_li     / root     # 医生"
echo "    user_wang     / root     # 用户"
echo "    user_chen     / root     # 用户"
echo "    user_zhao     / root     # 用户"
echo ""
echo " 日志: $LOG_DIR/"
echo "==============================================="
