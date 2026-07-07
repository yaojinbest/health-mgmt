#Requires -RunAsAdministrator
<#
.SYNOPSIS
  stop-all.ps1 - 停止健康管理系统所有进程 (v4.1)
.NOTES
  v4.1 改进:
    - ✅ Get-Process + Stop-Process 替 taskkill (不抛 RemoteException)
    - ✅ PID 输出, 方便 debug
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  健康管理系统 停止服务 (v4.1)" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# 杀 java (backend)
Write-Host "[1/2] 停止 Backend (java) ..." -ForegroundColor Cyan
$javaProcs = Get-Process -Name java -ErrorAction SilentlyContinue
if ($javaProcs) {
    $pids = ($javaProcs | Select-Object -ExpandProperty Id) -join ", "
    $javaProcs | Stop-Process -Force
    Write-Host "  OK (停止 $($javaProcs.Count) 个 java 进程, PID: $pids)" -ForegroundColor Green
} else {
    Write-Host "  OK (没 java 进程在跑)" -ForegroundColor Green
}

# 杀 python http.server (frontend)
Write-Host "[2/2] 停止 Frontend (python http.server) ..." -ForegroundColor Cyan
$pyProcs = Get-Process -Name python -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowTitle -eq "" -or $_.CommandLine -like "*http.server*" }
if ($pyProcs) {
    $pids = ($pyProcs | Select-Object -ExpandProperty Id) -join ", "
    $pyProcs | Stop-Process -Force
    Write-Host "  OK (停止 $($pyProcs.Count) 个 python 进程, PID: $pids)" -ForegroundColor Green
} else {
    Write-Host "  OK (没 python 进程在跑)" -ForegroundColor Green
}

Write-Host ""
Write-Host "MariaDB 没动, 如果要停 MariaDB 跑: net stop MariaDB" -ForegroundColor Gray
Write-Host "完全卸载跑: .\uninstall.ps1" -ForegroundColor Gray
Write-Host ""