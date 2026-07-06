#Requires -RunAsAdministrator
<#
.SYNOPSIS
  uninstall.ps1 - 完全卸载健康管理系统 (杀进程 + 删库 + 删 jar)
.NOTES
  v4.0
  - 不会卸载 MariaDB (那是另一个软件)
  - 不会删 source code (deploy\..\..\src, frontend-pc\src 等)
  - 只会清 runtime artifacts (jar, dist build, 进程, 数据库)
#>

[CmdletBinding()]
param(
    [switch]$KeepDatabase  # 加这个参数保留数据库, 默认 DROP
)

$ErrorActionPreference = "Stop"

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  健康管理系统 完全卸载" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

$confirm = Read-Host "确认要卸载? 这会删 health_management 库 + backend jar + frontend dist build (y/N)"
if ($confirm -ne "y" -and $confirm -ne "Y") {
    Write-Host "取消卸载" -ForegroundColor Yellow
    exit 0
}

Write-Host ""

# 1. 停进程
Write-Host "[1/4] 停止所有进程 ..." -ForegroundColor Cyan
& "$PSScriptRoot\stop-all.ps1"

# 2. DROP 数据库
Write-Host ""
Write-Host "[2/4] DROP health_management 库 ..." -ForegroundColor Cyan
if ($KeepDatabase) {
    Write-Host "  跳过 (用了 -KeepDatabase)" -ForegroundColor Yellow
} else {
    $mysqlExe = ""
    $candidates = @(
        "C:\Program Files\MariaDB*\bin\mysql.exe",
        "C:\Program Files (x86)\MariaDB*\bin\mysql.exe",
        "D:\Program Files\MariaDB*\bin\mysql.exe"
    )
    foreach ($p in $candidates) {
        $found = Get-Item $p -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) { $mysqlExe = $found.FullName; break }
    }
    if ($mysqlExe) {
        & $mysqlExe -h 127.0.0.1 -P 3306 -u root -popck2026 --default-character-set=utf8mb4 -e "DROP DATABASE IF EXISTS health_management;" 2>&1 | Out-Null
        Write-Host "  OK (DROP DATABASE IF EXISTS health_management)" -ForegroundColor Green
    } else {
        Write-Host "  [SKIP] 找不到 mysql.exe" -ForegroundColor Yellow
    }
}

# 3. 删 jar
Write-Host ""
Write-Host "[3/4] 删 backend jar ..." -ForegroundColor Cyan
$jarPath = Join-Path (Resolve-Path "..\..") "target\health-management-1.0.0.jar"
if (Test-Path $jarPath) {
    Remove-Item $jarPath -Force
    Write-Host "  OK (Remove-Item $jarPath)" -ForegroundColor Green
} else {
    Write-Host "  OK (jar 不存在)" -ForegroundColor Green
}

# 4. 删 frontend dist build
Write-Host ""
Write-Host "[4/4] 删 frontend dist build ..." -ForegroundColor Cyan
$distPath = Join-Path (Resolve-Path "..\..") "frontend-pc\dist"
if (Test-Path $distPath) {
    Remove-Item $distPath -Recurse -Force
    Write-Host "  OK (Remove-Item $distPath -Recurse)" -ForegroundColor Green
} else {
    Write-Host "  OK (dist 不存在)" -ForegroundColor Green
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "  卸载完成" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "注意:" -ForegroundColor Yellow
Write-Host "  - MariaDB 本身没卸 (用 installer 单独管理)" -ForegroundColor Gray
Write-Host "  - source code 没删 (deploy\..\..\src 等)" -ForegroundColor Gray
Write-Host "  - git 历史还在" -ForegroundColor Gray
Write-Host ""
Write-Host "完全重新部署: cd ..\.. && mvn package -DskipTests && cd frontend-pc && npm run build && cd ..\deploy\windows && .\install.ps1" -ForegroundColor Cyan
Write-Host ""