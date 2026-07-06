#Requires -RunAsAdministrator
<#
.SYNOPSIS
  reset-root-auto.ps1 - 自动 5 步 reset MariaDB root 密码 (PowerShell 5.1 实战版)
.DESCRIPTION
  被 install.ps1 -AutoResetRoot 自动调用, 也可手动跑:
    .\reset-root-auto.ps1 -NewPassword opck2026

  5 步流程:
    1. 停 MariaDB service + 强杀 mariadbd 进程
    2. 启 mariadbd --skip-grant-tables (前台新窗口)
    3. 用 reset-root-simple.sql 改密 (新窗口调 mysql)
    4. 关前台 mariadbd (新窗口 Stop-Process)
    5. 重启 service + 验证密码

.NOTES
  v4.1 (2026-07-06 22:34) - 基于 PowerShell 5.1 学习手册:
    - ✅ here-string 不用 (改用 .sql 文件 + Copy-Item)
    - ✅ mysql -h "127.0.0.1" 加空格 + 双引号
    - ✅ 进程用 Get-Process + Stop-Process (不用 taskkill)
    - ✅ $LASTEXITCODE 立即快照
    - ✅ UTF-8 BOM 全套
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$MariadbBin,
    [Parameter(Mandatory=$true)]
    [string]$MariadbDataDir,
    [int]$DbPort = 3306,
    [string]$DbUser = "root",
    [Parameter(Mandatory=$true)]
    [string]$NewPassword,
    [Parameter(Mandatory=$true)]
    [string]$MysqlExe
)

$ErrorActionPreference = "Stop"
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ResetSql = Join-Path $ScriptDir "reset-root-simple.sql"

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  MariaDB root 密码自动 reset (v4.1)" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "MariaDB bin:   $MariadbBin" -ForegroundColor Gray
Write-Host "datadir:       $MariadbDataDir" -ForegroundColor Gray
Write-Host "新密码:        $NewPassword" -ForegroundColor Gray
Write-Host "Reset SQL:     $ResetSql" -ForegroundColor Gray
Write-Host ""

# ============================================================
# Step 1: 停 service + 杀进程
# ============================================================
Write-Host "[Step 1/5] 停 service + 杀进程 ..." -ForegroundColor Cyan
$svc = Get-Service -Name MariaDB -ErrorAction SilentlyContinue
if ($svc -and $svc.Status -eq "Running") {
    net stop MariaDB | Out-Null
    Write-Host "  OK (service 已停)" -ForegroundColor Green
} else {
    Write-Host "  OK (service 没在跑)" -ForegroundColor Green
}
Start-Sleep -Seconds 2
$mariadbProcs = Get-Process -Name mariadbd,mysqld -ErrorAction SilentlyContinue
if ($mariadbProcs) {
    $mariadbProcs | Stop-Process -Force
    Write-Host "  OK (强杀 $($mariadbProcs.Count) 个 mariadbd 进程)" -ForegroundColor Green
} else {
    Write-Host "  OK (没 mariadbd 进程)" -ForegroundColor Green
}
Start-Sleep -Seconds 3
$portBusy = Get-NetTCPConnection -LocalPort $DbPort -State Listen -ErrorAction SilentlyContinue
if ($portBusy) {
    Write-Host "  [WARN] port $DbPort 还被占, 等 5 秒" -ForegroundColor Yellow
    Start-Sleep -Seconds 5
}

# ============================================================
# Step 2: 启 mariadbd --skip-grant-tables (前台新窗口)
# ============================================================
Write-Host "[Step 2/5] 启 mariadbd --skip-grant-tables (新窗口) ..." -ForegroundColor Cyan
$mariadbdExe = Join-Path $MariadbBin "mariadbd.exe"
$argStr = "--datadir=`"$MariadbDataDir`" --port=$DbPort --skip-grant-tables --character-set-server=utf8mb4 --character-set-filesystem=utf8mb4"
Write-Host "  args: $argStr" -ForegroundColor Gray

# Start-Process 用新窗口 (前台), 不隐藏, 用户能看到
Start-Process -FilePath $mariadbdExe -ArgumentList $argStr -RedirectStandardOutput "$env:TEMP\mariadbd-reset.log" -RedirectStandardError "$env:TEMP\mariadbd-reset.log.err"

# 等 ready for connections
$ready = $false
for ($i = 1; $i -le 30; $i++) {
    Start-Sleep -Seconds 1
    if (Test-NetTCPConnection -LocalPort $DbPort -State Listen -ErrorAction SilentlyContinue) {
        $ready = $true
        Write-Host "  OK (ready for connections, ${i}s)" -ForegroundColor Green
        break
    }
}
if (-not $ready) {
    Write-Host "  [FAIL] mariadbd 30s 内未起来" -ForegroundColor Red
    if (Test-Path "$env:TEMP\mariadbd-reset.log.err") {
        Get-Content "$env:TEMP\mariadbd-reset.log.err" -Tail 20 | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
    }
    exit 1
}

# ============================================================
# Step 3: 跑 reset-root-simple.sql
# ============================================================
Write-Host "[Step 3/5] 跑 reset-root-simple.sql ..." -ForegroundColor Cyan
if (-not (Test-Path $ResetSql)) {
    Write-Host "  [FAIL] 找不到 $ResetSql" -ForegroundColor Red
    exit 2
}

# 关键: -h "127.0.0.1" 加空格 + 双引号 + 用 Get-Content 管道 (不用 here-string)
$mysqlOut = Get-Content $ResetSql -Encoding UTF8 | & $MysqlExe -h "127.0.0.1" -P "$DbPort" -u "$DbUser" --default-character-set=utf8mb4 2>&1
$mysqlExit = $LASTEXITCODE   # 立即快照
if ($mysqlExit -ne 0) {
    Write-Host "  [FAIL] reset.sql 跑失败 (exit $mysqlExit):" -ForegroundColor Red
    $mysqlOut | Select-Object -Last 10 | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
    exit 3
}
Write-Host "  OK (3 行 INSERT + FLUSH PRIVILEGES)" -ForegroundColor Green

# ============================================================
# Step 4: 杀 mariadbd (退出 skip-grant 模式)
# ============================================================
Write-Host "[Step 4/5] 杀 mariadbd ..." -ForegroundColor Cyan
$mariadbProcs = Get-Process -Name mariadbd -ErrorAction SilentlyContinue
if ($mariadbProcs) {
    $mariadbProcs | Stop-Process -Force
    Write-Host "  OK (强杀 $($mariadbProcs.Count) 个进程)" -ForegroundColor Green
} else {
    Write-Host "  OK (没进程)" -ForegroundColor Green
}
Start-Sleep -Seconds 3

# ============================================================
# Step 5: 重启 service + 验证
# ============================================================
Write-Host "[Step 5/5] 重启 service + 验证 ..." -ForegroundColor Cyan
net start MariaDB | Out-Null
Start-Sleep -Seconds 3

# 验证
$verifyOut = & $MysqlExe -h "127.0.0.1" -P "$DbPort" -u $DbUser -p$NewPassword --default-character-set=utf8mb4 -e "SELECT VERSION(), CURRENT_USER();" 2>&1
$verifyExit = $LASTEXITCODE
if ($verifyExit -ne 0) {
    Write-Host "  [FAIL] 验证失败 (exit $verifyExit):" -ForegroundColor Red
    $verifyOut | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
    exit 4
}
Write-Host "  OK (新密码验证通过)" -ForegroundColor Green
$verifyOut | Where-Object { $_ -match "VERSION\|root@" } | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "  reset 成功 ✓" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
exit 0