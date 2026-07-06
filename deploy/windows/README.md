# 健康管理系统 - Windows 部署文档 (v3.0)

> 学生实践项目 · 二次开发定制版 · OPC_K PowerShell 5.1 + MariaDB 11.x 全套踩坑沉淀

---

## 重要:本版本踩坑沉淀 (2026-07-06)

**8 个真机坑全部已修, 部署本项目不会再踩**。本 README 包含完整原因 + 解决方案 + 复现路径。

| # | 坑 | 症状 | 永久方案 |
|---|---|---|---|
| 1 | PowerShell 5.1 ps1 缺 UTF-8 BOM | 中文注释乱码 `鏉€ java 杩涚▼` | 所有 ps1 文件都加 UTF-8 BOM |
| 2 | application.yml 空密码 | MariaDB 11.x + Connector/J 8.x JDBC 失败 | 设明确密码 `opck2026` |
| 3 | MariaDB root@127.0.0.1 没设 | 客户端连上但 JDBC 连不上 | `CREATE USER root@127.0.0.1 IDENTIFIED BY 'pwd'` |
| 4 | printStackTrace 走 stderr | backend.log 看不到任何 ERROR | 用 `@Slf4j` + `log.error("msg", exception)` |
| 5 | PowerShell 5.1 不支持 `<` 重定向 | `RedirectionNotSupported` | `Get-Content file \| cmd` 管道 |
| 6 | init.sql 缺 UTF-8 BOM | 管道读时中文变 `???` | init.sql 加 UTF-8 BOM |
| 7 | fix-db.ps1 缺 UTF-8 BOM | 中文输出乱码 | ps1 都加 UTF-8 BOM |
| 8 | `-ErrorAction` 在管道里失效 | taskkill 抛错终止脚本 | 用 `Get-Process` + `Stop-Process` |

---

## 项目概况

| 项 | 内容 |
|---|---|
| **项目名** | 健康管理系统 (health-management) |
| **后端** | Spring Boot 3.3.5 + MyBatis-Plus 3.5.9 + JDK 17 |
| **前端 PC Web** | Vue 3 + Vite 6 + Element Plus + ECharts 5 |
| **数据库** | MySQL 8+ / MariaDB 10.6+ |
| **Android** | Kotlin + ViewBinding + Material 3 (独立 APK) |
| **默认端口** | 后端 `8090` / PC Web `5174` / 数据库 `3306` |
| **演示账号** | 患者 `user_wang / root` · 医生 `doctor_zhang / root` · 管理员 `admin / root` |
| **演示数据** | 15 张表 + 6 个用户 (admin/doctor_zhang/doctor_li/user_wang/user_chen/user_zhao) |

> 🔔 **端口**: 本项目用 `3306` (默认 MariaDB 端口, 跟 application.yml 对齐)。如有冲突, 改 `application.yml`。
>
> 🔔 **v3.0 变更**: 端口从 3305 → 3306, 默认密码从空 → `opck2026` (application.yml 一致), 8 个真机坑永久修复。

---

## 系统要求

| 软件 | 最低版本 | 推荐版本 |
|---|---|---|
| 操作系统 | Windows 10/11 | Windows 11 |
| JDK | 17 (LTS) | 17.0.19+ |
| Node.js | 18 LTS | 20 LTS |
| MariaDB | 10.6 | 11.4+ (或 MySQL 8.0+) |
| NSSM | 2.24 | 2.24 (服务化用) |

---

## 部署包目录结构

```
健康管理系统/
├── frontend-pc/                          # PC Web 源码
├── src/                                  # 后端源码
├── sql/
│   └── init.sql                          # ⭐ 15 张表 + 6 用户 (已加 UTF-8 BOM)
├── target/
│   └── health-management-1.0.0.jar       # ⭐ 编译产物 (含 log.error 修复)
├── deploy/
│   └── windows/                          # ⭐ 部署脚本
│       ├── init-db.ps1                   #   数据库初始化 (端口默认 3306, 提示密码)
│       ├── start-backend.ps1             #   启动后端 (杀旧 java + 端口检测)
│       ├── start-frontend-pc.ps1         #   启动 PC Web
│       ├── install-services.ps1          #   注册 Windows 服务
│       ├── uninstall-services.ps1        #   卸载服务
│       ├── smoke-test.ps1                #   端到端验证
│       └── README.md                     #   本文件
```

---

## 快速上手 (5 分钟)

### 步骤 1: 装环境

- JDK 17 (Eclipse Temurin): https://adoptium.net/temurin/releases/?version=17
- MariaDB 11.x: https://mariadb.org/download/ (安装时端口用 3306, 密码用 `opck2026` 或自定义)
- Node.js 20 LTS: https://nodejs.org/

> ⚠️ **必须给 MariaDB 设密码, 不能用空密码** (坑 #2)。
> ⚠️ **MariaDB root@localhost 和 root@127.0.0.1 必须都设密码** (坑 #3)。

```sql
-- 在 MariaDB 客户端跑 (管理员):
ALTER USER 'root'@'localhost' IDENTIFIED BY 'opck2026';
CREATE USER IF NOT EXISTS 'root'@'127.0.0.1' IDENTIFIED BY 'opck2026';
CREATE USER IF NOT EXISTS 'root'@'::1' IDENTIFIED BY 'opck2026';
GRANT ALL ON *.* TO 'root'@'127.0.0.1' WITH GRANT OPTION;
FLUSH PRIVILEGES;
```

### 步骤 2: 初始化数据库

```powershell
cd 健康管理系统\deploy\windows
.\init-db.ps1
```

**预期输出**:
```
mysql: C:\Program Files\MariaDB 11.8\bin\mysql.exe
host:  127.0.0.1:3306
请输入 root 密码: ********
测试数据库连接 127.0.0.1:3306 ...
OK
跑 init.sql (DROP + CREATE + 15 表 + seed)...
OK
==== 验证结果 ====
表数: 15 (期望 15)
用户数: 6 (期望 6)

[OK] 初始化完成! 演示账号:
   - 患者:    user_wang / root
   - 医生:    doctor_zhang / root
   - 管理员:  admin / root
```

### 步骤 3: 启动后端

```powershell
.\start-backend.ps1
```

等看到:
```
Tomcat started on port 8090 (http)
Started HealthManagementApplication in 3.5 seconds
```

### 步骤 4: 启动 PC Web (新窗口)

```powershell
.\start-frontend-pc.ps1
```

等看到:
```
  ➜  Local:   http://localhost:5174/
```

### 步骤 5: 浏览器登录

打开 http://localhost:5174/ 登录 `admin / root`

### 步骤 6: 端到端验证

```powershell
.\smoke-test.ps1
```

**预期**:
```
==== 总结 ====
  PASS: 3
  FAIL: 0
```

---

## 注册为 Windows 后台服务 (可选)

```powershell
# 管理员 PowerShell
.\install-services.ps1

# 卸载
.\uninstall-services.ps1
```

服务管理:
```powershell
sc query HealthMgmtBackend
sc start HealthMgmtBackend
sc stop HealthMgmtBackend
Get-Content deploy\windows\logs\backend.out.log -Wait
```

---

## 故障排查 (OPC_K 真机坑沉淀, 8 大常见)

### 8.1 ⭐ backend.log 看不到任何 ERROR, web 报 "Failed to obtain JDBC Connection"
**坑 #4**: `GlobalExceptionHandler` 用 `printStackTrace()`, 走 System.err, logback 没接管
**修复** (本项目已修): 用 `@Slf4j` + `log.error("msg", exception)`
**验证**:
```powershell
# 触发 login 后:
Get-Content deploy\windows\logs\backend.log -Tail 30
# 应该看到完整 stack trace (Caused by: ...)
```

### 8.2 启动报 "Communications link failure"
**坑 #2**: MariaDB 密码错 (空密码 JDBC handshake 失败)
**修复**:
- 改 `application.yml` 明确密码: `password: opck2026`
- 重打 jar: `$env:JAVA_HOME='C:\jdk-17'; mvn package -DskipTests`

### 8.3 ⭐ 启动报 "Unknown database 'health_management'" 或 "Table 'sys_user' doesn't exist"
**坑 #3**: root@127.0.0.1 没设密码 / 没授权, init-db 没成功
**修复**:
```powershell
# 跑 init-db (会自动 DROP + CREATE + 导入)
.\init-db.ps1
```

### 8.4 ⭐ PowerShell 5.1 报 "字符串缺少终止符" / 中文乱码
**坑 #1 + #7**: ps1 / init.sql 缺 UTF-8 BOM
**修复** (本项目已修): 所有 ps1 + init.sql 都加了 UTF-8 BOM
**应急**:
```powershell
# 改控制台代码页
chcp 65001
# 重新跑
```

### 8.5 ⭐ init-db 报 "<"运算符是为将来使用而保留的
**坑 #5**: PowerShell 5.1 不支持 `<` 重定向 (那是 cmd/bash 语法)
**修复** (本项目已修): init-db.ps1 用 `Get-Content | mysql` 管道
**应急**:
```powershell
Get-Content D:\health-mgmt\sql\init.sql | & "C:\Program Files\MariaDB 11.8\bin\mysql.exe" -h 127.0.0.1 -P 3306 -uroot -popck2026 --default-character-set=utf8mb4
```

### 8.6 ⭐ init.sql 跑过但 CREATE TABLE 全报 1064 语法错, 中文变 ???
**坑 #6**: init.sql 缺 UTF-8 BOM, 管道读时中文变乱码
**修复** (本项目已修): init.sql 加 UTF-8 BOM, mysql 加 `--default-character-set=utf8mb4`
**验证 init.sql 是否有 BOM**:
```powershell
# PowerShell
[System.IO.File]::ReadAllBytes("D:\health-mgmt\sql\init.sql")[0..2] | %{[BitConverter]::ToString($_)}
# 应该看到 EF-BB-BF
```

### 8.7 taskkill 报 "process not found" 终止脚本
**坑 #8**: `-ErrorAction` 在管道里只对 Out-Null 生效, taskkill 自己抛错
**修复** (本项目已修): 用 `Get-Process` + `Stop-Process` PowerShell 原生 API
**参考**:
```powershell
$javaproc = Get-Process -Name java -ErrorAction SilentlyContinue
if ($javaproc) { Stop-Process -Id $javaproc.Id -Force }
```

### 8.8 启动报 "Port 8090 was already in use"
**原因**: 之前的 java 进程没结束
**修复** (本项目已修): start-backend.ps1 自动杀旧 java 进程
**手动**:
```powershell
Get-NetTCPConnection -LocalPort 8090 -State Listen
# 找到 PID 后
Stop-Process -Id <PID> -Force
```

---

## OPC_K PowerShell 5.1 部署 SOP (永久)

| 规则 | 说明 |
|---|---|
| 1. 所有 ps1 必须 UTF-8 BOM | `printf '\xef\xbb\xbf' \| cat - file > file.bom && mv file.bom file` |
| 2. sql 文件必须 UTF-8 BOM | 同上, 缺了管道读时中文乱码 |
| 3. mysql 命令必须加 `--default-character-set=utf8mb4` | 否则即使有 BOM, mysql 也按错编码解析 |
| 4. 不用 `<` 重定向 | PowerShell 5.1 不支持, 用 `Get-Content \| cmd` |
| 5. 杀进程用 `Get-Process` + `Stop-Process` | PowerShell 原生, 不抛错 |
| 6. 杀进程不用 `taskkill \| Out-Null -ErrorAction SilentlyContinue` | -ErrorAction 只对 Out-Null 生效, taskkill 抛错仍终止 |
| 7. 不用 `$env:MYSQL_PWD` | PowerShell 5.1 这个变量不可靠, 改用参数 `Read-Host -AsSecureString` |
| 8. 默认端口跟 application.yml 一致 | 别 3305/3306 混用, 文档说啥就用啥 |
| 9. 错误日志必须用 `log.error("msg", exception)` | `printStackTrace()` 走 stderr, logback 没接管 |

---

## 修订记录

- **v3.0** (2026-07-06): 8 个真机坑永久修复
  - 端口默认 3306 (跟 application.yml 对齐)
  - 密码明确 opck2026
  - init.sql 加 UTF-8 BOM
  - 所有 ps1 加 UTF-8 BOM + Get-Process 杀进程 + 端口检测
  - GlobalExceptionHandler 用 log.error
  - 端到端冒烟测试脚本 (smoke-test.ps1)
  - 部署 SOP 永久沉淀
- **v2.0** (2026-07-06): 移除 H5 前端, 仅保留 PC Web
- **v1.0** (2026-07-05): 初始版本

---

🎓 **学生项目答辩备注**:
- 启动只需 3 步: init-db → start-backend → start-frontend-pc
- 浏览器登录 admin / root
- 服务化可选: install-services.ps1
- Android 客户端独立 APK, 不依赖 PC
- 演示账号已含 seed (user_wang/root 等)
