﻿#Requires -RunAsAdministrator
<#
.SYNOPSIS
  init-db.ps1 - MariaDB 数据库初始化脚本 (health-mgmt v3.2)
.DESCRIPTION
  支持两种模式:
  1. 正常模式: 测连接, 跑 init.sql (DROP+CREATE+seed)
  2. -ResetRootPassword 模式: 破解/重置 MariaDB root 密码

  用法:
    .\init-db.ps1                          # 交互输入密码
    .\init-db.ps1 -DbPassword opck2026     # 直接指定密码
    .\init-db.ps1 -ResetRootPassword       # 强制走重置流程 (留空密码)
    .\init-db.ps1 -DbPassword opck2026 -ResetRootPassword  # 重置密码

.NOTES
  MariaDB 11.x Data Dictionary: mysql.user 是 VIEW, 不能直接 UPDATE/ALTER
  密码重置必须用 --init-file 在启动时执行
#>

param(
    [string]$DbPassword = "",
    [switch]$ResetRootPassword
)

# ---- 配置 ----
$DbHost = "127.0.0.1"
$DbPort = 3306
$DbUser = "root"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootDir   = (Get-Item $scriptDir).Parent.Parent
$InitSql   = Join-Path $rootDir "sql\init.sql"
$mariadbBase = "C:\Program Files\MariaDB 11.8"
$mariadbdExe = Join-Path $mariadbBase "bin\mariadbd.exe"
$mysqlExe    = Join-Path $mariadbBase "bin\mysql.exe"

if (-not (Test-Path $mysqlExe)) {
    $mariadbBase = (Get-ChildItem "C:\Program Files\MariaDB*" -Directory |
                    Where-Object { (Test-Path (Join-Path $_.FullName "bin\mariadbd.exe")) } |
                    Select-Object -First 1).FullName
    $mariadbdExe = Join-Path $mariadbBase "bin\mariadbd.exe"
    $mysqlExe    = Join-Path $mariadbBase "bin\mysql.exe"
}

# 默认密码
if (-not $DbPassword) {
    $secure = Read-Host "请输入 $DbUser 密码 (留空跳过此提示, 改走重置流程)" -AsSecureString
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    $DbPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    if (-not $DbPassword) {
        $DbPassword = "opck2026"
        Write-Host "[INFO] 密码留空, 自动启用 -ResetRootPassword 流程" -ForegroundColor Cyan
        $ResetRootPassword = $true
    }
}

Write-Host "mysql: $mysqlExe" -ForegroundColor Gray
Write-Host "host:  $DbHost`:$DbPort" -ForegroundColor Gray
Write-Host "目标密码: ******** (留 -DbPassword 覆盖)" -ForegroundColor Gray

# ---- 找 MariaDB 服务名 (动态, 兼容多个版本) ----
$MariaService = $null
try {
    $svcList = & sc.exe query state= all 2>$null | Select-String "SERVICE_NAME:.*MariaDB" | ForEach-Object {
        if ($_ -match "SERVICE_NAME:\s*(\S+)") { $matches[1] }
    }
    if ($svcList) { $MariaService = $svcList | Select-Object -First 1 }
} catch {}
if (-not $MariaService) { $MariaService = "MariaDB" }

# ---- 测试连接 ----
Write-Host "测试数据库连接 $DbHost`:$DbPort ..." -ForegroundColor Cyan
$testOut = & $mysqlExe -h $DbHost -P "$DbPort" -u $DbUser -p$DbPassword --default-character-set=utf8mb4 -e "SELECT VERSION();" 2>&1
if ($LASTEXITCODE -ne 0) {
    if ($testOut -match "1045" -or $testOut -match "Access denied") {
        if (-not $ResetRootPassword) {
            Write-Host "[WARN] Access denied. 自动启用 -ResetRootPassword 流程..." -ForegroundColor Yellow
            $ResetRootPassword = $true
        }
    } elseif ($testOut -match "10061" -or $testOut -match "Can't connect" -or $testOut -match "Connection refused") {
        if (-not $ResetRootPassword) {
            Write-Host "[WARN] 服务没起 (10061), 自动启用 -ResetRootPassword 流程 (会启 mariadbd)..." -ForegroundColor Yellow
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

# ---- -ResetRootPassword 流程 (v3.2 重写, 用 --init-file) ----
if ($ResetRootPassword) {
    Write-Host ""
    Write-Host "==== 走 -ResetRootPassword 流程 ====" -ForegroundColor Cyan
    Write-Host "目标: 重置 $DbUser@localhost + $DbUser@127.0.0.1 密码为 -DbPassword" -ForegroundColor Gray
    Write-Host "方式: --init-file (MariaDB 11.x Data Dictionary VIEW 修复)" -ForegroundColor Gray

    if (-not $mariadbdExe) {
        Write-Host "[FAIL] mariadbd.exe 不存在, 无法走重置流程" -ForegroundColor Red
        exit 5
    }

    # 1) 强杀所有 mariadbd/mysqld/mysql 进程
    Write-Host "1) 强杀所有 mariadbd/mysqld/mysql 进程..." -ForegroundColor Cyan
    $svc = Get-Service -Name $MariaService -ErrorAction SilentlyContinue
    if ($svc -and $svc.Status -eq "Running") {
        Stop-Service -Name $MariaService -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
    }
    foreach ($name in @("mariadbd.exe", "mysqld.exe", "mysql.exe")) {
        $killOut = & taskkill.exe /F /IM $name /T 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  OK (taskkill 杀 $name)" -ForegroundColor Green
        }
    }
    Start-Sleep -Seconds 3

    # 端口验证
    $portBusy = Get-NetTCPConnection -LocalPort $DbPort -State Listen -ErrorAction SilentlyContinue
    if ($portBusy) {
        $pids = $portBusy.OwningProcess | Sort-Object -Unique
        Write-Host "  端口 $DbPort 仍被占 (PID: $($pids -join ',')), 按 PID 强杀..." -ForegroundColor Yellow
        foreach ($pid in $pids) {
            $procName = (Get-Process -Id $pid -ErrorAction SilentlyContinue).ProcessName
            Write-Host "    PID $pid = $procName" -ForegroundColor Gray
            & taskkill.exe /F /PID $pid /T 2>&1 | Out-Null
        }
        Start-Sleep -Seconds 3
    }
    $portBusy2 = Get-NetTCPConnection -LocalPort $DbPort -State Listen -ErrorAction SilentlyContinue
    if ($portBusy2) {
        $pids2 = $portBusy2.OwningProcess | Sort-Object -Unique
        $procs2 = $pids2 | ForEach-Object { "PID $_ = $((Get-Process -Id $_ -EA SilentlyContinue).ProcessName)" }
        Write-Host "  [FAIL] 端口 $DbPort 仍被占: $($procs2 -join '; ')" -ForegroundColor Red
        exit 8
    }
    Write-Host "  OK (端口 $DbPort 空闲)" -ForegroundColor Green

    # 2) 找 datadir
    $dataDir = "C:\Program Files\MariaDB 11.8\data"
    if (-not (Test-Path $dataDir)) {
        $candidates = Get-ChildItem "C:\Program Files\MariaDB*" -Directory -ErrorAction SilentlyContinue
        if ($candidates) {
            $dataDir = $candidates[0].FullName + "\data"
        }
    }
    Write-Host "2) datadir: $dataDir" -ForegroundColor Gray

    # 3) 写 init 文件 (UTF-8 NO BOM, ASCII 注释, ALTER USER 改密码)
    # MariaDB 11.x: mysql.user 是 Data Dictionary VIEW, 不能 UPDATE
    # 但 --init-file 在启动时执行, 此时 server 层还没完全初始化 DD VIEW
    # 所以 ALTER USER 在 init-file 里可以工作
    # 关键: 不加 BOM (否则 Windows GBK 读会乱码), 不用中文注释
    $initFile = Join-Path $env:TEMP "mariadb-init-password.sql"
    $initContent = @"
-- MariaDB 11.x password reset (--init-file mode)
-- File is read as UTF-8 by mariadbd (--character-set-server=utf8mb4)
ALTER USER '$DbUser'@'localhost' IDENTIFIED BY '$DbPassword';
ALTER USER '$DbUser'@'127.0.0.1' IDENTIFIED BY '$DbPassword';
ALTER USER '$DbUser'@'::1' IDENTIFIED BY '$DbPassword';
FLUSH PRIVILEGES;
SELECT 'PASSWORD_RESET_OK' AS status;
"@
    # PowerShell 5.1 写文件: UTF-8 NO BOM (BOM 会被 Windows GBK 读成乱码)
    $utf8NoBOM = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($initFile, $initContent, $utf8NoBOM)
    Write-Host "3) init-file: $initFile (UTF-8 NO BOM)" -ForegroundColor Gray

    # 4) 用 --init-file 启动 mariadbd (后台, 等待启动完成)
    Write-Host "4) 启 mariadbd --init-file (后台启动, 等 SQL 执行完)..." -ForegroundColor Cyan
    $initLog = Join-Path $env:TEMP "mariadbd-init.log"
    $initArgs = "--init-file=`"$initFile`" --datadir=`"$dataDir`" --port=$DbPort --character-set-server=utf8mb4 --character-set-filesystem=utf8mb4 --console"
    Write-Host "  log: $initLog" -ForegroundColor Gray
    Write-Host "  args: $initArgs" -ForegroundColor Gray
    $proc = Start-Process -FilePath $mariadbdExe -ArgumentList $initArgs `
        -RedirectStandardOutput $initLog -RedirectStandardError "$initLog.err" `
        -WindowStyle Hidden -PassThru
    Write-Host "  PID: $($proc.Id)" -ForegroundColor Gray

    # 等 mariadbd 启动 + 执行 init-file (需要等待 SQL 完成)
    Write-Host "  等 mariadbd 启动 + 执行 init-file SQL (15s)..." -ForegroundColor Cyan
    Start-Sleep -Seconds 15

    # 检查 init log 是否有 PASSWORD_RESET_OK
    if (Test-Path $initLog) {
        $initContent2 = Get-Content $initLog -Raw -ErrorAction SilentlyContinue
        if ($initContent2 -match "PASSWORD_RESET_OK") {
            Write-Host "  [OK] init-file SQL 执行成功 (找到 PASSWORD_RESET_OK)" -ForegroundColor Green
        } elseif ($initContent2) {
            Write-Host "  init-log 内容:" -ForegroundColor Gray
            Get-Content $initLog | Select-Object -First 20 | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
        }
        if (Test-Path "$initLog.err") {
            $initErr = Get-Content "$initLog.err" -Raw -ErrorAction SilentlyContinue
            if ($initErr -match "ERROR|error") {
                Write-Host "  init-log stderr 有 ERROR:" -ForegroundColor Red
                Get-Content "$initLog.err" | Select-Object -First 10 | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
            }
        }
    } else {
        Write-Host "  [WARN] init log 文件不存在" -ForegroundColor Yellow
    }

    # 5) 验证密码改了
    Write-Host "5) 验证新密码能连..." -ForegroundColor Cyan
    $testPwd = & $mysqlExe -h $DbHost -P "$DbPort" -u $DbUser -p$DbPassword --default-character-set=utf8mb4 -e "SELECT VERSION();" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [OK] 新密码 opck2026 能连: $($testPwd -join ' ')" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] 新密码验证失败: $($testPwd -join ' ')" -ForegroundColor Red
        Write-Host "  init-log 最后 30 行:" -ForegroundColor Gray
        if (Test-Path $initLog) {
            Get-Content $initLog -Tail 30 | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
        }
        Write-Host "  init-log stderr 最后 30 行:" -ForegroundColor Gray
        if (Test-Path "$initLog.err") {
            Get-Content "$initLog.err" -Tail 30 | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
        }
        # 清理
        & taskkill.exe /F /IM mariadbd.exe /T 2>$null | Out-Null
        Remove-Item $initFile -ErrorAction SilentlyContinue
        exit 7
    }

    # 6) SHUTDOWN 干净停
    Write-Host "6) SHUTDOWN 干净停 mariadbd..." -ForegroundColor Cyan
    $shutdownOut = & $mysqlExe -h $DbHost -P "$DbPort" -u $DbUser -p$DbPassword --default-character-set=utf8mb4 -e "SHUTDOWN;" 2>&1
    Start-Sleep -Seconds 5
    & taskkill.exe /F /IM mariadbd.exe /T 2>$null | Out-Null
    Write-Host "  OK" -ForegroundColor Green
    Remove-Item $initFile -ErrorAction SilentlyContinue

    # 7) 启回 MariaDB 服务
    Write-Host "7) 启回 MariaDB (优先 Start-Service, 失败则 mariadbd.exe 直接启)..." -ForegroundColor Cyan
    $serviceStarted = $false
    $svc3 = Get-Service -Name $MariaService -ErrorAction SilentlyContinue
    if ($svc3) {
        Start-Service -Name $MariaService -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 3
        $svc3 = Get-Service -Name $MariaService -ErrorAction SilentlyContinue
        if ($svc3.Status -eq "Running") {
            $portNow = Get-NetTCPConnection -LocalPort $DbPort -State Listen -ErrorAction SilentlyContinue
            if ($portNow) {
                Write-Host "  OK (服务起来了, 端口 $DbPort 监听)" -ForegroundColor Green
                $serviceStarted = $true
            }
        }
    }
    if (-not $serviceStarted) {
        Write-Host "  启 mariadbd.exe (直接启, zip 安装场景)..." -ForegroundColor Cyan
        $normalLog = Join-Path $env:TEMP "mariadbd-normal.log"
        $normalArgs = "--datadir=`"$dataDir`" --port=$DbPort --console"
        $procN = Start-Process -FilePath $mariadbdExe -ArgumentList $normalArgs `
            -RedirectStandardOutput $normalLog -RedirectStandardError "$normalLog.err" `
            -WindowStyle Hidden -PassThru
        Start-Sleep -Seconds 6
        $portNow2 = Get-NetTCPConnection -LocalPort $DbPort -State Listen -ErrorAction SilentlyContinue
        if ($portNow2) {
            Write-Host "  OK (mariadbd.exe 在端口 $DbPort 监听)" -ForegroundColor Green
        } else {
            Write-Host "  [FAIL] mariadbd 启不起来, 看 log: $normalLog.err" -ForegroundColor Red
            if (Test-Path "$normalLog.err") {
                Get-Content "$normalLog.err" -Tail 20 | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
            }
            exit 10
        }
    }

    # 8) 最终验证
    Write-Host "8) 最终验证新密码能连..." -ForegroundColor Cyan
    $finalTest = & $mysqlExe -h $DbHost -P "$DbPort" -u $DbUser -p$DbPassword --default-character-set=utf8mb4 -e "SELECT VERSION();" 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[FAIL] 最终验证失败: $($finalTest -join ' ')" -ForegroundColor Red
        exit 7
    }
    Write-Host "  OK: $($finalTest -join ' ')" -ForegroundColor Green
    Write-Host "==== -ResetRootPassword 流程完成 ====" -ForegroundColor Cyan
    Write-Host ""
}

# ---- 跑 init.sql (UTF-8 BOM + utf8mb4) ----
if (-not (Test-Path $InitSql)) {
    Write-Host "[FAIL] init.sql 不存在: $InitSql" -ForegroundColor Red
    exit 4
}
Write-Host "跑 init.sql (DROP + CREATE + 15 表 + seed)..." -ForegroundColor Cyan
Get-Content $InitSql -Encoding UTF8 | & $mysqlExe -h $DbHost -P "$DbPort" -u $DbUser -p$DbPassword --default-character-set=utf8mb4 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "[FAIL] init.sql 跑失败, 退出码 $LASTEXITCODE" -ForegroundColor Red
    exit 3
}
Write-Host "OK" -ForegroundColor Green
Write-Host ""
Write-Host "==== 初始化完成 ====" -ForegroundColor Cyan
Write-Host "  后端启动: .\start-backend.ps1" -ForegroundColor Gray
Write-Host "  PC Web  : .\start-frontend-pc.ps1" -ForegroundColor Gray
