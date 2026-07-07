# 健康管理系统 - 部署指南 (v4.1)

> 基于 PowerShell 5.1 实战派学习手册 v4.1 (2026-07-06 22:34)
> 设计原则: **极简 1 个脚本 + 自动 root 密码探测 + 故障自愈**

---

## ⚡ 3 步部署

```powershell
# 1. 用管理员 PowerShell 打开
# 2. cd 到 deploy/windows/
cd C:\path\to\health-mgmt\deploy\windows

# 3. 跑 install.ps1
.\install.ps1

# 如果 root 密码忘了, 加 -AutoResetRoot 自动跑 5 步 reset
.\install.ps1 -AutoResetRoot
```

跑完输出：
- Frontend: `http://localhost:5173`
- Backend: `http://localhost:8090/api`
- 6 角色账号 (密码统一 `root`)

---

## 📦 6 个 ps1 + 1 个 sql + 1 个 md (deploy/windows/)

| 文件 | 用途 | 行数 |
|---|---|---|
| `install.ps1` | **一键部署** (含 root 密码自动探测 + 自动 reset) | 380+ |
| `reset-root-auto.ps1` | **自动 5 步 reset MariaDB root 密码** (install.ps1 自动调) | 150+ |
| `reset-root-simple.sql` | root 改密 SQL (硬编码 hash + access=1099511627775) | 10 |
| `reset-root-password.md` | 手动 5 步 reset 文档 (保留) | 100+ |
| `stop-all.ps1` | 停 backend + frontend | 40 |
| `restart-all.ps1` | stop + 重新 install | 20 |
| `status.ps1` | 看 3 大组件状态 (含 PID) | 80 |
| `uninstall.ps1` | 完全卸载 (杀进程 + DROP 库 + 删 jar + 删 dist) | 100 |
| `README.md` | 本文件 | 200+ |

---

## 🌟 v4.1 重大改进 (基于 PowerShell 5.1 学习手册)

| # | 改进 | 解决的 7/6 真机坑 |
|---|---|---|
| 1 | **自动探测 root 密码** (空 / opck2026) | 坑 #3 装 MariaDB 默认空密码 |
| 2 | **-AutoResetRoot 自动跑 5 步 reset** | 坑 #3 + #5 + #17 (进哥 22:02 报 1045) |
| 3 | **datadir 自动探测** (从 my.ini 读) | 坑 #156 硬编码 `C:\Program Files\MariaDB 11.8\data` |
| 4 | **Start-Process 路径用反引号转义** | 坑 #25-28 含空格路径 |
| 5 | **Get-Content 全部加 -Encoding UTF8** | 坑 #11 中文乱码 |
| 6 | **mysql -h "127.0.0.1" 加空格 + 双引号** | 坑 #16 PS 5.1 截断为 '127' |
| 7 | **$LASTEXITCODE 立即快照** | 坑 #22-24 跨命令丢失 |
| 8 | **禁用 here-string 写 SQL** | 坑 #42 here-string 截断 |
| 9 | **mariadbd 加 --character-set-server=utf8mb4** | (兼容多语言) |
| 10 | **健康检查** Invoke-WebRequest | 启动后立即验证 |

---

## 📋 6 角色账号 (密码统一 `root`)

| 账号 | 角色 | 权限 |
|---|---|---|
| `admin` | 管理员 | 全权限 |
| `doctor_zhang` | 医生 | 接诊 + 处方 |
| `doctor_li` | 医生 | 接诊 + 处方 |
| `user_wang` | 用户 | 预约 + 健康数据 |
| `user_chen` | 用户 | 预约 + 健康数据 |
| `user_zhao` | 用户 | 预约 + 健康数据 |

---

## 🚪 端口约定

| 端口 | 用途 |
|---|---|
| `3306` | MariaDB |
| `8090` | Backend (Spring Boot) |
| `5173` | Frontend (Vue 3 dist) |

冲突时用参数换:
```powershell
.\install.ps1 -DbPort 3307 -BackendPort 8091 -FrontendPort 5174
```

---

## 🛠️ 默认参数

| 参数 | 默认值 | 说明 |
|---|---|---|
| `-DbPassword` | `opck2026` | MariaDB root 密码 |
| `-DbPort` | `3306` | MariaDB 端口 |
| `-BackendPort` | `8090` | Backend 端口 |
| `-FrontendPort` | `5173` | Frontend 端口 |
| `-AutoResetRoot` | (无) | 密码错自动跑 5 步 reset |

---

## ✅ 前置依赖 (install.ps1 自动检测)

| 依赖 | 检测方法 | 没装怎么办 |
|---|---|---|
| Windows 管理员权限 | `[Security.Principal.WindowsPrincipal]` | 右键 PowerShell -> Run as administrator |
| MariaDB 11.x | 找 `C:\Program Files\MariaDB*\bin\mysql.exe` | https://mariadb.org/download/ |
| JDK 17+ | 找 `java.exe` | https://adoptium.net/ |
| Python 3.x | 找 `python.exe` (用于 frontend http server) | https://www.python.org/ |

---

## 🚨 故障排查 (5 条)

### 1. install.ps1 报 "root 密码错误"
```
[6/9] 探测 root 密码 ...
  试密码: <空> FAIL
  试密码: opck2026 FAIL
```
**修法**: 加 `-AutoResetRoot` 重跑：
```powershell
.\install.ps1 -AutoResetRoot
```

### 2. Backend port 8090 起不来
- `Get-NetTCPConnection -LocalPort 8090` 看谁在占
- `.\stop-all.ps1` 杀旧进程
- 用 `-BackendPort 8091` 换端口

### 3. Frontend 没显示 (port 5173 NOT LISTENING)
- 检查 Python: `python --version`
- 检查 dist 存在: `dir ..\..\frontend-pc\dist`

### 4. 登录页能开, 但 login 失败
- 看 Backend 日志: `Get-Content $env:TEMP\health-backend.log.err -Tail 30`
- 大概率是 DB 没连上 (MariaDB 没起 or 密码错)

### 5. reset-root-auto.ps1 失败
- 看日志: `$env:TEMP\mariadbd-reset.log.err`
- 大概率是 mariadbd 启动参数错 (datadir 路径不对)

---

## 🧹 完全卸载

```powershell
.\uninstall.ps1
# 默认 DROP health_management 库 + 删 jar + 删 dist
.\uninstall.ps1 -KeepDatabase   # 保留库
```

---

## 📚 学习资源

**OPC_K PowerShell 5.1 实战派学习手册 v4.1**:
- 本地: `~/.openclaw/agents/pm_jiaozi/skills/opck-powershell-5.1/SKILL.md`
- 网盘: `/apps/bdpan/learning/powershell-5.1-learning.zip`
- 内容: 8 段 (引号 / here-string / 路径 / Start-Process / 管道 / exit code / BOM / service)

---

## 📝 文件清单

```
deploy/windows/
├── install.ps1                # 一键部署 (含 -AutoResetRoot)
├── reset-root-auto.ps1        # 自动 5 步 reset (install 自动调)
├── reset-root-simple.sql      # root 改密 SQL (硬编码 hash)
├── reset-root-password.md     # 手动 5 步 reset 文档
├── stop-all.ps1               # 停服务
├── restart-all.ps1            # 重启
├── status.ps1                 # 看状态
├── uninstall.ps1              # 完全卸载
└── README.md                  # 本文件
```