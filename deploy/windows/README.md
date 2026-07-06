# 健康管理系统 - 部署指南 (v4.0)

## 一键部署 (3 步)

```powershell
# 1. 用管理员 PowerShell 打开
# 2. cd 到 deploy/windows/
cd C:\path\to\health-mgmt\deploy\windows

# 3. 跑 install.ps1
.\install.ps1
```

跑完会输出:
- Frontend URL: `http://localhost:5173`
- Backend URL: `http://localhost:8090/api`
- 6 角色账号 (密码统一 `root`)

## 5 个脚本 (deploy/windows/)

| 脚本 | 用途 |
|---|---|
| `install.ps1` | **一键部署** (装环境 + 初始化库 + 启动 backend + 启动 frontend) |
| `stop-all.ps1` | 停 backend + frontend (不动 MariaDB) |
| `restart-all.ps1` | stop + 重新 install |
| `status.ps1` | 看服务状态 (MariaDB + Backend + Frontend) |
| `uninstall.ps1` | 完全卸载 (杀进程 + DROP 库 + 删 jar + 删 dist) |

## 6 角色账号 (密码统一 `root`)

| 账号 | 角色 | 权限 |
|---|---|---|
| `admin` | 管理员 | 全权限 |
| `doctor_zhang` | 医生 | 接诊 + 处方 |
| `doctor_li` | 医生 | 接诊 + 处方 |
| `user_wang` | 用户 | 预约 + 健康数据 |
| `user_chen` | 用户 | 预约 + 健康数据 |
| `user_zhao` | 用户 | 预约 + 健康数据 |

## 端口约定

| 端口 | 用途 |
|---|---|
| `3306` | MariaDB |
| `8090` | Backend (Spring Boot) |
| `5173` | Frontend (Vue 3 dist) |

如果端口冲突, 用参数换:
```powershell
.\install.ps1 -DbPort 3307 -BackendPort 8091 -FrontendPort 5174
```

## 默认参数

| 参数 | 默认值 | 说明 |
|---|---|---|
| `-DbPassword` | `opck2026` | MariaDB root 密码 (跟 application.yml 一致) |
| `-DbPort` | `3306` | MariaDB 端口 |
| `-BackendPort` | `8090` | Backend 端口 |
| `-FrontendPort` | `5173` | Frontend 端口 |

## 前置依赖 (install.ps1 会自动检测)

| 依赖 | 检测方法 | 没装怎么办 |
|---|---|---|
| Windows 管理员权限 | `[Security.Principal.WindowsPrincipal]` | 右键 PowerShell -> Run as administrator |
| MariaDB 11.x | 找 `C:\Program Files\MariaDB*\bin\mysql.exe` | https://mariadb.org/download/ |
| JDK 17+ | 找 `java.exe` | https://adoptium.net/ |
| Python 3.x | 找 `python.exe` (用于 frontend http server) | https://www.python.org/ |

## 故障排查 (5 条)

### 1. install.ps1 报 "root 密码错误"
- 看是不是 MariaDB 没起 → 跑 `net start MariaDB`
- 看是不是 root 密码不是 opck2026 → 跑 `reset-root-password.md` 5 步法

### 2. Backend 端口 8090 起不来
- `Get-NetTCPConnection -LocalPort 8090` 看谁在占
- `.\stop-all.ps1` 杀旧进程
- 用 `-BackendPort 8091` 换端口

### 3. Frontend 没显示 (port 5173 NOT LISTENING)
- 检查 Python: `python --version`
- 检查 dist 存在: `dir ..\..\frontend-pc\dist`

### 4. 登录页能开, 但 login 失败
- 检查 Backend 日志: `Get-Content $env:TEMP\health-backend.log.err -Tail 30`
- 大概率是 DB 没连上 (MariaDB 没起 or 密码错)

### 5. 浏览器跨域 (CORS)
- Backend `CorsConfig.java` 默认允许所有 origin
- 真要部署生产, 改 `application.yml` 的 `cors.allowed-origins`

## 完全卸载

```powershell
.\uninstall.ps1
# 默认会 DROP health_management 库 + 删 jar + 删 dist
# 加 -KeepDatabase 保留数据库
.\uninstall.ps1 -KeepDatabase
```

## 文件清单 (deploy/windows/)

```
install.ps1            # 一键部署 (12 KB)
stop-all.ps1           # 停服务 (1.5 KB)
restart-all.ps1        # 重启 (0.7 KB)
status.ps1             # 看状态 (2.3 KB)
uninstall.ps1          # 完全卸载 (3.2 KB)
reset-root-password.md # root 密码重置 (3.5 KB)
README.md              # 本文件
```