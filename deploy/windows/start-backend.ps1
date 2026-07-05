# ============================================================================
#  start-backend.ps1 - 启动健康管理系统 Spring Boot 后端
# ============================================================================
#
#  用法:
#    PS> .\start-backend.ps1           # 默认端口 8090
#    PS> .\start-backend.ps1 -Port 9090 # 自定义端口
#
#  行为:
#    1. 检查 JAVA_HOME (JDK 17)
#    2. 检查后端 JAR 存在 (target\health-management-1.0.0.jar)
#    3. 检查 MariaDB/MySQL 监听
#    4. 启动 Java 进程 (前台, Ctrl+C 结束)
#
#  Windows 服务化版本: .\install-services.ps1
# ============================================================================

[CmdletBinding()]
param(
    [int]$Port = 8090,
    [string]$ProjectRoot = "..\..",
    [string]$LogFile = "logs\backend.log"
)

$ErrorActionPreference = "Stop"
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# ---- 路径 ----
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$AbsRoot = Resolve-Path (Join-Path $ScriptDir $ProjectRoot) | Select-Object -ExpandProperty Path
$JarPath = Join-Path $AbsRoot "target\health-management-1.0.0.jar"

if (-not (Test-Path $JarPath)) {
    Write-Host "❌ 找不到 $JarPath" -ForegroundColor Red
    Write-Host "   先跑 (Linux 沙箱或本机 Maven):" -ForegroundColor Yellow
    Write-Host "   cd $AbsRoot" -ForegroundColor Yellow
    Write-Host "   `$env:JAVA_HOME = 'C:\Program Files\Eclipse Adoptium\jdk-17'" -ForegroundColor Yellow
    Write-Host "   mvn package -DskipTests" -ForegroundColor Yellow
    exit 1
}

# ---- JDK 17 检查 ----
if (-not $env:JAVA_HOME) {
    $jdk17 = Get-Command java -ErrorAction SilentlyContinue
    if ($jdk17) {
        Write-Host "⚠️  JAVA_HOME 未设置, 但 java 在 PATH 中, 继续尝试..." -ForegroundColor Yellow
    } else {
        Write-Host "❌ 未检测到 Java, 请安装 JDK 17 并设置 JAVA_HOME" -ForegroundColor Red
        Write-Host "   推荐: Eclipse Temurin 17 (https://adoptium.net/)" -ForegroundColor Yellow
        exit 2
    }
} else {
    $javaBin = Join-Path $env:JAVA_HOME "bin\java.exe"
    if (-not (Test-Path $javaBin)) {
        Write-Host "❌ JAVA_HOME 指向不存在的 bin\java.exe: $javaBin" -ForegroundColor Red
        exit 2
    }
    $versionOutput = & $javaBin -version 2>&1 | Select-Object -First 1
    if ($versionOutput -notmatch '"(\d+)\.(\d+)\.') {
        Write-Host "❌ 无法解析 Java 版本" -ForegroundColor Red
        exit 2
    }
    $major = [int]$Matches[1]
    if ($major -lt 17 -or $major -gt 21) {
        Write-Host "⚠️  Java $major 检测到, 推荐 JDK 17 (Lombok 兼容性)" -ForegroundColor Yellow
    } else {
        Write-Host "✅ Java $major OK" -ForegroundColor Green
    }
}

# ---- 日志目录 ----
$logDir = Join-Path $ScriptDir "logs"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
$logAbs = Join-Path $ScriptDir $LogFile

# ---- 启动 ----
Write-Host ""
Write-Host "🚀 启动健康管理系统后端..." -ForegroundColor Cyan
Write-Host "   JAR: $JarPath" -ForegroundColor Gray
Write-Host "   端口: $Port" -ForegroundColor Gray
Write-Host "   日志: $logAbs" -ForegroundColor Gray
Write-Host ""

# 关键: -D 在 -jar 之前 (NSSM 踩坑 #5)
# 关键: -Dfile.encoding=UTF-8 防中文乱码
& java `
    -Dfile.encoding=UTF-8 `
    -Dspring.profiles.active=prod `
    -Dserver.port=$Port `
    -jar "$JarPath" `
    *>&1 | Tee-Object -FilePath $logAbs -Append

Write-Host "`n🛑 后端已停止 (退出码 $LASTEXITCODE)" -ForegroundColor Yellow
