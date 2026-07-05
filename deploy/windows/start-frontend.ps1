# ============================================================================
#  start-frontend.ps1 - 启动健康管理系统 H5 (Vue 3 + Vite dev server)
# ============================================================================
#
#  用法:
#    PS> .\start-frontend.ps1         # 默认端口 5176
#    PS> .\start-frontend.ps1 -Build   # 先 build 到 frontend/dist 再用 preview
#
#  说明:
#    - dev 模式: Vite dev server, 热更新, 需要 src 源码
#    - build 模式: 静态 dist, 用 vite preview, 适合生产
#
#  后端 API 反代: vite.config.js 已配 /api → http://localhost:8090
# ============================================================================

[CmdletBinding()]
param(
    [switch]$Build = $false,
    [string]$ProjectRoot = "..\..",
    [string]$LogFile = "logs\frontend.log"
)

$ErrorActionPreference = "Continue"
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$AbsRoot = Resolve-Path (Join-Path $ScriptDir $ProjectRoot) | Select-Object -ExpandProperty Path
$FrontendDir = Join-Path $AbsRoot "frontend"

if (-not (Test-Path $FrontendDir)) {
    Write-Host "❌ 找不到 $FrontendDir" -ForegroundColor Red
    exit 1
}

# ---- Node 检查 ----
$node = Get-Command node -ErrorAction SilentlyContinue
$npm = Get-Command npm -ErrorAction SilentlyContinue
if (-not $node -or -not $npm) {
    Write-Host "❌ 未检测到 node/npm, 请安装 Node.js 18+ LTS" -ForegroundColor Red
    Write-Host "   下载: https://nodejs.org/" -ForegroundColor Yellow
    exit 2
}
Write-Host "✅ Node $(& node --version) / npm $(& npm --version)" -ForegroundColor Green

# ---- npm install ----
$nodeModules = Join-Path $FrontendDir "node_modules"
$packageLock = Join-Path $FrontendDir "package-lock.json"
if (-not (Test-Path $nodeModules) -or
    (Test-Path $packageLock) -and
    (Get-Item $packageLock).LastWriteTime -gt (Get-Item $nodeModules).LastWriteTime) {
    Write-Host "`n📦 安装 frontend 依赖 (首次 / lock 变了)..." -ForegroundColor Cyan
    Push-Location $FrontendDir
    try { & npm install --no-audit --no-fund 2>&1 | Tee-Object -FilePath "$ScriptDir\$LogFile" -Append }
    finally { Pop-Location }
}

# ---- 日志目录 ----
$logDir = Join-Path $ScriptDir "logs"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }

# ---- 启动 ----
Push-Location $FrontendDir
try {
    if ($Build) {
        Write-Host "`n🏗️  Build H5 静态产物..." -ForegroundColor Cyan
        & npm run build 2>&1 | Tee-Object -FilePath "$ScriptDir\$LogFile" -Append | Out-Null
        Write-Host "`n🚀 启动 vite preview (静态模式, 端口 5176)..." -ForegroundColor Cyan
        & npm run preview 2>&1 | Tee-Object -FilePath "$ScriptDir\$LogFile" -Append | Out-Null
    } else {
        Write-Host "`n🚀 启动 vite dev (开发模式, 端口 5176)..." -ForegroundColor Cyan
        & npm run dev 2>&1 | Tee-Object -FilePath "$ScriptDir\$LogFile" -Append | Out-Null
    }
}
finally {
    Pop-Location
}
