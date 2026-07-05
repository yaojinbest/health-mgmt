# ============================================================================
#  install-services.ps1 - 将健康管理系统安装为 Windows 后台服务
# ============================================================================
#
#  要求:
#    - 必须 PowerShell 管理员身份运行
#    - NSSM 已下载 (https://nssm.cc/release/nssm-2.24.zip)
#      解压到 C:\Tools\nssm-2.24\win64\nssm.exe
#
#  作用:
#    1. 创建 logs/ 目录
#    2. 注册 HealthMgmtBackend 服务 (NSSM + Spring Boot jar)
#    3. 注册 HealthMgmtFrontend 服务 (NSSM + Vite dev)
#    4. 设置自启动, 失败自动重启
#
#  用法 (管理员 PowerShell):
#    PS> .\install-services.ps1
# ============================================================================

[CmdletBinding()]
param(
    [string]$NssmPath = "C:\Tools\nssm-2.24\win64\nssm.exe",
    [int]$BackendPort = 8090,
    [int]$FrontendPort = 5176,
    [string]$ProjectRoot = "..\.."
)

$ErrorActionPreference = "Stop"
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# ---- 管理员权限检查 ----
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "❌ 必须用管理员身份运行 PowerShell" -ForegroundColor Red
    Write-Host "   右键 PowerShell → 以管理员身份运行 → 重新执行本脚本" -ForegroundColor Yellow
    exit 1
}

# ---- NSSM 检查 ----
if (-not (Test-Path $NssmPath)) {
    Write-Host "❌ NSSM 不存在: $NssmPath" -ForegroundColor Red
    Write-Host ""
    Write-Host "下载 NSSM 2.24:" -ForegroundColor Yellow
    Write-Host "   1. 访问 https://nssm.cc/release/nssm-2.24.zip" -ForegroundColor Yellow
    Write-Host "   2. 解压到 C:\Tools\nssm-2.24\" -ForegroundColor Yellow
    Write-Host "   3. 重试" -ForegroundColor Yellow
    exit 2
}
Write-Host "✅ NSSM: $NssmPath`n" -ForegroundColor Green

# ---- 路径定位 ----
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$AbsRoot = Resolve-Path (Join-Path $ScriptDir $ProjectRoot) | Select-Object -ExpandProperty Path
$JarPath = Join-Path $AbsRoot "target\health-management-1.0.0.jar"

if (-not (Test-Path $JarPath)) {
    Write-Host "❌ 找不到 jar: $JarPath, 先跑 start-backend.ps1 或 mvn package" -ForegroundColor Red
    exit 3
}

# ---- JDK ----
if (-not $env:JAVA_HOME) {
    Write-Host "❌ JAVA_HOME 未设置, 服务无法启动 java" -ForegroundColor Red
    Write-Host "   setx JAVA_HOME 'C:\Program Files\Eclipse Adoptium\jdk-17'" -ForegroundColor Yellow
    exit 4
}
$javaBin = Join-Path $env:JAVA_HOME "bin\java.exe"
if (-not (Test-Path $javaBin)) {
    Write-Host "❌ JAVA_HOME/bin/java.exe 不存在: $javaBin" -ForegroundColor Red
    exit 4
}

# ---- 日志目录 ----
$logDir = Join-Path $ScriptDir "logs"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }

# ---- 工具函数 ----
function Install-NssmService {
    param(
        [string]$Name,
        [string]$Exe,
        [string]$Args,
        [string]$DisplayName,
        [string]$Description,
        [string]$StdoutLog,
        [string]$StderrLog
    )
    Write-Host "📦 安装服务: $Name" -ForegroundColor Cyan

    # 如果已存在, 先停止 + 移除
    & $NssmPath stop   $Name 2>$null | Out-Null
    & $NssmPath remove $Name confirm 2>$null | Out-Null
    Start-Sleep -Seconds 1

    # install
    & $NssmPath install $Name $Exe $Args | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "nssm install 失败 ($LASTEXITCODE)" }

    & $NssmPath set $Name DisplayName $DisplayName | Out-Null
    & $NssmPath set $Name Description $Description | Out-Null
    & $NssmPath set $Name Start SERVICE_AUTO_START | Out-Null
    & $NssmPath set $Name AppStdout $StdoutLog | Out-Null
    & $NssmPath set $Name AppStderr $StderrLog | Out-Null
    & $NssmPath set $Name AppRotateFiles 1 | Out-Null
    & $NssmPath set $Name AppRotateBytes 10485760 | Out-Null  # 10MB 单文件

    # 失败自动重启
    & $NssmPath set $Name AppExit Default Restart | Out-Null
    & $NssmPath set $Name AppRestartDelay 5000 | Out-Null

    Write-Host "✅ $Name 已安装 (类型: AUTO_START, 失败重启)" -ForegroundColor Green
}

# ---- 注册后端服务 ----
# 关键: -D 必须在 -jar 前 (NSSM 踩坑 #5)
# 关键: 整个 AppParameters 用单引号, 保留 $ 给 JVM (NSSM 踩坑 #6)
$backendArgs = "`"$javaBin`" -Dfile.encoding=UTF-8 -Dspring.profiles.active=prod -Dserver.port=$BackendPort -jar `"$JarPath`""
$backendArgs = $backendArgs -replace '"','""'  # nssm set 参数需要双引号转义? 不, 我们直接 set string

# NSSM 实际接受 string 用空格分隔的 exe + args, 简单做法:
#   nssm set Name Application <exe>
#   nssm set Name AppParameters <args>
# 所以分开设置
Install-NssmService `
    -Name "HealthMgmtBackend" `
    -Exe $javaBin `
    -Args "-Dfile.encoding=UTF-8 -Dspring.profiles.active=prod -Dserver.port=$BackendPort -jar `"$JarPath`"" `
    -DisplayName "健康管理系统 - 后端" `
    -Description "Spring Boot + MyBatis-Plus 后端服务 (健康管理系统)" `
    -StdoutLog (Join-Path $logDir "backend.out.log") `
    -StderrLog (Join-Path $logDir "backend.err.log")

# ---- 注册前端服务 ----
$npmBin = (Get-Command npm).Source
$npmDir = Split-Path -Parent $npmBin
$nodeBin = Join-Path $npmDir "node.exe"

$frontendDir = Join-Path $AbsRoot "frontend"

# nssm 跑 npm 会有 cmd 包装问题, 用 node 直接跑 vite
$frontendWorkDir = $frontendDir

# 这里用 nssm + node 直接运行 vite (需要 package.json 已 install)
$viteCmd = Join-Path $frontendDir "node_modules\.bin\vite.cmd"
if (Test-Path $viteCmd) {
    Install-NssmService `
        -Name "HealthMgmtFrontend" `
        -Exe $viteCmd `
        -Args "--host 0.0.0.0 --port $FrontendPort" `
        -DisplayName "健康管理系统 - H5" `
        -Description "Vue 3 + Vite H5 开发服务器" `
        -StdoutLog (Join-Path $logDir "frontend.out.log") `
        -StderrLog (Join-Path $logDir "frontend.err.log")
} else {
    Write-Host "`n⚠️  frontend/node_modules 不存在, 跳过前端服务" -ForegroundColor Yellow
    Write-Host "   先跑 start-frontend.ps1 让它 npm install, 再重新 install-services" -ForegroundColor Yellow
}

# ---- 启动 ----
Write-Host "`n🚀 启动服务..." -ForegroundColor Cyan
& $NssmPath start HealthMgmtBackend | Out-Null
if (Test-Path $viteCmd) {
    & $NssmPath start HealthMgmtFrontend | Out-Null
}

Start-Sleep -Seconds 3

Write-Host "`n🎉 安装完成!" -ForegroundColor Green
Write-Host "   后端 PID: $((Get-Service HealthMgmtBackend -ErrorAction SilentlyContinue).Status)" -ForegroundColor White
Write-Host ""
Write-Host "📝 常用命令:" -ForegroundColor Cyan
Write-Host "   sc query HealthMgmtBackend          # 查询状态" -ForegroundColor White
Write-Host "   sc stop HealthMgmtBackend           # 停止" -ForegroundColor White
Write-Host "   sc start HealthMgmtBackend          # 启动" -ForegroundColor White
Write-Host "   services.msc                        # 图形管理" -ForegroundColor White
Write-Host "   .\uninstall-services.ps1            # 卸载" -ForegroundColor White
