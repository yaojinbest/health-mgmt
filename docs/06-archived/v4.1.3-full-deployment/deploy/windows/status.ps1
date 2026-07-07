<#
.SYNOPSIS
  status.ps1 - 看健康管理系统状态 (v4.1)
.NOTES
  v4.1 改进:
    - ✅ 颜色编码 (Running=绿, Stopped=黄)
    - ✅ PID 显示方便 debug
#>

[CmdletBinding()]
param()

function Get-PortStatus {
    param([int]$Port)
    # v4.1.2 fix: @() 包装避免单元素 wrapper 折叠成布尔
    $conn = @(Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue)
    if ($conn.Count -gt 0) {
        $pids = ($conn.OwningProcess | Select-Object -Unique) -join ", "
        return @{ Status="LISTENING"; Pids=$pids }
    } else {
        return @{ Status="NOT LISTENING"; Pids="" }
    }
}

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  健康管理系统 服务状态 (v4.1)" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# MariaDB
Write-Host "MariaDB:" -ForegroundColor Cyan
$svc = Get-Service -Name MariaDB -ErrorAction SilentlyContinue
if ($svc) {
    $color = if ($svc.Status -eq "Running") { "Green" } else { "Yellow" }
    Write-Host "  Service: $($svc.Status)" -ForegroundColor $color
} else {
    Write-Host "  Service: 没装" -ForegroundColor Yellow
}
$dbPort = Get-PortStatus -Port 3306
$color = if ($dbPort.Status -eq "LISTENING") { "Green" } else { "Yellow" }
Write-Host "  Port 3306: $($dbPort.Status)" -ForegroundColor $color
if ($dbPort.Pids) { Write-Host "  PID: $($dbPort.Pids)" -ForegroundColor Gray }

# Backend
Write-Host ""
Write-Host "Backend (java):" -ForegroundColor Cyan
$javaProcs = Get-Process -Name java -ErrorAction SilentlyContinue
if ($javaProcs) {
    $pids = ($javaProcs | Select-Object -ExpandProperty Id) -join ", "
    Write-Host "  进程: $($javaProcs.Count) 个 (PID: $pids)" -ForegroundColor Green
} else {
    Write-Host "  没 java 进程在跑" -ForegroundColor Yellow
}
$bePort = Get-PortStatus -Port 8090
$color = if ($bePort.Status -eq "LISTENING") { "Green" } else { "Yellow" }
Write-Host "  Port 8090: $($bePort.Status)" -ForegroundColor $color

# Frontend
Write-Host ""
Write-Host "Frontend (python http.server):" -ForegroundColor Cyan
$pyProcs = Get-Process -Name python -ErrorAction SilentlyContinue
if ($pyProcs) {
    $pids = ($pyProcs | Select-Object -ExpandProperty Id) -join ", "
    Write-Host "  进程: $($pyProcs.Count) 个 (PID: $pids)" -ForegroundColor Green
} else {
    Write-Host "  没 python 进程在跑" -ForegroundColor Yellow
}
$fePort = Get-PortStatus -Port 5173
$color = if ($fePort.Status -eq "LISTENING") { "Green" } else { "Yellow" }
Write-Host "  Port 5173: $($fePort.Status)" -ForegroundColor $color

Write-Host ""
Write-Host "操作:" -ForegroundColor Cyan
Write-Host "  启动:  .\install.ps1" -ForegroundColor Gray
Write-Host "  停止:  .\stop-all.ps1" -ForegroundColor Gray
Write-Host "  重启:  .\restart-all.ps1" -ForegroundColor Gray
Write-Host "  卸载:  .\uninstall.ps1" -ForegroundColor Gray
Write-Host "  手动 reset root: .\reset-root-auto.ps1 -MariadbBin <bin> -MariadbDataDir <data> -NewPassword opck2026 -MysqlExe <mysql>" -ForegroundColor Gray
Write-Host ""