#Requires -RunAsAdministrator
<#
.SYNOPSIS
  install.ps1 - 健康管理系统一键部署 (health-mgmt)
.DESCRIPTION
  1 个脚本搞定:
    1. 检测环境 (MariaDB + Java + Node)
    2. 启动 MariaDB (前台跑, 单独窗口)
    3. 初始化 health_management 库 (DROP + CREATE + 15 表 + 种子)
    4. 启动后端 jar (后台, 隐藏窗口)
    5. 启动前端 (后台, 隐藏窗口, http.server 模式 serve dist/)
    6. 健康检查 + 输出访问 URL

  用法 (管理员 PowerShell):
    PS> cd C:\path\to\health-mgmt\deploy\windows
    PS> .\install.ps1
    PS> .\install.ps1 -DbPassword opck2026
    PS> .\install.ps1 -DbPassword opck2026 -BackendPort 8090 -FrontendPort 5173

  不依赖 NSSM, 进程用 Start-Process -WindowStyle Hidden 后台跑
  关闭窗口也不停 (除非手动 stop-all.ps1)
.NOTES
  v4.0 全新重写 (2026-07-06 21:35):
    - 极简 1 个 install.ps1 全部搞定
    - 不依赖 NSSM
    - 后台进程用 Start-Process -WindowStyle Hidden 启动
    - 端口冲突自动检查 + 友好提示
#>

[CmdletBinding()]
param(
    [string]$DbHost = "127.0.0.1",
    [int]$DbPort = 3306,
    [string]$DbName = "health_management",
    [string]$DbUser = "root",
    [string]$DbPassword = "opck2026",
    [int]$BackendPort = 8090,
    [int]$FrontendPort = 5173,
    [string]$ProjectRoot = "..\.."
)

# ---- UTF-8 全局 ----
$ErrorActionPreference = "Stop"
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# ---- 路径定位 ----
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ResolvedRoot = (Resolve-Path $ProjectRoot).Path
$JarPath = Join-Path $ResolvedRoot "target\health-management-1.0.0.jar"
$DistPath = Join-Path $ResolvedRoot "frontend-pc\dist"
$InitSql = Join-Path $ResolvedRoot "sql\init.sql"

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  健康管理系统 一键部署 v4.0" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Project root: $ResolvedRoot" -ForegroundColor Gray
Write-Host "Backend jar:  $JarPath" -ForegroundColor Gray
Write-Host "Frontend dist: $DistPath" -ForegroundColor Gray
Write-Host "Init SQL:     $InitSql" -ForegroundColor Gray
Write-Host ""

# ---- 1. 检测管理员权限 ----
Write-Host "[1/7] 检测管理员权限 ..." -ForegroundColor Cyan
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "  [FAIL] 请用管理员 PowerShell 跑 (右键 PowerShell -> Run as administrator)" -ForegroundColor Red
    exit 1
}
Write-Host "  OK" -ForegroundColor Green

# ---- 2. 检测 MariaDB ----
Write-Host "[2/7] 检测 MariaDB ..." -ForegroundColor Cyan
$mariadbBin = ""
$candidates = @(
    "C:\Program Files\MariaDB*\bin\mysql.exe",
    "C:\Program Files (x86)\MariaDB*\bin\mysql.exe",
    "D:\Program Files\MariaDB*\bin\mysql.exe"
)
foreach ($p in $candidates) {
    $found = Get-Item $p -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) { $mariadbBin = Split-Path -Parent $found.FullName; break }
}
if (-not $mariadbBin) {
    Write-Host "  [FAIL] 找不到 MariaDB" -ForegroundColor Red
    Write-Host "  请先安装: https://mariadb.org/download/" -ForegroundColor Yellow
    Write-Host "  安装时记住 root 密码, 后面会用 -DbPassword 参数传" -ForegroundColor Yellow
    exit 2
}
$mysqlExe = Join-Path $mariadbBin "mysql.exe"
$mariadbdExe = Join-Path $mariadbBin "mariadbd.exe"
Write-Host "  OK ($mariadbBin)" -ForegroundColor Green

# ---- 3. 检测 Java ----
Write-Host "[3/7] 检测 Java ..." -ForegroundColor Cyan
$javaExe = ""
try {
    $cmd = Get-Command java -ErrorAction SilentlyContinue
    if ($cmd) {
        $javaExe = if ($cmd.Source) { $cmd.Source } elseif ($cmd.Path) { $cmd.Path } else { "" }
    }
} catch {}
if (-not $javaExe) {
    $candidates = @(
        "C:\Program Files\Java\jdk*\bin\java.exe",
        "C:\Program Files\Eclipse Adoptium\jdk*\bin\java.exe",
        "C:\Program Files\Microsoft\jdk*\bin\java.exe"
    )
    foreach ($p in $candidates) {
        $found = Get-Item $p -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) { $javaExe = $found.FullName; break }
    }
}
if (-not $javaExe) {
    Write-Host "  [FAIL] 找不到 Java" -ForegroundColor Red
    Write-Host "  请安装 JDK 17: https://adoptium.net/" -ForegroundColor Yellow
    exit 3
}
Write-Host "  OK ($javaExe)" -ForegroundColor Green

# ---- 4. 端口检查 ----
Write-Host "[4/7] 检查端口 $DbPort / $BackendPort / $FrontendPort ..." -ForegroundColor Cyan
function Test-Port {
    param([int]$Port)
    return Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
}
$ports = @(
    @{Name="DB"; Port=$DbPort},
    @{Name="Backend"; Port=$BackendPort},
    @{Name="Frontend"; Port=$FrontendPort}
)
$portBusy = $false
foreach ($p in $ports) {
    if (Test-Port -Port $p.Port) {
        Write-Host "  [WARN] $($p.Name) port $($p.Port) 已被占用" -ForegroundColor Yellow
        $portBusy = $true
    }
}
if ($portBusy) {
    Write-Host ""
    Write-Host "  占用进程:" -ForegroundColor Yellow
    Get-NetTCPConnection -LocalPort $DbPort,$BackendPort,$FrontendPort -State Listen -ErrorAction SilentlyContinue |
        Select-Object LocalPort, OwningProcess, @{Name="Process";Expression={(Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue).ProcessName}} |
        Format-Table -AutoSize | Out-String | Write-Host -ForegroundColor Gray
    Write-Host "  请先 stop-all.ps1 停掉旧服务, 或者用 -BackendPort/-FrontendPort/-DbPort 换端口" -ForegroundColor Yellow
    $confirm = Read-Host "  是否继续? (y/N)"
    if ($confirm -ne "y" -and $confirm -ne "Y") {
        exit 4
    }
}
Write-Host "  OK" -ForegroundColor Green

# ---- 5. 启动 MariaDB (后台 + 前台) ----
Write-Host "[5/7] 启动 MariaDB ..." -ForegroundColor Cyan
$mariadbDataDir = "C:\Program Files\MariaDB 11.8\data"
if (-not (Test-Path $mariadbDataDir)) {
    # 找实际 datadir
    $myIni = Get-ChildItem -Path (Split-Path -Parent $mariadbBin) -Recurse -Filter "my.ini" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($myIni) {
        Write-Host "  找到 my.ini: $($myIni.FullName)" -ForegroundColor Gray
    }
}

# 检查是否 service 形式跑
$svc = Get-Service -Name MariaDB -ErrorAction SilentlyContinue
if ($svc -and $svc.Status -eq "Running") {
    Write-Host "  OK (service 已在跑: $svc)" -ForegroundColor Green
} elseif ($svc) {
    net start MariaDB | Out-Null
    Start-Sleep -Seconds 3
    Write-Host "  OK (service 已启动)" -ForegroundColor Green
} else {
    # 没 service, 用 mariadbd 后台启
    $mariadbLog = Join-Path $env:TEMP "mariadbd-install.log"
    if (Test-Port -Port $DbPort) {
        Write-Host "  port $DbPort 已被占用, 跳过启动 MariaDB" -ForegroundColor Yellow
    } else {
        $argStr = "--datadir=`"$mariadbDataDir`" --port=$DbPort --character-set-server=utf8mb4 --character-set-filesystem=utf8mb4"
        Write-Host "  args: $argStr" -ForegroundColor Gray
        Start-Process -FilePath $mariadbdExe -ArgumentList $argStr -WindowStyle Hidden -RedirectStandardOutput $mariadbLog -RedirectStandardError "$mariadbLog.err"
        Start-Sleep -Seconds 5
        if (Test-Port -Port $DbPort) {
            Write-Host "  OK (mariadbd 后台跑, log: $mariadbLog)" -ForegroundColor Green
        } else {
            Write-Host "  [FAIL] mariadbd 未监听 port $DbPort" -ForegroundColor Red
            if (Test-Path "$mariadbLog.err") {
                Get-Content "$mariadbLog.err" -Tail 20 | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
            }
            exit 5
        }
    }
}

# 验证 root 密码
Write-Host "  验证 root 密码 ..." -ForegroundColor Gray
$testOut = & $mysqlExe -h $DbHost -P "$DbPort" -u $DbUser -p$DbPassword --default-character-set=utf8mb4 -e "SELECT VERSION();" 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "  [FAIL] root 密码错误 (or service 没起来)" -ForegroundColor Red
    Write-Host "  $testOut" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  如果你忘了 root 密码, 请跑 reset-root-password.md 的 5 步法" -ForegroundColor Yellow
    exit 5
}
Write-Host "  OK (VERSION = $(($testOut | Select-Object -Last 1).Trim()))" -ForegroundColor Green

# ---- 6. 初始化数据库 ----
Write-Host "[6/7] 初始化 $DbName 库 ..." -ForegroundColor Cyan
if (-not (Test-Path $InitSql)) {
    Write-Host "  [FAIL] 找不到 $InitSql" -ForegroundColor Red
    exit 6
}
# 用 Get-Content + mysql 管道 (PowerShell 5.1 不支持 < 重定向)
$mysqlOut = Get-Content $InitSql -Encoding UTF8 | & $mysqlExe -h $DbHost -P "$DbPort" -u $DbUser -p$DbPassword --default-character-set=utf8mb4 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "  [FAIL] init.sql 跑失败:" -ForegroundColor Red
    $mysqlOut | Select-Object -Last 10 | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
    exit 6
}
Write-Host "  OK (DROP + CREATE + 15 表 + 种子数据)" -ForegroundColor Green

# ---- 7. 启动后端 + 前端 (后台) ----
Write-Host "[7/7] 启动后端 + 前端 ..." -ForegroundColor Cyan

# 启动后端 jar
if (-not (Test-Path $JarPath)) {
    Write-Host "  [WARN] 找不到 backend jar: $JarPath" -ForegroundColor Yellow
    Write-Host "  跳过 backend 启动 (你可以手动 mvn package 后重跑 install.ps1)" -ForegroundColor Yellow
} else {
    $backendLog = Join-Path $env:TEMP "health-backend.log"
    $backendArg = "-jar `"$JarPath`" --spring.datasource.password=$DbPassword --server.port=$BackendPort"
    Write-Host "  Backend args: $backendArg" -ForegroundColor Gray
    Start-Process -FilePath $javaExe -ArgumentList $backendArg -WindowStyle Hidden -RedirectStandardOutput $backendLog -RedirectStandardError "$backendLog.err"
    Start-Sleep -Seconds 8
    if (Test-Port -Port $BackendPort) {
        Write-Host "  OK Backend (port $BackendPort, log: $backendLog)" -ForegroundColor Green
    } else {
        Write-Host "  [WARN] Backend port $BackendPort 未监听, 看 log: $backendLog.err" -ForegroundColor Yellow
    }
}

# 启动前端 (用 Python http.server 模式, 不需要 Node)
$pyExe = ""
try {
    $cmd = Get-Command python -ErrorAction SilentlyContinue
    if ($cmd) { $pyExe = $cmd.Source }
} catch {}
if (-not $pyExe) {
    $pyExe = (Get-Command py -ErrorAction SilentlyContinue).Source
}
if (-not $pyExe) {
    Write-Host "  [WARN] 找不到 Python, 跳过前端启动" -ForegroundColor Yellow
    Write-Host "  你可以手动: cd frontend-pc\dist && python -m http.server $FrontendPort" -ForegroundColor Yellow
} else {
    if (-not (Test-Path $DistPath)) {
        Write-Host "  [WARN] 找不到 $DistPath, 跳过前端" -ForegroundColor Yellow
    } else {
        $frontendLog = Join-Path $env:TEMP "health-frontend.log"
        $frontendArg = "-m http.server $FrontendPort --directory `"$DistPath`""
        Write-Host "  Frontend args: $frontendArg" -ForegroundColor Gray
        Start-Process -FilePath $pyExe -ArgumentList $frontendArg -WindowStyle Hidden -RedirectStandardOutput $frontendLog -RedirectStandardError "$frontendLog.err"
        Start-Sleep -Seconds 3
        if (Test-Port -Port $FrontendPort) {
            Write-Host "  OK Frontend (port $FrontendPort, log: $frontendLog)" -ForegroundColor Green
        } else {
            Write-Host "  [WARN] Frontend port $FrontendPort 未监听" -ForegroundColor Yellow
        }
    }
}

# ---- 完成 ----
Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "  部署完成 ✓" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "访问 URL:" -ForegroundColor Cyan
Write-Host "  Frontend: http://localhost:$FrontendPort" -ForegroundColor White
Write-Host "  Backend:  http://localhost:$BackendPort/api" -ForegroundColor White
Write-Host "  浏览器打开 Frontend URL 即可" -ForegroundColor Gray
Write-Host ""
Write-Host "6 角色账号 (密码统一 root):" -ForegroundColor Cyan
Write-Host "  admin        (管理员)  / root" -ForegroundColor White
Write-Host "  doctor_zhang (医生)    / root" -ForegroundColor White
Write-Host "  doctor_li    (医生)    / root" -ForegroundColor White
Write-Host "  user_wang    (用户)    / root" -ForegroundColor White
Write-Host "  user_chen    (用户)    / root" -ForegroundColor White
Write-Host "  user_zhao    (用户)    / root" -ForegroundColor White
Write-Host ""
Write-Host "停止服务: .\stop-all.ps1" -ForegroundColor Gray
Write-Host "重启服务: .\restart-all.ps1" -ForegroundColor Gray
Write-Host "看状态:   .\status.ps1" -ForegroundColor Gray
Write-Host "完全卸载: .\uninstall.ps1" -ForegroundColor Gray
Write-Host ""