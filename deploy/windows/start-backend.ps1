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
    [string]$LogFile = "logs\backend.log",
    [string]$JavaHome = ""
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

# ---- JDK 17 检查 (JavaHome 参数 → JAVA_HOME 环境变量 → PATH → 自动搜 10+ 路径) ----
$javaBin = $null
$jdkHome = $null

# 优先级 1: -JavaHome 参数
if ($JavaHome -and (Test-Path (Join-Path $JavaHome 'bin\java.exe'))) {
    $jdkHome = $JavaHome
}
# 优先级 2: JAVA_HOME 环境变量
if (-not $jdkHome -and $env:JAVA_HOME -and (Test-Path (Join-Path $env:JAVA_HOME 'bin\java.exe'))) {
    $jdkHome = $env:JAVA_HOME
}
# 优先级 3: PATH 里 java (where.exe)
if (-not $jdkHome) {
    $whereOut = & where.exe java 2>$null | Select-Object -First 1
    if ($whereOut -and (Test-Path $whereOut)) {
        # 从 java.exe 路径反推 JDK HOME (..\.. 退到 JDK 根目录)
        $jdkHome = Split-Path -Parent (Split-Path -Parent $whereOut)
    }
}
# 优先级 4: 自动搜 10+ 常见安装位置
if (-not $jdkHome) {
    $candidates = @(
        "C:\Program Files\Eclipse Adoptium\jdk-17*",
        "C:\Program Files\Eclipse Adoptium\jdk-21*",
        "C:\Program Files\AdoptOpenJDK\jdk-17*",
        "C:\Program Files\AdoptOpenJDK\jdk-21*",
        "C:\Program Files\Java\jdk-17*",
        "C:\Program Files\Java\jdk-21*",
        "C:\Program Files\Zulu\zulu-17*",
        "C:\Program Files\Zulu\zulu-21*",
        "C:\Program Files\Microsoft\jdk-17*",
        "C:\Program Files\Amazon Corretto\jdk17*",
        "C:\Program Files\BellSoft\LibericaJDK-17*",
        "C:\Program Files\Semeru\jdk-17*",
        "C:\Program Files\GraalVM\graalvm-ce-java17*",
        "D:\Program Files\Eclipse Adoptium\jdk-17*",
        "D:\tools\jdk-17*",
        "D:\jdk-17*"
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
    Write-Host "❌ 未检测到 JDK" -ForegroundColor Red
    Write-Host ""
    Write-Host "  📦 未装 JDK? 推荐安装 Eclipse Temurin 17 (Lombok 兼容):" -ForegroundColor Yellow
    Write-Host "     https://adoptium.net/temurin/releases/?version=17" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  🛠️  三种修复方法 (任选一):" -ForegroundColor Yellow
    Write-Host "    1. 装好 JDK 后, 重开 PowerShell (环境变量生效)" -ForegroundColor Yellow
    Write-Host "    2. 手动指定路径重跑:" -ForegroundColor Yellow
    Write-Host "       .\start-backend.ps1 -JavaHome 'D:\tools\jdk-17.0.10'" -ForegroundColor Gray
    Write-Host "    3. 设环境变量后重跑:" -ForegroundColor Yellow
    Write-Host "       setx JAVA_HOME 'C:\Program Files\Eclipse Adoptium\jdk-17.0.10'" -ForegroundColor Gray
    Write-Host "       (重开 PowerShell 生效)" -ForegroundColor Gray
    exit 2
}

$javaBin = Join-Path $jdkHome "bin\java.exe"
Write-Host "✅ JDK: $jdkHome" -ForegroundColor Green

# 版本检查 (lombok 兼容性, 推荐 17)
$prevPref = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $versionOutput = & $javaBin -version 2>&1 | Select-Object -First 1
} finally {
    $ErrorActionPreference = $prevPref
}
if ($versionOutput -notmatch '"(\d+)\.(\d+)\.') {
    Write-Host "⚠️  无法解析 Java 版本 (不影响启动): $versionOutput" -ForegroundColor Yellow
} else {
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

# 关键修复 (2026-07-05): PowerShell 5.1 + java.exe 传递 -D 参数会被错误拆分
#   以前写法: & java -Dfile.encoding=UTF-8 -jar ...
#   问题: java 把 -Dfile.encoding=UTF-8 拆成 -Dfile + encoding=UTF-8
#         (中文 Windows JDK 报错 "找不到或无法加载主类 .encoding=UTF-8")
# 解决: 用 cmd.exe 作为中间层, 或者用引号包裹 -D 参数
chcp 65001 > $null   # 强制控制台 UTF-8 (PowerShell 5.1 中文 Windows 默认 GBK)
$javaCmd = "`"$javaBin`" -Dfile.encoding=UTF-8 -Dspring.profiles.active=prod -Dserver.port=$Port -jar `"$JarPath`""
Write-Host "   CMD: $javaCmd" -ForegroundColor Gray
Write-Host ""
cmd.exe /c $javaCmd 2>&1 | Tee-Object -FilePath $logAbs -Append

Write-Host "`n🛑 后端已停止 (退出码 $LASTEXITCODE)" -ForegroundColor Yellow
