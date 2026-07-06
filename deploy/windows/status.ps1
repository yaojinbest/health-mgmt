<#
.SYNOPSIS
  status.ps1 - 看健康管理系统状态
.NOTES
  v4.0
#>

[CmdletBinding()]
param()

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  健康管理系统 服务状态" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# MariaDB
Write-Host "MariaDB:" -ForegroundColor Cyan
$svc = Get-Service -Name MariaDB -ErrorAction SilentlyContinue
if ($svc) {
    Write-Host "  Service: $($svc.Status)" -ForegroundColor $(if ($svc.Status -eq "Running") { "Green" } else { "Yellow" })
} else {
    Write-Host "  Service: 没装" -ForegroundColor Yellow
}
$port3306 = Get-NetTCPConnection -LocalPort 3306 -State Listen -ErrorAction SilentlyContinue
if ($port3306) {
    Write-Host "  Port 3306: LISTENING" -ForegroundColor Green
} else {
    Write-Host "  Port 3306: NOT LISTENING" -ForegroundColor Yellow
}

# Backend
Write-Host ""
Write-Host "Backend (java):" -ForegroundColor Cyan
$javaProcs = Get-Process -Name java -ErrorAction SilentlyContinue
if ($javaProcs) {
    Write-Host "  进程数: $($javaProcs.Count) (PID: $($javaProcs.Id -join ', '))" -ForegroundColor Green
} else {
    Write-Host "  没 java 进程在跑" -ForegroundColor Yellow
}
$port8090 = Get-NetTCPConnection -LocalPort 8090 -State Listen -ErrorAction SilentlyContinue
if ($port8090) {
    Write-Host "  Port 8090: LISTENING" -ForegroundColor Green
} else {
    Write-Host "  Port 8090: NOT LISTENING" -ForegroundColor Yellow
}

# Frontend
Write-Host ""
Write-Host "Frontend (python http.server):" -ForegroundColor Cyan
$pyProcs = Get-Process -Name python -ErrorAction SilentlyContinue
if ($pyProcs) {
    Write-Host "  进程数: $($pyProcs.Count) (PID: $($pyProcs.Id -join ', '))" -ForegroundColor Green
} else {
    Write-Host "  没 python 进程在跑" -ForegroundColor Yellow
}
$port5173 = Get-NetTCPConnection -LocalPort 5173 -State Listen -ErrorAction SilentlyContinue
if ($port5173) {
    Write-Host "  Port 5173: LISTENING" -ForegroundColor Green
} else {
    Write-Host "  Port 5173: NOT LISTENING" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "操作:" -ForegroundColor Cyan
Write-Host "  启动:  .\install.ps1" -ForegroundColor Gray
Write-Host "  停止:  .\stop-all.ps1" -ForegroundColor Gray
Write-Host "  重启:  .\restart-all.ps1" -ForegroundColor Gray
Write-Host "  卸载:  .\uninstall.ps1" -ForegroundColor Gray
Write-Host ""