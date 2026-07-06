# ============================================================================
#  start-frontend-pc.ps1 - 启动 PC Web 桌面端 (v2)
# ============================================================================
#
#  用法:
#    PS> .\start-frontend-pc.ps1
#    PS> .\start-frontend-pc.ps1 -FrontendDir "D:\health-mgmt\frontend-pc"
#
#  OPC_K 部署 SOP (2026-07-06):
#    - 杀 node 进程用 Get-Process (PowerShell 原生)
#    - UTF-8 BOM 必备
#
#  历史踩坑 (2026-07-06):
#    - 杀 node.exe 也用 taskkill 抛错, 改用 Get-Process
# ============================================================================

[CmdletBinding()]
param(
    [string]$NodeExe = "",
    [string]$FrontendDir = "D:\health-mgmt\frontend-pc",
    [int]$Port = 5174
)

$ErrorActionPreference = "Stop"
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# ---- 杀旧 node 进程 (Get-Process, 不抛错) ----
$nodeproc = Get-Process -Name node -ErrorAction SilentlyContinue
if ($nodeproc) {
    Write-Host "杀旧 node 进程..." -ForegroundColor Cyan
    foreach ($p in $nodeproc) {
        try { Stop-Process -Id $p.Id -Force -ErrorAction Stop } catch {}
    }
    Start-Sleep -Seconds 2
}

# ---- 端口检测 ----
$portInUse = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
if ($portInUse) {
    Write-Host "[WARN] 端口 $Port 已被占用 (PID $($portInUse.OwningProcess))" -ForegroundColor Yellow
    Write-Host "  杀: Stop-Process -Id $($portInUse.OwningProcess) -Force" -ForegroundColor Gray
    Write-Host "  或换端口: -Port 5175" -ForegroundColor Gray
    exit 1
}

# ---- 找 node.exe ----
if (-not $NodeExe) {
    $nodePath = & where.exe node 2>$null | Select-Object -First 1
    if ($nodePath) {
        $NodeExe = $nodePath
    } else {
        Write-Host "[FAIL] 找不到 node.exe" -ForegroundColor Red
        Write-Host "  装 Node.js 18+: https://nodejs.org/" -ForegroundColor Yellow
        exit 2
    }
}
Write-Host "node: $NodeExe" -ForegroundColor Cyan

# ---- 找 frontend-pc ----
if (-not (Test-Path $FrontendDir)) {
    Write-Host "[FAIL] FrontendDir 不存在: $FrontendDir" -ForegroundColor Red
    exit 3
}
Write-Host "frontend-pc: $FrontendDir" -ForegroundColor Cyan

# ---- node_modules ----
$nodeModules = Join-Path $FrontendDir "node_modules"
if (-not (Test-Path $nodeModules)) {
    Write-Host ""
    Write-Host "node_modules 不存在, 跑 npm install..." -ForegroundColor Yellow
    Push-Location $FrontendDir
    try {
        & npm install 2>&1 | Select-Object -Last 20
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[FAIL] npm install 失败" -ForegroundColor Red
            Pop-Location
            exit 4
        }
    } finally { Pop-Location }
    Write-Host "OK" -ForegroundColor Green
}

# ---- dist ----
$distDir = Join-Path $FrontendDir "dist"
if (-not (Test-Path $distDir)) {
    Write-Host ""
    Write-Host "dist 不存在, 跑 npm run build..." -ForegroundColor Yellow
    Push-Location $FrontendDir
    try {
        & npm run build 2>&1 | Select-Object -Last 15
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[FAIL] npm run build 失败" -ForegroundColor Red
            Pop-Location
            exit 5
        }
    } finally { Pop-Location }
    Write-Host "OK" -ForegroundColor Green
}

# ---- 启动 vite preview ----
Write-Host ""
Write-Host "启动 PC Web (端口 $Port)..." -ForegroundColor Cyan
Write-Host "  浏览器: http://localhost:$Port/" -ForegroundColor Gray
Write-Host "  演示账号: admin / root" -ForegroundColor Gray
Write-Host "  Ctrl+C 退出" -ForegroundColor Gray
Write-Host ""

Push-Location $FrontendDir
try {
    & npx vite preview --host 0.0.0.0 --port $Port
} finally {
    Pop-Location
}
