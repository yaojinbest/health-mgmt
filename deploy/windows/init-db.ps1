# ============================================================================
#  init-db.ps1 - MariaDB / MySQL 一键初始化（健康管理系统 v3.1）
# ============================================================================
#
#  作用:
#    1. 测试 MariaDB 连接 (空密码自动转 -ResetRootPassword 流程)
#    2. 创建 health_management 库 (utf8mb4)
#    3. 导入 sql/init.sql (15 张表 + 6 用户 seed)
#
#  用法 (管理员 PowerShell):
#    PS> .\init-db.ps1                                      # 默认: 127.0.0.1:3306, 提示输入密码
#    PS> .\init-db.ps1 -DbPassword opck2026                 # 密码直接传 (跟 application.yml 一致)
#    PS> .\init-db.ps1 -ResetRootPassword                   # 强制走 --skip-grant-tables 流程 (重置 root 密码)
#    PS> .\init-db.ps1 -DbPort 3305                         # 端口不是 3306
#
#  2026-07-06 v3.1 升级:
#    - 加 -ResetRootPassword 开关 (解决 root 密码不知道/不一致问题)
#    - 默认行为: 测连接时若 1045 Access denied, 自动调用 --skip-grant-tables 流程重置
#    - 重置后, root@localhost + root@127.0.0.1 密码统一为 -DbPassword
#    - 加 CREATE USER root@127.0.0.1 (坑 #3 兜底)
#
#  OPC_K 部署 SOP (2026-07-06):
#    1. 文件加 UTF-8 BOM (本脚本已带)
#    2. sql 文件加 UTF-8 BOM (sql/init.sql 已带)
#    3. mysql 命令加 --default-character-set=utf8mb4 (本脚本已带)
#    4. 杀进程用 Get-Process + Stop-Process (PowerShell 原生 API, 不抛错)
#    5. 不用 < 重定向, 用 Get-Content | mysql 管道
#
#  历史踩坑 (2026-07-05/06):
#    - 默认端口从 3305 改为 3306 (跟 application.yml 对齐)
#    - password 不再走 $env:MYSQL_PWD (PowerShell 5.1 不生效), 改用参数
#    - 杀进程从 taskkill 改为 Get-Process (管道里 -ErrorAction 不生效)
#    - 加 --default-character-set=utf8mb4 (init.sql 中文注释不乱码)
#    - v3.1 加 -ResetRootPassword 兜底 (15:15 踩 here-string + 15:19 Access denied 沉淀)
# ============================================================================

[CmdletBinding()]
param(
    [string]$DbHost = "127.0.0.1",
    [int]$DbPort = 3306,
    [string]$DbName = "health_management",
    [string]$DbUser = "root",
    [string]$DbPassword = "",
    [string]$ProjectRoot = "..\..",
    [string]$MysqlPath = "",
    [switch]$ResetRootPassword
)

# UTF-8 BOM 必备
$ErrorActionPreference = "Continue"
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# ---- 路径定位 ----
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$InitSql = Join-Path (Resolve-Path $ProjectRoot) "sql/init.sql"
if (-not (Test-Path $InitSql)) {
    Write-Host "[FAIL] 找不到 sql/init.sql, 请确认 $InitSql 存在" -ForegroundColor Red
    exit 1
}

# ---- 找 mysql.exe (PATH → 常见安装位置) ----
$mysqlExe = ""
if ($MysqlPath -and (Test-Path $MysqlPath)) {
    $mysqlExe = (Get-MysqlItem) $MysqlPath
} else {
    try {
        $whereOut = & where.exe mysql 2>$null | Select-Object -First 1
        if ($whereOut -and (Test-Path $whereOut)) {
            $mysqlExe = (Get-Item $whereOut).FullName
        }
    } catch {}
    if (-not $mysqlExe) {
        $cmd = Get-Command mysql -ErrorAction SilentlyContinue
        if ($cmd) {
            $mysqlExe = if ($cmd.Source) { $cmd.Source } elseif ($cmd.Path) { $cmd.Path } else { "" }
            if ($mysqlExe -and -not (Test-Path $mysqlExe)) { $mysqlExe = "" }
        }
    }
    if (-not $mysqlExe) {
        $candidates = @(
            "C:\Program Files\MariaDB*\bin\mysql.exe",
            "C:\Program Files (x86)\MariaDB*\bin\mysql.exe",
            "C:\Program Files\MySQL\MySQL Server*\bin\mysql.exe",
            "D:\Program Files\MariaDB*\bin\mysql.exe"
        )
        foreach ($p in $candidates) {
            $found = Get-Item $p -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($found) { $mysqlExe = $found.FullName; break }
        }
    }
}
if (-not $mysqlExe) {
    Write-Host "[FAIL] 找不到 mysql.exe" -ForegroundColor Red
    Write-Host "  请确认 MariaDB / MySQL 已安装, 或用 -MysqlPath 指定" -ForegroundColor Yellow
    exit 1
}
Write-Host "mysql: $mysqlExe" -ForegroundColor Cyan
Write-Host "host:  $DbHost`:$DbPort" -ForegroundColor Cyan

# ---- 找 mariadbd.exe (--skip-grant-tables 用) ----
$mariadbdExe = ""
$mariadbdDir = Split-Path -Parent $mysqlExe
$candidatesMariadbd = @(
    (Join-Path $mariadbdDir "mariadbd.exe"),
    "C:\Program Files\MariaDB 11.8\bin\mariadbd.exe"
)
foreach ($p in $candidatesMariadbd) {
    if ($p -and (Test-Path $p)) { $mariadbdExe = (Get-Item $p).FullName; break }
}
if (-not $mariadbdExe) {
    Write-Host "[WARN] 找不到 mariadbd.exe, -ResetRootPassword 流程不可用" -ForegroundColor Yellow
    Write-Host "  (正常连接流程仍可走)" -ForegroundColor Gray
}

# ---- 找 MariaDB 服务名 (动态, 兼容多个版本) ----
$MariaService = $null
try {
    $svcList = & sc.exe query state= all 2>$null | Select-String "SERVICE_NAME:.*MariaDB" | ForEach-Object {
        if ($_ -match "SERVICE_NAME:\s*(\S+)") { $matches[1] }
    }
    if ($svcList) { $MariaService = $svcList | Select-Object -First 1 }
} catch {}
if (-not $MariaService) { $MariaService = "MariaDB" }  # 兜底

# ---- 密码处理 (不再走 $env:MYSQL_PWD) ----
if (-not $DbPassword) {
    $secure = Read-Host "请输入 $DbUser 密码 (留空跳过此提示, 改走重置流程)" -AsSecureString
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    $DbPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
}
# 留空 = 自动走 -ResetRootPassword
if (-not $DbPassword) {
    Write-Host "[INFO] 密码留空, 自动启用 -ResetRootPassword 流程" -ForegroundColor Cyan
    $ResetRootPassword = $true
    $DbPassword = "opck2026"  # 默认跟 application.yml 对齐
}
Write-Host "目标密码: ******** (留 -DbPassword 覆盖)" -ForegroundColor Gray

# ---- 测试连接 ----
Write-Host "测试数据库连接 $DbHost`:$DbPort ..." -ForegroundColor Cyan
$testOut = & $mysqlExe -h $DbHost -P "$DbPort" -u $DbUser -p$DbPassword --default-character-set=utf8mb4 -e "SELECT VERSION();" 2>&1
if ($LASTEXITCODE -ne 0) {
    # 1045 = Access denied → 自动走重置
    if ($testOut -match "1045" -or $testOut -match "Access denied") {
        if (-not $ResetRootPassword) {
            Write-Host "[WARN] Access denied. 自动启用 -ResetRootPassword 流程..." -ForegroundColor Yellow
            $ResetRootPassword = $true
        }
    } else {
        Write-Host "[FAIL] 连接失败:" -ForegroundColor Red
        $testOut | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
        Write-Host ""
        Write-Host "常见原因:" -ForegroundColor Yellow
        Write-Host "  1. MariaDB / MySQL 服务没起: Get-Service $MariaService" -ForegroundColor Gray
        Write-Host "  2. 端口不对: 试 -DbPort 3305 或 3306" -ForegroundColor Gray
        Write-Host "  3. 密码不对: 留空密码自动重置, 或 -ResetRootPassword 强制走" -ForegroundColor Gray
        exit 2
    }
} else {
    Write-Host "OK" -ForegroundColor Green
}

# ---- -ResetRootPassword 流程 (v3.1 新增) ----
if ($ResetRootPassword) {
    Write-Host ""
    Write-Host "==== 走 -ResetRootPassword 流程 ====" -ForegroundColor Cyan
    Write-Host "目标: 重置 $DbUser@localhost + $DbUser@127.0.0.1 密码为 -DbPassword" -ForegroundColor Gray

    if (-not $mariadbdExe) {
        Write-Host "[FAIL] mariadbd.exe 不存在, 无法走 --skip-grant-tables 流程" -ForegroundColor Red
        Write-Host "  请手动: 管理员命令行停 MariaDB 服务, 用 mysqld --skip-grant-tables 起, 跑 ALTER USER" -ForegroundColor Yellow
        exit 5
    }

    # 1) 停 MariaDB 服务
    Write-Host "1) 停 MariaDB 服务 ($MariaService)..." -ForegroundColor Cyan
    $svc = Get-Service -Name $MariaService -ErrorAction SilentlyContinue
    if ($svc) {
        if ($svc.Status -eq "Running") {
            Stop-Service -Name $MariaService -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 3
        }
        $svc2 = Get-Service -Name $MariaService -ErrorAction SilentlyContinue
        if ($svc2.Status -eq "Stopped") {
            Write-Host "  OK (已停)" -ForegroundColor Green
        } else {
            Write-Host "  [WARN] 服务没完全停, 尝试 Stop-Process..." -ForegroundColor Yellow
            $proc = Get-Process -Name mariadbd -ErrorAction SilentlyContinue
            if ($proc) { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue; Start-Sleep -Seconds 2 }
        }
    } else {
        Write-Host "  [WARN] 找不到服务 $MariaService, 尝试 Stop-Process mariadbd" -ForegroundColor Yellow
        $proc = Get-Process -Name mariadbd -ErrorAction SilentlyContinue
        if ($proc) { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue; Start-Sleep -Seconds 2 }
    }

    # 2) 启 mariadbd --skip-grant-tables --skip-networking (后台)
    Write-Host "2) 启 mariadbd --skip-grant-tables --skip-networking..." -ForegroundColor Cyan
    $dataDir = "C:\Program Files\MariaDB 11.8\data"
    if (-not (Test-Path $dataDir)) {
        $dataDir = (Get-ChildItem "C:\Program Files\MariaDB*" -Directory | Select-Object -First 1).FullName + "\data"
    }
    $grantLog = Join-Path $env:TEMP "mariadbd-grant.log"
    $grantArgs = "--skip-grant-tables --skip-networking --datadir=`"$dataDir`" --port=$DbPort"
    Write-Host "  datadir: $dataDir" -ForegroundColor Gray
    Write-Host "  log:     $grantLog" -ForegroundColor Gray
    $proc = Start-Process -FilePath $mariadbdExe -ArgumentList $grantArgs `
        -RedirectStandardOutput $grantLog -RedirectStandardError "$grantLog.err" `
        -WindowStyle Hidden -PassThru
    Start-Sleep -Seconds 5

    # 3) 连 (免密码) 改密码
    Write-Host "3) 连 mysql (免密码) 改密码..." -ForegroundColor Cyan
    $resetSql = @"
FLUSH PRIVILEGES;
ALTER USER '$DbUser'@'localhost' IDENTIFIED BY '$DbPassword';
CREATE USER IF NOT EXISTS '$DbUser'@'127.0.0.1' IDENTIFIED BY '$DbPassword';
CREATE USER IF NOT EXISTS '$DbUser'@'::1' IDENTIFIED BY '$DbPassword';
GRANT ALL ON *.* TO '$DbUser'@'127.0.0.1' WITH GRANT OPTION;
GRANT ALL ON *.* TO '$DbUser'@'::1' WITH GRANT OPTION;
FLUSH PRIVILEGES;
"@
    $resetOut = & $mysqlExe -h $DbHost -P "$DbPort" -u $DbUser --default-character-set=utf8mb4 -e $resetSql 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[FAIL] ALTER USER 失败:" -ForegroundColor Red
        $resetOut | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
        Write-Host "  残留进程: 需手动 Stop-Process mariadbd" -ForegroundColor Yellow
        exit 6
    }
    Write-Host "  OK" -ForegroundColor Green

    # 4) 停 mariadbd, 启回服务
    Write-Host "4) 停 mariadbd (skip-grant-tables)..." -ForegroundColor Cyan
    $proc2 = Get-Process -Name mariadbd -ErrorAction SilentlyContinue
    if ($proc2) {
        Stop-Process -Id $proc2.Id -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 3
    }
    Write-Host "  OK" -ForegroundColor Green

    Write-Host "5) 启回 MariaDB 服务 ($MariaService)..." -ForegroundColor Cyan
    Start-Service -Name $MariaService -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 3
    $svc3 = Get-Service -Name $MariaService -ErrorAction SilentlyContinue
    if ($svc3.Status -eq "Running") {
        Write-Host "  OK (服务起来了)" -ForegroundColor Green
    } else {
        Write-Host "  [WARN] 服务状态: $($svc3.Status), 手动启: Start-Service $MariaService" -ForegroundColor Yellow
    }

    # 5) 验证新密码能连
    Write-Host "6) 验证新密码能连..." -ForegroundColor Cyan
    $testOut2 = & $mysqlExe -h $DbHost -P "$DbPort" -u $DbUser -p$DbPassword --default-character-set=utf8mb4 -e "SELECT VERSION();" 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[FAIL] 新密码连不上:" -ForegroundColor Red
        $testOut2 | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
        exit 7
    }
    Write-Host "  OK" -ForegroundColor Green
    Write-Host "==== -ResetRootPassword 流程完成 ====" -ForegroundColor Cyan
    Write-Host ""
}

# ---- 跑 init.sql (UTF-8 BOM + utf8mb4) ----
Write-Host "跑 init.sql (DROP + CREATE + 15 表 + seed)..." -ForegroundColor Cyan
Get-Content $InitSql | & $mysqlExe -h $DbHost -P "$DbPort" -u $DbUser -p$DbPassword --default-character-set=utf8mb4 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "[FAIL] init.sql 跑失败, 退出码 $LASTEXITCODE" -ForegroundColor Red
    exit 3
}
Write-Host "OK" -ForegroundColor Green

# ---- 验证 ----
Write-Host "验证..." -ForegroundColor Cyan
$tables = & $mysqlExe -h $DbHost -P "$DbPort" -u $DbUser -p$DbPassword -N -B --default-character-set=utf8mb4 -e "USE $DbName; SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='$DbName';" 2>&1
$users = & $mysqlExe -h $DbHost -P "$DbPort" -u $DbUser -p$DbPassword -N -B --default-character-set=utf8mb4 -e "USE $DbName; SELECT COUNT(*) FROM sys_user;" 2>&1

Write-Host ""
Write-Host "==== 验证结果 ====" -ForegroundColor Green
Write-Host "表数: $tables (期望 15)" -ForegroundColor White
Write-Host "用户数: $users (期望 6)" -ForegroundColor White
Write-Host ""

if ($tables -eq 15 -and $users -eq 6) {
    Write-Host "[OK] 初始化完成! 演示账号:" -ForegroundColor Green
    Write-Host "   - 患者:    user_wang / root" -ForegroundColor White
    Write-Host "   - 医生:    doctor_zhang / root" -ForegroundColor White
    Write-Host "   - 管理员:  admin / root" -ForegroundColor White
    Write-Host ""
    Write-Host "下一步:" -ForegroundColor Cyan
    Write-Host "   cd $ScriptDir" -ForegroundColor White
    Write-Host "   .\start-backend.ps1" -ForegroundColor White
    Write-Host "   (新窗口) .\start-frontend-pc.ps1" -ForegroundColor White
} else {
    Write-Host "[WARN] 数量不对" -ForegroundColor Yellow
    exit 4
}
