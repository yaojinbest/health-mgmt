# ============================================================================
#  uninstall-services.ps1 - 卸载健康管理系统的 Windows 服务
# ============================================================================
[CmdletBinding()]
param(
    [string]$NssmPath = "C:\Tools\nssm-2.24\win64\nssm.exe",
    [string]$LogDir = "logs"
)

$ErrorActionPreference = "Stop"
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "❌ 必须用管理员身份运行 PowerShell" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $NssmPath)) {
    Write-Host "❌ NSSM 不存在: $NssmPath" -ForegroundColor Red
    exit 2
}

$services = @("HealthMgmtBackend", "HealthMgmtFrontendPc")

foreach ($svc in $services) {
    $exists = & $NssmPath status $svc 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "⏭️  服务不存在, 跳过: $svc" -ForegroundColor Gray
        continue
    }
    Write-Host "🛑 停止 + 移除: $svc" -ForegroundColor Cyan
    & $NssmPath stop   $svc 2>$null | Out-Null
    Start-Sleep -Seconds 1
    & $NssmPath remove $svc confirm | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ $svc 已移除" -ForegroundColor Green
    } else {
        Write-Host "⚠️  $svc 移除失败 (退出码 $LASTEXITCODE)" -ForegroundColor Yellow
    }
}

# 可选: 清日志
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$logAbs = Join-Path $scriptDir $LogDir
if (Test-Path $logAbs) {
    $ans = Read-Host "`n是否清空日志目录 $logAbs ? (y/N)"
    if ($ans -eq 'y' -or $ans -eq 'Y') {
        Remove-Item -Path "$logAbs\*" -Force -ErrorAction SilentlyContinue
        Write-Host "🧹 日志已清空" -ForegroundColor Green
    }
}

Write-Host "`n✅ 卸载完成" -ForegroundColor Green