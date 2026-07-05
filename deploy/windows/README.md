# 🩺 健康管理系统 - Windows / Linux 部署文档 (v1.0)

> 学生实践项目 · 二次开发定制版 · 适用于答辩演示与日常开发

---

## 📋 项目概况

| 项 | 内容 |
|---|---|
| **项目名** | 健康管理系统 (health-management) |
| **后端** | Spring Boot 3.3.5 + MyBatis-Plus 3.5.9 + JDK 17 |
| **前端 H5** | Vue 3 + Vite 6 + ECharts 5 |
| **数据库** | MySQL 8+ / MariaDB 10+ |
| **Android** | Kotlin + ViewBinding + Material 3（独立 APK） |
| **默认端口** | 后端 `8090` / H5 `5176` / 数据库 `3305` |
| **演示账号** | 患者 `user_wang / root` · 医生 `doctor_zhang / root` · 管理员 `admin / root` |
| **演示数据** | 15 张表全部含 seed (init.sql 268 行) |

> 🔔 **端口说明**：项目用 `3305` 端口（避免与系统中已有的 `3306` MySQL 冲突）。如有冲突，改 `application.yml`。

---

## 🖥️ 0. 系统要求

| 软件 | 最低版本 | 推荐版本 | 备注 |
|---|---|---|---|
| **操作系统** | Windows 10 / 11 / Server 2019+ | Windows 11 | Linux: Ubuntu 22.04+ / CentOS 9+ |
| **JDK** | 17 (LTS) | 21 (兼容) | ⚠️ 必须是 JDK 17 编译 |
| **Node.js** | 18 LTS | 20 LTS | 仅开发 / npm install 时需要 |
| **MariaDB** | 10.6 | 11.4+ | 或 MySQL 8.0+ |
| **NSSM** | 2.24 | 2.24 | 仅 Windows 服务化用 |
| **磁盘空间** | 5 GB | 10 GB | 含 JDK + MariaDB |
| **内存** | 4 GB | 8 GB | 后端 + 数据库 |

---

## 📥 1. 软件下载

| 软件 | 下载链接 | 安装要点 |
|---|---|---|
| **JDK 17 (Eclipse Temurin)** | https://adoptium.net/temurin/releases/?version=17 | 记下安装路径 `C:\Program Files\Eclipse Adoptium\jdk-17` |
| **MariaDB 11.4** | https://mariadb.org/download/ | **端口改 3305**, **root 密码设 root** (或自定义) |
| **Node.js 20 LTS** | https://nodejs.org/ | 默认安装, 含 npm |
| **NSSM 2.24** | https://nssm.cc/release/nssm-2.24.zip | 解压到 `C:\Tools\nssm-2.24\` |
| **Maven (可选)** | https://maven.apache.org/ | 仅需要重新打包后端时用 |

> 💡 **不想自己下**：本项目源码包 `健康管理系统.zip` 已包含后端编译产物 `target/health-management-1.0.0.jar`，**只需 JDK 17 + 数据库即可启动**。

---

## 📂 2. 目录结构

```
健康管理系统/
├── frontend/                       # H5 源码 (Vue 3)
│   ├── src/
│   ├── package.json
│   └── dist/                       # 已构建好的静态产物
├── src/                            # 后端源码
├── sql/
│   └── init.sql                    # 15 张表 + 15 份 seed 数据
├── target/
│   └── health-management-1.0.0.jar # 已编译的 Spring Boot jar ⭐
├── uploads/                        # 文件上传目录
└── deploy/                         # ⭐ 部署包
    ├── env-example-backend         # 环境变量模板
    └── windows/                    # Windows 部署脚本
        ├── init-db.ps1             # 数据库初始化
        ├── start-backend.ps1       # 启动后端 (前台)
        ├── start-frontend.ps1      # 启动 H5 (前台)
        ├── install-services.ps1    # 注册 Windows 服务
        ├── uninstall-services.ps1  # 卸载服务
        └── smoke-test.ps1          # 端到端验证
```

---

## 🚀 3. 快速上手 (5 分钟)

### 3.1 环境变量

```powershell
# PowerShell (永久)
setx JAVA_HOME "C:\Program Files\Eclipse Adoptium\jdk-17"
setx PATH "$env:PATH;%JAVA_HOME%\bin"

# 验证
java -version        # 应该看到 openjdk 17.x.x
```

### 3.2 启动 MariaDB

```powershell
# 如果用 mariadb-install-db 默认服务, 应该已经自动启动
# 验证
net start | findstr -i maria
```

### 3.3 初始化数据库 (5 步)

```powershell
cd 健康管理系统\deploy\windows

# 第一次跑, 会问数据库 root 密码
.\init-db.ps1
```

**预期输出**：
```
🔍 测试数据库连接 127.0.0.1:3305 ...
✅ 数据库连接 OK
📦 导入 sql/init.sql 到 health_management ...
✅ 创建数据库: health_management (表数=15, 演示用户数=3)
🎉 初始化完成!
   演示账号:
   - 患者:  user_wang / root
   - 医生:  doctor_zhang / root
   - 管理员: admin / root
```

### 3.4 启动后端

```powershell
.\start-backend.ps1
```

**预期日志** (节选)：
```
🚀 启动健康管理系统后端...
   JAR: C:\...\target\health-management-1.0.0.jar
   端口: 8090
   日志: C:\...\logs\backend.log

  .   ____          _            __ _ _
 /\\ / ___'_ __ _ _(_)_ __  __ _ \ \ \ \
...

Tomcat started on port 8090 (http)
Started HealthManagementApplication in 3.45 seconds
```

### 3.5 启动 H5 (开发模式)

新开 PowerShell 窗口：
```powershell
cd 健康管理系统\deploy\windows
.\start-frontend.ps1
```

浏览器打开：
- 患者 H5: http://localhost:5176/
- 工作台: http://localhost:5176/manage

**演示登录**: `user_wang / root`

### 3.6 Android 客户端

详见下方 [Android 客户端](#-4-android-客户端) 一节。

---

## 🎯 4. 日常使用

| 任务 | 命令 |
|---|---|
| 启动后端 (前台) | `.\start-backend.ps1` |
| 启动 H5 (前台) | `.\start-frontend.ps1` |
| 重新构建后端 | `cd 健康管理系统; mvn package -DskipTests` |
| 重新构建前端 (生产 dist) | `.\start-frontend.ps1 -Build` |
| 端到端验证 | `.\smoke-test.ps1` |
| 看后端日志 (前台) | 在运行窗口 Ctrl+Scroll 或查看 `logs\backend.log` |
| 看后端日志 (服务模式) | `Get-Content logs\backend.out.log -Wait` |

---

## 🛡️ 5. 注册为 Windows 后台服务 (可选)

如果你想开机自启 + 后台运行:

```powershell
# 1. PowerShell ⭐ 管理员 ⭐ 身份运行
# 2. 先用 start-frontend.ps1 让它 npm install (否则 vite.cmd 不存在)
.\start-frontend.ps1
# Ctrl+C 终止

# 3. 安装服务
.\install-services.ps1
```

**预期输出**:
```
🛡️  正在以管理员权限运行...
✅ NSSM: C:\Tools\nssm-2.24\win64\nssm.exe
📦 安装服务: HealthMgmtBackend
✅ HealthMgmtBackend 已安装 (类型: AUTO_START, 失败重启)
📦 安装服务: HealthMgmtFrontend
✅ HealthMgmtFrontend 已安装 (类型: AUTO_START, 失败重启)
🚀 启动服务...
🎉 安装完成!
```

**管理命令**:
```powershell
sc query HealthMgmtBackend          # 状态
sc stop HealthMgmtBackend           # 停止
sc start HealthMgmtBackend          # 启动
services.msc                        # 图形管理
Get-Content logs\backend.out.log -Wait  # 实时日志流
```

**卸载**:
```powershell
.\uninstall-services.ps1
```

---

## 📱 6. Android 客户端

### 6.1 获取 APK

**方式 A**: 用我已经构建好的 `app-debug.apk`
```
路径: app/build/outputs/apk/debug/app-debug.apk
大小: 7.74 MB
md5:  (运行 Get-FileHash 获取)
```

**方式 B**: 自己重新构建
```bash
cd /path/to/android-app
JAVA_HOME=/path/to/jdk-17 ./gradlew assembleDebug
```

### 6.2 安装到设备

**模拟器** (Android Studio AVD):
```powershell
adb install -r app-debug.apk
# 默认 10.0.2.2:8090 直连宿主机, 无需额外配置
```

**真机** (USB):
```powershell
# 1. 手机开 USB 调试 + 电脑装对应 USB 驱动
adb devices

# 2. 方式 A: 反向代理 (推荐, 不依赖 WiFi)
adb reverse tcp:8090 tcp:8090
adb install -r app-debug.apk

# 3. 方式 B: 同 WiFi 局域网, 改 API 地址
#    修改 app/build.gradle 的 API_BASE_URL = "http://<宿主机IP>:8090/"
#    重新 ./gradlew assembleDebug
```

### 6.3 演示数据准备

| 字段 | 值 |
|---|---|
| 测试账号 | `user_wang` / `root` |
| 角色 | USER (患者) |
| 端口 | 8090 (后端 API) |
| 反代命令 | `adb reverse tcp:8090 tcp:8090` |

### 6.4 完整演示流程

1. 启动后端 + H5 (在 PC)
2. 手机连 USB 或模拟器开
3. `adb reverse tcp:8090 tcp:8090` (USB 真机)
4. 安装 + 启动 APK
5. demo 账号登录
6. 体验：录入健康数据、看趋势图、查用药、紧急 SOS、看文章

---

## 🚨 7. 故障排查 (10 大常见)

### 7.1 ⭐ 后端启动报 "找不到符号 getXxx"
**根因**: 用 JDK 25 编译了 Lombok 注解不兼容。
**修复**:
```powershell
$env:JAVA_HOME = "C:\Program Files\Eclipse Adoptium\jdk-17"
cd 健康管理系统
mvn package -DskipTests
```

### 7.2 后端启动报 "Communications link failure"
**根因**: MariaDB / MySQL 没起, 或端口错。
**修复**:
```powershell
net start | findstr -i maria     # 确认服务在跑
Test-NetConnection localhost -Port 3305  # 验证端口
```

### 7.3 后端报 "Access denied for user 'root'@'localhost'"
**根因**: 数据库密码错, 或 MariaDB unix socket auth。
**修复**:
- MariaDB 启动时 `--skip-grant-tables` 进安全管理改密码
- 或检查 `application.yml` 的 `spring.datasource.password`

### 7.4 H5 启动报 "EADDRINUSE :::5176"
**根因**: 端口被占。
**修复**: 改 `frontend/vite.config.js` 的 `server.port = 5177`, 或结束占 5176 的进程。

### 7.5 浏览器访问 http://localhost:5176/ 空白
**根因**: `node_modules` 未安装 / Vite 未起来。
**修复**:
```powershell
cd ../frontend
npm install
npm run dev
```

### 7.6 后端启动报 "Port 8090 was already in use"
**根因**: 之前的 Java 进程没结束 / 别的程序占用。
**修复**:
```powershell
Get-Process | Where-Object {$_.Port -eq 8090}
Get-NetTCPConnection -LocalPort 8090 -ErrorAction SilentlyContinue
# 找到 PID 后:
Stop-Process -Id <PID> -Force
```

### 7.7 ⭐ PowerShell 报 "running scripts is disabled on this system"
**根因**: 执行策略禁止 .ps1 脚本。
**修复** (管理员):
```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

### 7.8 init-db 报 "AuthenticationProvider.BadAuthenticationPlugin"
**根因**: 错误信息误导！实际是密码错。
**修复**:
- 重试 init-db.ps1, 仔细输密码
- 端口确认 (3305)
- MariaDB 实际只允许 `127.0.0.1` 不允许 `localhost` → 用 `-h 127.0.0.1`

### 7.9 ⭐ Android 登录提示 "Unable to resolve host"
**根因**: 模拟器/真机连不上 PC 8090。
**修复**:
- 模拟器: `http://10.0.2.2:8090` (默认配置)
- USB 真机: `adb reverse tcp:8090 tcp:8090`
- WiFi 真机: PC 防火墙放行 8090 + 用局域网 IP

### 7.10 NSSM 服务启动后立即停
**根因**: 一般是 java 路径错 / jar 路径错。
**修复**:
```powershell
# 看详细错误
& 'C:\Tools\nssm-2.24\win64\nssm.exe' status HealthMgmtBackend
Get-Content deploy\windows\logs\backend.err.log -Tail 30
```

---

## 🔧 8. systemd 单元 (Linux 等价)

如果部署在 Linux 服务器，可以替代 NSSM：

`/etc/systemd/system/health-backend.service`:
```ini
[Unit]
Description=Health Management Backend
After=mariadb.service

[Service]
Type=simple
User=appuser
Environment=JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
EnvironmentFile=-/etc/opck/health-backend.env
ExecStart=${JAVA_HOME}/bin/java -Dfile.encoding=UTF-8 -Dspring.profiles.active=prod -jar /opt/health-mgmt/target/health-management-1.0.0.jar
WorkingDirectory=/opt/health-mgmt
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now health-backend
sudo systemctl status health-backend
```

---

## 🔄 9. 升级与回滚

### 升级后端
```powershell
# 1. 备份当前 jar
copy target\health-management-1.0.0.jar target\health-management-1.0.0.jar.bak

# 2. 重新编译 (或复制新版 jar)
mvn package -DskipTests

# 3. 重启服务
sc stop HealthMgmtBackend
sc start HealthMgmtBackend
```

### 回滚
```powershell
sc stop HealthMgmtBackend
copy target\health-management-1.0.0.jar.bak target\health-management-1.0.0.jar
sc start HealthMgmtBackend
```

### 数据库迁移
开发期可以 `DROP DATABASE health_management` 后重跑 `init-db.ps1`。
生产期推荐用 Flyway / Liquibase (本次课设未集成)。

---

## 📜 10. License & 文档版本

- **License**: 课程演示用途, 仅供学习
- **文档版本**: v1.0 (2026-07-05)
- **基于**: OPC_K `deploy-windows` skill (智慧家庭 17 轮 force-push 实战)
- **作者**: pm_jiaozi (饺子)
- **修订记录**:
  - v1.0 (2026-07-05): 初始版本 (适配健康管理系统)

---

## 📞 联系 & 反馈

部署过程中遇到问题:
1. 优先看 [故障排查](#-7-故障排查-10-大常见)
2. 跑 `.\smoke-test.ps1` 自检
3. 看 `logs\backend.log` / `logs\backend.err.log`

---

🎓 **学生项目答辩备注**：
- 启动只需 3 步 (start-backend → start-frontend → 浏览器访问)
- 服务化可选 (开机自启)
- Android 客户端独立 APK (不依赖 PC)
- 演示账号已含 seed (user_wang / root)
