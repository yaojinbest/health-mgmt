# ============================================================================
#  uninstall-services.ps1 - 卸载 Windows 后台服务 (v2)
# ============================================================================
[CmdletBinding()]
param(
    [string]$NssmPath = "C:\Tools\nssm-2.24\win64\nssm.exe"
)

$ErrorActionPreference = "Stop"
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[FAIL] 请用管理员身份运行 PowerShell" -ForegroundColor Red
    exit 1
}
if (-not (Test-Path $NssmPath)) { Write-Host "[FAIL] NSSM 不存在: $NssmPath" -ForegroundColor Red; exit 2 }

foreach ($svc in @("HealthMgmtBackend", "HealthMgmtFrontendPc")) {
    $status = & sc.exe query $svc 2>&1
    if ($status -match "STOPPED|RUNNING") {
        Write-Host "停止 + 卸载: $svc" -ForegroundColor Cyan
        & $NssmPath stop $svc 2>&1 | Out-Null
        Start-Sleep -Seconds 2
        & $NssmPath remove $svc confirm 2>&1 | Out-Null
        Write-Host "  OK" -ForegroundColor Green
    } else {
        Write-Host "  $svc 未安装, 跳过" -ForegroundColor Gray
    }
}
Write-Host ""
Write-Host "[OK] 卸载完成" -ForegroundColor Green
