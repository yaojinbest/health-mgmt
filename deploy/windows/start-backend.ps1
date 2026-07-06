# ============================================================================
#  start-backend.ps1 - 启动健康管理系统 Spring Boot 后端 (v3)
# ============================================================================
#
#  用法:
#    PS> .\start-backend.ps1
#    PS> .\start-backend.ps1 -Port 9090
#    PS> .\start-backend.ps1 -JavaHome "C:\Program Files\Eclipse Adoptium\jdk-17.0.10"
#
#  OPC_K 部署 SOP (2026-07-06):
#    - 杀 java 进程用 Get-Process + Stop-Process (PowerShell 原生, 不抛错)
#    - 启动用 cmd /c 包裹 (避免 -D 参数被 PowerShell 拆分)
#    - UTF-8 BOM 必备
#    - 端口冲突检测
#
#  历史踩坑 (2026-07-05/06):
#    - java.exe -Dfile.encoding=UTF-8 被 PS 拆成 -Dfile + encoding (中文 Windows)
#    - 用 cmd.exe /c 包裹解决
# ============================================================================

[CmdletBinding()]
param(
    [int]$Port = 8090,
    [string]$ProjectRoot = "..\..",
    [string]$LogFile = "logs\backend.log",
    [string]$JavaHome = ""
)

$ErrorActionPreference = "Stop"
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# ---- 杀旧 java 进程 (用 Get-Process, 不抛错) ----
$javaproc = Get-Process -Name java -ErrorAction SilentlyContinue
if ($javaproc) {
    Write-Host "杀旧 java 进程 (PID $($javaproc.Id))..." -ForegroundColor Cyan
    try {
        Stop-Process -Id $javaproc.Id -Force -ErrorAction Stop
        Start-Sleep -Seconds 2
    } catch {
        Write-Host "  (进程已退出, 忽略)" -ForegroundColor Gray
    }
}

# ---- 路径 ----
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$AbsRoot = Resolve-Path (Join-Path $ScriptDir $ProjectRoot) | Select-Object -ExpandProperty Path
$JarPath = Join-Path $AbsRoot "target\health-management-1.0.0.jar"

if (-not (Test-Path $JarPath)) {
    Write-Host "[FAIL] 找不到 $JarPath" -ForegroundColor Red
    Write-Host "  编译: `$env:JAVA_HOME='C:\Program Files\Eclipse Adoptium\jdk-17'; mvn package -DskipTests" -ForegroundColor Yellow
    exit 1
}

# ---- 端口检测 ----
$portInUse = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
if ($portInUse) {
    Write-Host "[WARN] 端口 $Port 已被占用 (PID $($portInUse.OwningProcess))" -ForegroundColor Yellow
    Write-Host "  杀进程: Stop-Process -Id $($portInUse.OwningProcess) -Force" -ForegroundColor Gray
    Write-Host "  或换端口: .\start-backend.ps1 -Port 9090" -ForegroundColor Gray
    exit 2
}

# ---- JDK 17 找 ----
$jdkHome = $null
if ($JavaHome -and (Test-Path (Join-Path $JavaHome 'bin\java.exe'))) {
    $jdkHome = $JavaHome
}
if (-not $jdkHome -and $env:JAVA_HOME -and (Test-Path (Join-Path $env:JAVA_HOME 'bin\java.exe'))) {
    $jdkHome = $env:JAVA_HOME
}
if (-not $jdkHome) {
    $whereOut = & where.exe java 2>$null | Select-Object -First 1
    if ($whereOut -and (Test-Path $whereOut)) {
        $jdkHome = Split-Path -Parent (Split-Path -Parent $whereOut)
    }
}
if (-not $jdkHome) {
    $candidates = @(
        "C:\Program Files\Eclipse Adoptium\jdk-17*",
        "C:\Program Files\Eclipse Adoptium\jdk-21*",
        "C:\Program Files\Zulu\zulu-17*",
        "C:\Program Files\Amazon Corretto\jdk17*",
        "D:\tools\jdk-17*"
    )
    foreach ($p in $candidates) {
        $found = Get-Item $p -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found -and (Test-Path (Join-Path $found.FullName 'bin\java.exe'))) {
            $jdkHome = $found.FullName
            break
        }
    }
}
if (-not $jdkHome) {
    Write-Host "[FAIL] 未检测到 JDK" -ForegroundColor Red
    Write-Host "  推荐 Eclipse Temurin 17: https://adoptium.net/temurin/releases/?version=17" -ForegroundColor Yellow
    exit 3
}

$javaBin = Join-Path $jdkHome "bin\java.exe"
Write-Host "JDK: $jdkHome" -ForegroundColor Cyan

# ---- 启动 ----
$logDir = Join-Path $ScriptDir "logs"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
$logAbs = Join-Path $ScriptDir $LogFile

Write-Host ""
Write-Host "启动健康管理系统后端..." -ForegroundColor Cyan
Write-Host "  JAR:  $JarPath" -ForegroundColor Gray
Write-Host "  端口: $Port" -ForegroundColor Gray
Write-Host "  日志: $logAbs" -ForegroundColor Gray
Write-Host ""

# cmd.exe /c 包裹避免 -D 参数被 PowerShell 拆分
chcp 65001 > $null
$javaCmd = "`"$javaBin`" -Dfile.encoding=UTF-8 -Dspring.profiles.active=prod -Dserver.port=$Port -jar `"$JarPath`""
Write-Host "CMD: $javaCmd" -ForegroundColor Gray
Write-Host ""
cmd.exe /c $javaCmd 2>&1 | Tee-Object -FilePath $logAbs -Append

Write-Host ""
Write-Host "[STOP] 后端已停止 (退出码 $LASTEXITCODE)" -ForegroundColor Yellow
