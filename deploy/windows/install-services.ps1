# ============================================================================
#  install-services.ps1 - 注册为 Windows 后台服务 (v2)
# ============================================================================
[CmdletBinding()]
param(
    [string]$JavaHome = "",
    [string]$NodeExe = "",
    [string]$FrontendDir = "D:\health-mgmt\frontend-pc",
    [string]$ProjectRoot = "D:\health-mgmt",
    [string]$NssmPath = "C:\Tools\nssm-2.24\win64\nssm.exe"
)

$ErrorActionPreference = "Stop"
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# 检查管理员权限
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[FAIL] 请用管理员身份运行 PowerShell" -ForegroundColor Red
    exit 1
}

# 找 nssm
if (-not (Test-Path $NssmPath)) {
    Write-Host "[FAIL] NSSM 不存在: $NssmPath" -ForegroundColor Red
    Write-Host "  下载: https://nssm.cc/release/nssm-2.24.zip" -ForegroundColor Yellow
    exit 2
}
Write-Host "NSSM: $NssmPath" -ForegroundColor Cyan

$BackendService = "HealthMgmtBackend"
$FrontendService = "HealthMgmtFrontendPc"
$JarPath = Join-Path $ProjectRoot "target\health-management-1.0.0.jar"
$LogDir = Join-Path $ProjectRoot "deploy\windows\logs"
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }

# 找 JDK
$jdkHome = $null
if ($JavaHome -and (Test-Path (Join-Path $JavaHome 'bin\java.exe'))) { $jdkHome = $JavaHome }
if (-not $jdkHome -and $env:JAVA_HOME -and (Test-Path (Join-Path $env:JAVA_HOME 'bin\java.exe'))) { $jdkHome = $env:JAVA_HOME }
if (-not $jdkHome) {
    $whereOut = & where.exe java 2>$null | Select-Object -First 1
    if ($whereOut) { $jdkHome = Split-Path -Parent (Split-Path -Parent $whereOut) }
}
if (-not $jdkHome) { Write-Host "[FAIL] 找不到 JDK" -ForegroundColor Red; exit 3 }
$javaBin = Join-Path $jdkHome "bin\java.exe"

# 找 node
if (-not $NodeExe) {
    $nodePath = & where.exe node 2>$null | Select-Object -First 1
    if ($nodePath) { $NodeExe = $nodePath } else { Write-Host "[FAIL] 找不到 node.exe" -ForegroundColor Red; exit 4 }
}

Write-Host ""
Write-Host "安装服务: $BackendService" -ForegroundColor Cyan

# 装后端服务
& $NssmPath install $BackendService $javaBin `
    "-Dfile.encoding=UTF-8 -Dspring.profiles.active=prod -jar `"$JarPath`"" | Out-Null
& $NssmPath set $BackendService AppDirectory $ProjectRoot | Out-Null
& $NssmPath set $BackendService AppStdout (Join-Path $LogDir "backend.out.log") | Out-Null
& $NssmPath set $BackendService AppStderr (Join-Path $LogDir "backend.err.log") | Out-Null
& $NssmPath set $BackendService Start SERVICE_AUTO_START | Out-Null
& $NssmPath set $BackendService AppRestartDelay 5000 | Out-Null
Write-Host "  OK" -ForegroundColor Green

# 装前端服务
Write-Host "安装服务: $FrontendService" -ForegroundColor Cyan
& $NssmPath install $FrontendService $NodeExe `
    "npx vite preview --host 0.0.0.0 --port 5174" | Out-Null
& $NssmPath set $FrontendService AppDirectory $FrontendDir | Out-Null
& $NssmPath set $FrontendService AppStdout (Join-Path $LogDir "frontend.out.log") | Out-Null
& $NssmPath set $FrontendService AppStderr (Join-Path $LogDir "frontend.err.log") | Out-Null
& $NssmPath set $FrontendService Start SERVICE_AUTO_START | Out-Null
& $NssmPath set $FrontendService AppRestartDelay 5000 | Out-Null
Write-Host "  OK" -ForegroundColor Green

# 启动
Write-Host ""
Write-Host "启动服务..." -ForegroundColor Cyan
& $NssmPath start $BackendService | Out-Null
& $NssmPath start $FrontendService | Out-Null
Start-Sleep -Seconds 3

Write-Host ""
Write-Host "OK 安装完成" -ForegroundColor Green
Write-Host "  - 后端:  sc query $BackendService" -ForegroundColor Gray
Write-Host "  - 前端:  sc query $FrontendService" -ForegroundColor Gray
Write-Host "  - 日志:  Get-Content '$LogDir\backend.out.log' -Wait" -ForegroundColor Gray
