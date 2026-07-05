# UTF-8 BOM (必备, 否则中文注释乱码)
<#
.SYNOPSIS
  启动 PC Web 桌面端 (frontend-pc)

.DESCRIPTION
  - 检查 Node.js + npm
  - 检查 node_modules (没有就跑 npm install)
  - 检查 dist (没有就跑 npm run build)
  - 启动 vite preview (生产模式, 端口 5174)
  - 后端通过 Vite proxy 转发 /api 到 http://localhost:8090

.PARAMETER NodeExe
  Node.js 可执行文件路径 (默认 where.exe 自动搜)

.PARAMETER FrontendDir
  frontend-pc 目录路径 (默认 D:\health-mgmt\frontend-pc)

.EXAMPLE
  .\start-frontend-pc.ps1
  .\start-frontend-pc.ps1 -FrontendDir "D:\myapp\frontend-pc"
#>
[CmdletBinding()]
param(
    [string]$NodeExe = "",
    [string]$FrontendDir = "D:\health-mgmt\frontend-pc"
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  健康管理系统 - PC Web 启动器" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# === 1. 找 node.exe ===
if (-not $NodeExe) {
    $nodePath = & where.exe node 2>$null | Select-Object -First 1
    if ($nodePath) {
        $NodeExe = $nodePath
        Write-Host "✅ node: $NodeExe" -ForegroundColor Green
    } else {
        Write-Host "❌ 找不到 node.exe" -ForegroundColor Red
        Write-Host "   请先安装 Node.js 18+: https://nodejs.org/" -ForegroundColor Yellow
        Write-Host "   或指定 -NodeExe 'C:\path\to\node.exe'" -ForegroundColor Yellow
        exit 1
    }
} else {
    if (-not (Test-Path $NodeExe)) {
        Write-Host "❌ NodeExe 不存在: $NodeExe" -ForegroundColor Red
        exit 1
    }
    Write-Host "✅ node: $NodeExe" -ForegroundColor Green
}

# === 2. 找 frontend-pc 目录 ===
if (-not (Test-Path $FrontendDir)) {
    Write-Host "❌ FrontendDir 不存在: $FrontendDir" -ForegroundColor Red
    Write-Host "   请确认路径正确, 或指定 -FrontendDir '...'" -ForegroundColor Yellow
    exit 1
}
Write-Host "✅ frontend-pc: $FrontendDir" -ForegroundColor Green

# === 3. 检查 node_modules ===
$nodeModules = Join-Path $FrontendDir "node_modules"
if (-not (Test-Path $nodeModules)) {
    Write-Host ""
    Write-Host "⏳ node_modules 不存在, 跑 npm install..." -ForegroundColor Yellow
    Push-Location $FrontendDir
    try {
        & npm install 2>&1 | Select-Object -Last 20
        if ($LASTEXITCODE -ne 0) {
            Write-Host "❌ npm install 失败" -ForegroundColor Red
            Pop-Location
            exit 1
        }
    } finally {
        Pop-Location
    }
    Write-Host "✅ npm install 完成" -ForegroundColor Green
}

# === 4. 检查 dist ===
$distDir = Join-Path $FrontendDir "dist"
if (-not (Test-Path $distDir)) {
    Write-Host ""
    Write-Host "⏳ dist 不存在, 跑 npm run build..." -ForegroundColor Yellow
    Push-Location $FrontendDir
    try {
        & npm run build 2>&1 | Select-Object -Last 15
        if ($LASTEXITCODE -ne 0) {
            Write-Host "❌ npm run build 失败" -ForegroundColor Red
            Pop-Location
            exit 1
        }
    } finally {
        Pop-Location
    }
    Write-Host "✅ npm run build 完成" -ForegroundColor Green
}

# === 5. 启动 vite preview ===
Write-Host ""
Write-Host "🚀 启动 PC Web (端口 5174)..." -ForegroundColor Green
Write-Host "   浏览器打开: http://localhost:5174/" -ForegroundColor Cyan
Write-Host "   演示账号: admin / root · user_wang / root · doctor_zhang / root" -ForegroundColor Cyan
Write-Host ""
Write-Host "   Ctrl+C 退出" -ForegroundColor Gray
Write-Host ""

Push-Location $FrontendDir
try {
    # vite preview 会运行在 5174 端口, 后端 /api 通过 proxy 转发到 8090
    & npx vite preview --host 0.0.0.0 --port 5174
} finally {
    Pop-Location
}