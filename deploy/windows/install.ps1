#Requires -RunAsAdministrator
<#
.SYNOPSIS
  install.ps1 - 健康管理系统一键部署 v4.1 (health-mgmt)
.DESCRIPTION
  1 个脚本搞定全部部署 (基于 PowerShell 5.1 实战派学习手册 v4.1):

    Step 1: 检测管理员权限
    Step 2: 检测 MariaDB (路径含空格)
    Step 3: 检测 Java (JDK 17+)
    Step 4: 端口冲突检查 (友好提示)
    Step 5: 启动 MariaDB (service 优先 / mariadbd 后备)
    Step 6: 自动检测 root 密码 (空 / opck2026 / 自定义) + 失败回退到 5 步 reset
    Step 7: 初始化数据库 (DROP + CREATE + 15 表 + 种子)
    Step 8: 启动后端 (Start-Process -WindowStyle Hidden + 反引号路径)
    Step 9: 启动前端 (python -m http.server 零依赖)
    Step 10: 健康检查 + 输出访问 URL

  用法 (管理员 PowerShell):
    PS> cd C:\path\to\health-mgmt\deploy\windows
    PS> .\install.ps1
    PS> .\install.ps1 -DbPassword opck2026
    PS> .\install.ps1 -DbPassword opck2026 -BackendPort 8090 -FrontendPort 5173

  进程用 Start-Process -WindowStyle Hidden 后台跑, 关 PowerShell 窗口不停.

.NOTES
  Version History:
  v4.0 (2026-07-06 21:35) - 极简一键部署
  v4.1 (2026-07-06 22:34) - 基于 PowerShell 5.1 学习手册重写:
    - ✅ 自动检测 root 密码 (空 / opck2026 / 自定义)
    - ✅ 失败自动跑 5 步 reset (前端 + 后端协同)
    - ✅ datadir 自动探测 (my.ini)
    - ✅ Start-Process 含空格路径用反引号转义
    - ✅ Get-Content 全部加 -Encoding UTF8
    - ✅ mysql 客户端 -h "127.0.0.1" 加空格 + 双引号 (避免 PS 5.1 截断)
    - ✅ $LASTEXITCODE 立即快照
    - ✅ 这里-string 全部禁用 (改用 .sql 文件 + Copy-Item)
    - ✅ mariadbd 启动参数必加 --character-set-server=utf8mb4
    - ✅ 所有 ps1 UTF-8 BOM
#>

[CmdletBinding()]
param(
    [string]$DbHost = "127.0.0.1",
    [int]$DbPort = 3306,
    [string]$DbName = "health_management",
    [string]$DbUser = "root",
    [string]$DbPassword = "opck2026",
    [int]$BackendPort = 8090,
    [int]$FrontendPort = 5173,
    [string]$ProjectRoot = "",
    [switch]$AutoResetRoot  # 密码错自动跑 5 步 reset
)

# ============================================================
# 0. 初始化: UTF-8 + 错误处理
# ============================================================
$ErrorActionPreference = "Stop"
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# ============================================================
# 1. 路径定位 (v4.1.1 自动探测 ProjectRoot)
# ============================================================
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# 关键修复 v4.1.1: 自动探测 ProjectRoot, 在 4 个候选位置找 sql\init.sql
# 解决: 进哥从 D:\BaiduNetdiskDownload\health-mgmt-deploy-v4.1\deploy\windows\ 跑时
# `..\..` 被 PS 5.1 解析成 D:\, 找不到 jar/sql/dist
function Find-ProjectRoot {
    param([string]$ScriptDirPath)
    $candidates = @(
        (Get-Location).Path,                                              # cwd
        $ScriptDirPath,                                                   # scripts dir
        (Split-Path -Parent $ScriptDirPath),                              # 上一层
        (Split-Path -Parent (Split-Path -Parent $ScriptDirPath))          # 上两层
    )
    foreach ($p in $candidates) {
        $try = $p
        try {
            $resolved = (Resolve-Path $try -ErrorAction Stop).Path
            $test = Join-Path $resolved "sql\init.sql"
            if (Test-Path $test) {
                return $resolved
            }
        } catch {}
    }
    return $null
}

$ResolvedRoot = Find-ProjectRoot -ScriptDirPath $ScriptDir
if (-not $ResolvedRoot) {
    if ([string]::IsNullOrEmpty($ProjectRoot)) {
        Write-Host "  [FAIL] 自动探测 ProjectRoot 失败, sql\init.sql 不在常见位置" -ForegroundColor Red
        Write-Host "  请用 -ProjectRoot D:\path\to\health-mgmt 显式指定" -ForegroundColor Yellow
        exit 1
    }
    $ResolvedRoot = (Resolve-Path $ProjectRoot).Path
}

$JarPath = Join-Path $ResolvedRoot "target\health-management-1.0.0.jar"
$DistPath = Join-Path $ResolvedRoot "frontend-pc\dist"
$InitSql = Join-Path $ResolvedRoot "sql\init.sql"
$ResetSql = Join-Path $ScriptDir "reset-root-simple.sql"

# v4.1.1 fallback: 在 ResolvedRoot 上级找 jar (zip 顶层放 jar 时)
if (-not (Test-Path $JarPath)) {
    $JarPathAlt = Join-Path (Split-Path -Parent $ResolvedRoot) "health-management-1.0.0.jar"
    if (Test-Path $JarPathAlt) {
        Write-Host "  [INFO] 从上层目录找 jar: $JarPathAlt" -ForegroundColor Yellow
        $JarPath = $JarPathAlt
        # 上层目录同时是实际 ProjectRoot (有 init.sql)
        $altRoot = Split-Path -Parent $ResolvedRoot
        if (Test-Path (Join-Path $altRoot "sql\init.sql")) {
            $ResolvedRoot = $altRoot
            $InitSql = Join-Path $ResolvedRoot "sql\init.sql"
        }
    }
}
# 同 fallback: init.sql 也可能在 ResolvedRoot 上层
if (-not (Test-Path $InitSql)) {
    $InitSqlAlt = Join-Path (Split-Path -Parent $ResolvedRoot) "init.sql"
    if (Test-Path $InitSqlAlt) {
        Write-Host "  [INFO] 从上层目录找 init.sql: $InitSqlAlt" -ForegroundColor Yellow
        $InitSql = $InitSqlAlt
        $ResolvedRoot = Split-Path -Parent $ResolvedRoot
    }
}

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  健康管理系统 一键部署 v4.1.1" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Project root: $ResolvedRoot" -ForegroundColor Gray
Write-Host "Backend jar:  $JarPath" -ForegroundColor Gray
Write-Host "Frontend dist: $DistPath" -ForegroundColor Gray
Write-Host "Init SQL:     $InitSql" -ForegroundColor Gray
Write-Host ""

# ============================================================
# 2. 工具函数 (端口检测 / 路径转义)
# ============================================================

function Test-Port {
    param([int]$Port)
    return Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
}

# 检查 SQL 文件是否带 BOM
function Test-Bom {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return $false }
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    return ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
}

# v4.1.1 关键修复: Test-MysqlAuth 用 array args + try/catch + 2>$null
# 解决进哥 22:51 报错: -p$Pwd 当 Pwd 为空时拼成 -p, mysql 误判
# 同时解决 RemoteException (mysql.exe stderr) 中断 ps 流程
function Test-MysqlAuth {
    param([string]$Pwd)
    try {
        if ([string]::IsNullOrEmpty($Pwd)) {
            # 空密码: 不要 -p 参数
            $argList = @("-h", "127.0.0.1", "-P", "$DbPort", "-u", $DbUser, "--default-character-set=utf8mb4", "-e", "SELECT VERSION();")
        } else {
            $argList = @("-h", "127.0.0.1", "-P", "$DbPort", "-u", $DbUser, "-p$Pwd", "--default-character-set=utf8mb4", "-e", "SELECT VERSION();")
        }
        & $mysqlExe $argList 2>$null 3>$null | Out-Null
        return ($LASTEXITCODE -eq 0)
    } catch {
        return $false
    }
}

# ============================================================
# 3. Step 1: 管理员权限
# ============================================================
Write-Host "[1/9] 检测管理员权限 ..." -ForegroundColor Cyan
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "  [FAIL] 请用管理员 PowerShell 跑 (右键 PowerShell -> Run as administrator)" -ForegroundColor Red
    exit 1
}
Write-Host "  OK" -ForegroundColor Green

# ============================================================
# 4. Step 2: 检测 MariaDB (路径含空格)
# ============================================================
Write-Host "[2/9] 检测 MariaDB ..." -ForegroundColor Cyan
$mariadbBin = ""
$candidates = @(
    "C:\Program Files\MariaDB*\bin\mysql.exe",
    "C:\Program Files (x86)\MariaDB*\bin\mysql.exe",
    "D:\Program Files\MariaDB*\bin\mysql.exe"
)
foreach ($p in $candidates) {
    $found = Get-Item $p -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) { $mariadbBin = Split-Path -Parent $found.FullName; break }
}
if (-not $mariadbBin) {
    Write-Host "  [FAIL] 找不到 MariaDB" -ForegroundColor Red
    Write-Host "  请先安装: https://mariadb.org/download/" -ForegroundColor Yellow
    exit 2
}
$mysqlExe = Join-Path $mariadbBin "mysql.exe"
$mariadbdExe = Join-Path $mariadbBin "mariadbd.exe"
Write-Host "  OK ($mariadbBin)" -ForegroundColor Green

# ============================================================
# 5. Step 3: 检测 Java
# ============================================================
Write-Host "[3/9] 检测 Java (JDK 17+) ..." -ForegroundColor Cyan
$javaExe = ""
try {
    $cmd = Get-Command java -ErrorAction SilentlyContinue
    if ($cmd) { $javaExe = if ($cmd.Source) { $cmd.Source } elseif ($cmd.Path) { $cmd.Path } else { "" } }
} catch {}
if (-not $javaExe) {
    $candidates = @(
        "C:\Program Files\Java\jdk*\bin\java.exe",
        "C:\Program Files\Eclipse Adoptium\jdk*\bin\java.exe",
        "C:\Program Files\Microsoft\jdk*\bin\java.exe"
    )
    foreach ($p in $candidates) {
        $found = Get-Item $p -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) { $javaExe = $found.FullName; break }
    }
}
if (-not $javaExe) {
    Write-Host "  [FAIL] 找不到 Java" -ForegroundColor Red
    Write-Host "  请安装 JDK 17: https://adoptium.net/" -ForegroundColor Yellow
    exit 3
}
Write-Host "  OK ($javaExe)" -ForegroundColor Green

# ============================================================
# 6. Step 4: 端口冲突检查
# ============================================================
Write-Host "[4/9] 检查端口 $DbPort / $BackendPort / $FrontendPort ..." -ForegroundColor Cyan
$ports = @(
    @{Name="DB"; Port=$DbPort},
    @{Name="Backend"; Port=$BackendPort},
    @{Name="Frontend"; Port=$FrontendPort}
)
$portBusy = $false
foreach ($p in $ports) {
    if (Test-Port -Port $p.Port) {
        Write-Host "  [WARN] $($p.Name) port $($p.Port) 已被占用" -ForegroundColor Yellow
        $portBusy = $true
    }
}
if ($portBusy) {
    Write-Host ""
    Write-Host "  占用进程:" -ForegroundColor Yellow
    Get-NetTCPConnection -LocalPort $DbPort,$BackendPort,$FrontendPort -State Listen -ErrorAction SilentlyContinue |
        Select-Object LocalPort, OwningProcess, @{Name="Process";Expression={(Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue).ProcessName}} |
        Format-Table -AutoSize | Out-String | Write-Host -ForegroundColor Gray
    Write-Host "  请先 .\stop-all.ps1 停掉旧服务, 或者用 -BackendPort/-FrontendPort/-DbPort 换端口" -ForegroundColor Yellow
    $confirm = Read-Host "  是否继续? (y/N)"
    if ($confirm -ne "y" -and $confirm -ne "Y") {
        exit 4
    }
}
Write-Host "  OK" -ForegroundColor Green

# ============================================================
# 7. Step 5: 启动 MariaDB
# ============================================================
Write-Host "[5/9] 启动 MariaDB ..." -ForegroundColor Cyan

# 自动探测 datadir (my.ini 路径) - v4.1.1 修复 Select-String 输出
$mariadbDataDir = ""
$myIni = Get-ChildItem -Path (Split-Path -Parent $mariadbBin) -Recurse -Filter "my.ini" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($myIni) {
    Write-Host "  找到 my.ini: $($myIni.FullName)" -ForegroundColor Gray
    # 从 my.ini 读 datadir
    $datadirLine = Select-String -Path $myIni.FullName -Pattern "^datadir\s*=" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($datadirLine) {
        # v4.1.1 关键修复: Select-String 输出格式是 "filename:line:content"
        # 例: "C:\Program Files\MariaDB 11.8\data\my.ini:2:datadir=C:/Program Files/MariaDB 11.8/data"
        # 必须先 strip filename:line: 前缀
        $rawLine = $datadirLine.ToString()
        $datadirValue = ""
        # 方法 1: 找 ":datadir=" 这个关键标识
        $idx = $rawLine.IndexOf("datadir=", [System.StringComparison]::OrdinalIgnoreCase)
        if ($idx -ge 0) {
            $datadirValue = $rawLine.Substring($idx + "datadir=".Length).Trim()
        }
        # 方法 2 (fallback): 用 split 找冒号后面内容
        if (-not $datadirValue) {
            $parts = $rawLine -split ':', 3
            if ($parts.Length -ge 3) {
                $datadirValue = $parts[2].Trim()
            }
        }
        # 去掉行尾注释 (# 或 ;)
        $datadirValue = ($datadirValue -replace '\s*[#;].*$', '').Trim()
        # 把 Unix 路径分隔符转 Windows (C:/Program Files/ -> C:\Program Files\)
        $datadirValue = $datadirValue -replace '/', '\'
        $mariadbDataDir = $datadirValue
        Write-Host "  探测 datadir: $mariadbDataDir" -ForegroundColor Gray
    }
}
if (-not $mariadbDataDir -or -not (Test-Path $mariadbDataDir)) {
    $mariadbDataDir = "C:\Program Files\MariaDB 11.8\data"
    Write-Host "  使用默认 datadir: $mariadbDataDir" -ForegroundColor Gray
}

# 检查 service 形式
$svc = Get-Service -Name MariaDB -ErrorAction SilentlyContinue
if ($svc -and $svc.Status -eq "Running") {
    Write-Host "  OK (service 已在跑: MariaDB)" -ForegroundColor Green
} elseif ($svc) {
    net start MariaDB | Out-Null
    Start-Sleep -Seconds 3
    Write-Host "  OK (service 已启动)" -ForegroundColor Green
} else {
    # 没 service, mariadbd 后台启 (含 utf8mb4 参数)
    $mariadbLog = Join-Path $env:TEMP "mariadbd-install.log"
    if (Test-Port -Port $DbPort) {
        Write-Host "  port $DbPort 已被占用, 跳过启动 MariaDB" -ForegroundColor Yellow
    } else {
        $argStr = "--datadir=`"$mariadbDataDir`" --port=$DbPort --character-set-server=utf8mb4 --character-set-filesystem=utf8mb4"
        Write-Host "  args: $argStr" -ForegroundColor Gray
        Start-Process -FilePath $mariadbdExe -ArgumentList $argStr -WindowStyle Hidden -RedirectStandardOutput $mariadbLog -RedirectStandardError "$mariadbLog.err"
        Start-Sleep -Seconds 5
        if (Test-Port -Port $DbPort) {
            Write-Host "  OK (mariadbd 后台跑, log: $mariadbLog)" -ForegroundColor Green
        } else {
            Write-Host "  [FAIL] mariadbd 未监听 port $DbPort" -ForegroundColor Red
            if (Test-Path "$mariadbLog.err") {
                Get-Content "$mariadbLog.err" -Tail 20 | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
            }
            exit 5
        }
    }
}

# ============================================================
# 8. Step 6: 自动检测 root 密码 (空 / opck2026 / 自定义)
# ============================================================
Write-Host "[6/9] 探测 root 密码 ..." -ForegroundColor Cyan
# v4.1.1: Test-MysqlAuth 已上移到工具函数区 (array args + try/catch)
# 测试顺序: socket (空密码从 127.0.0.1 大概率空 OK) -> 空 / opck2026

$detectedPwd = $null
$testPwds = @("", $DbPassword)
foreach ($pwd in $testPwds) {
    $displayPwd = if ($pwd -eq "") { "<空>" } else { $pwd }
    Write-Host "  试密码: $displayPwd ..." -ForegroundColor Gray -NoNewline
    if (Test-MysqlAuth -Pwd $pwd) {
        Write-Host " OK" -ForegroundColor Green
        $detectedPwd = $pwd
        break
    } else {
        Write-Host " FAIL" -ForegroundColor Yellow
    }
}

if (-not $detectedPwd) {
    Write-Host "  [FAIL] 默认密码 (空/opck2026) 都不通" -ForegroundColor Red
    if ($AutoResetRoot) {
        Write-Host "  自动跑 5 步 reset ..." -ForegroundColor Cyan
        # 调用 reset-root 自动脚本
        & "$ScriptDir\reset-root-auto.ps1" -MariadbBin $mariadbBin -MariadbDataDir $mariadbDataDir -DbPort $DbPort -DbUser $DbUser -NewPassword $DbPassword -MysqlExe $mysqlExe
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  [FAIL] 5 步 reset 失败, 请手动跑 reset-root-password.md" -ForegroundColor Red
            exit 6
        }
        $detectedPwd = $DbPassword
    } else {
        Write-Host ""
        Write-Host "  选项:" -ForegroundColor Yellow
        Write-Host "    A) 重跑: .\install.ps1 -AutoResetRoot" -ForegroundColor White
        Write-Host "    B) 手动: 看 reset-root-password.md 5 步法" -ForegroundColor White
        exit 6
    }
}

Write-Host "  OK (root 密码 = $(if ($detectedPwd -eq '') {'<空>'} else {$detectedPwd}))" -ForegroundColor Green

# ============================================================
# 9. Step 7: 初始化数据库
# ============================================================
Write-Host "[7/9] 初始化 $DbName 库 ..." -ForegroundColor Cyan

if (-not (Test-Path $InitSql)) {
    Write-Host "  [FAIL] 找不到 $InitSql" -ForegroundColor Red
    exit 7
}

# 检查 SQL 是否带 BOM
if (-not (Test-Bom -Path $InitSql)) {
    Write-Host "  [WARN] $InitSql 缺 UTF-8 BOM, 中文可能乱码" -ForegroundColor Yellow
    Write-Host "  加 BOM 中 ..." -ForegroundColor Gray
    $bytes = [System.IO.File]::ReadAllBytes($InitSql)
    if ($bytes[0] -ne 0xEF -or $bytes[1] -ne 0xBB -or $bytes[2] -ne 0xBF) {
        $bytes = [byte[]](0xEF, 0xBB, 0xBF) + $bytes
        [System.IO.File]::WriteAllBytes($InitSql, $bytes)
        Write-Host "  OK (加了 BOM)" -ForegroundColor Green
    }
}

# 关键 v4.1.1: 用 array args 替代字符串拼 (-p$pwd 当 pwd 为空会出错)
# 关键: Get-Content -Encoding UTF8 (避免 GBK 解码乱码)
if ([string]::IsNullOrEmpty($detectedPwd)) {
    # 空密码不传 -p
    $initArgList = @("-h", "127.0.0.1", "-P", "$DbPort", "-u", $DbUser, "--default-character-set=utf8mb4")
} else {
    $initArgList = @("-h", "127.0.0.1", "-P", "$DbPort", "-u", $DbUser, "-p$detectedPwd", "--default-character-set=utf8mb4")
}
try {
    Get-Content $InitSql -Encoding UTF8 | & $mysqlExe $initArgList 2>$null 3>$null | Out-Null
    $mysqlExit = $LASTEXITCODE   # ← 立即快照, 后续不丢
} catch {
    $mysqlExit = 1
    Write-Host "  [WARN] init.sql 调用抛 RemoteException (PowerShell 5.1 已知问题)" -ForegroundColor Yellow
}
if ($mysqlExit -ne 0) {
    Write-Host "  [FAIL] init.sql 跑失败 (exit $mysqlExit)" -ForegroundColor Red
    Write-Host "  可能原因: 数据库密码不对 / init.sql 语法错 / 网络不通" -ForegroundColor Yellow
    exit 7
}
Write-Host "  OK (DROP + CREATE + 15 表 + 种子数据)" -ForegroundColor Green

# ============================================================
# 10. Step 8: 启动后端 (含空格路径用反引号转义)
# ============================================================
Write-Host "[8/9] 启动后端 + 前端 ..." -ForegroundColor Cyan

# 启动后端 jar
if (-not (Test-Path $JarPath)) {
    Write-Host "  [WARN] 找不到 backend jar: $JarPath" -ForegroundColor Yellow
    Write-Host "  跳过 backend 启动 (你可以手动 mvn package 后重跑 install.ps1)" -ForegroundColor Yellow
} else {
    $backendLog = Join-Path $env:TEMP "health-backend.log"
    # 关键: 路径含空格用反引号转义 + 双引号包裹
    $backendArg = "-jar `"$JarPath`" --spring.datasource.password=$detectedPwd --server.port=$BackendPort"
    Write-Host "  Backend args: $backendArg" -ForegroundColor Gray
    Start-Process -FilePath $javaExe -ArgumentList $backendArg -WindowStyle Hidden -RedirectStandardOutput $backendLog -RedirectStandardError "$backendLog.err"
    Start-Sleep -Seconds 8
    if (Test-Port -Port $BackendPort) {
        Write-Host "  OK Backend (port $BackendPort, log: $backendLog)" -ForegroundColor Green
    } else {
        Write-Host "  [WARN] Backend port $BackendPort 未监听, 看 log: $backendLog.err" -ForegroundColor Yellow
        if (Test-Path "$backendLog.err") {
            Get-Content "$backendLog.err" -Tail 5 | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
        }
    }
}

# 启动前端 (Python http.server 零依赖)
$pyExe = ""
try {
    $cmd = Get-Command python -ErrorAction SilentlyContinue
    if ($cmd) { $pyExe = $cmd.Source }
} catch {}
if (-not $pyExe) {
    $pyExe = (Get-Command py -ErrorAction SilentlyContinue).Source
}
if (-not $pyExe) {
    Write-Host "  [WARN] 找不到 Python, 跳过前端启动" -ForegroundColor Yellow
    Write-Host "  你可以手动: cd frontend-pc\dist && python -m http.server $FrontendPort" -ForegroundColor Yellow
} else {
    if (-not (Test-Path $DistPath)) {
        Write-Host "  [WARN] 找不到 $DistPath, 跳过前端" -ForegroundColor Yellow
    } else {
        $frontendLog = Join-Path $env:TEMP "health-frontend.log"
        # 关键: 路径含空格用反引号转义
        $frontendArg = "-m http.server $FrontendPort --directory `"$DistPath`""
        Write-Host "  Frontend args: $frontendArg" -ForegroundColor Gray
        Start-Process -FilePath $pyExe -ArgumentList $frontendArg -WindowStyle Hidden -RedirectStandardOutput $frontendLog -RedirectStandardError "$frontendLog.err"
        Start-Sleep -Seconds 3
        if (Test-Port -Port $FrontendPort) {
            Write-Host "  OK Frontend (port $FrontendPort, log: $frontendLog)" -ForegroundColor Green
        } else {
            Write-Host "  [WARN] Frontend port $FrontendPort 未监听" -ForegroundColor Yellow
        }
    }
}

# ============================================================
# 11. Step 9: 健康检查 + 输出
# ============================================================
Write-Host ""
Write-Host "[9/9] 健康检查 ..." -ForegroundColor Cyan
$healthOk = $true

# Backend
try {
    $backendResp = Invoke-WebRequest -Uri "http://localhost:$BackendPort/api/dashboard/admin" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
    Write-Host "  Backend: OK (HTTP $($backendResp.StatusCode))" -ForegroundColor Green
} catch {
    Write-Host "  Backend: FAIL (可能未启动, 看 $env:TEMP\health-backend.log.err)" -ForegroundColor Yellow
    $healthOk = $false
}

# Frontend
try {
    $frontendResp = Invoke-WebRequest -Uri "http://localhost:$FrontendPort/" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
    Write-Host "  Frontend: OK (HTTP $($frontendResp.StatusCode))" -ForegroundColor Green
} catch {
    Write-Host "  Frontend: FAIL (可能未启动)" -ForegroundColor Yellow
    $healthOk = $false
}

# ============================================================
# 12. 完成
# ============================================================
Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "  部署完成 ✓" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "访问 URL:" -ForegroundColor Cyan
Write-Host "  Frontend: http://localhost:$FrontendPort" -ForegroundColor White
Write-Host "  Backend:  http://localhost:$BackendPort/api" -ForegroundColor White
Write-Host "  浏览器打开 Frontend URL 即可" -ForegroundColor Gray
Write-Host ""
Write-Host "6 角色账号 (密码统一 root):" -ForegroundColor Cyan
Write-Host "  admin        (管理员)  / root" -ForegroundColor White
Write-Host "  doctor_zhang (医生)    / root" -ForegroundColor White
Write-Host "  doctor_li    (医生)    / root" -ForegroundColor White
Write-Host "  user_wang    (用户)    / root" -ForegroundColor White
Write-Host "  user_chen    (用户)    / root" -ForegroundColor White
Write-Host "  user_zhao    (用户)    / root" -ForegroundColor White
Write-Host ""
Write-Host "管理命令:" -ForegroundColor Cyan
Write-Host "  .\status.ps1       # 看状态" -ForegroundColor Gray
Write-Host "  .\stop-all.ps1     # 停服务 (不动 MariaDB)" -ForegroundColor Gray
Write-Host "  .\restart-all.ps1  # 重启" -ForegroundColor Gray
Write-Host "  .\uninstall.ps1    # 完全卸载 (杀进程 + DROP 库 + 删 jar + 删 dist)" -ForegroundColor Gray
Write-Host ""
if (-not $healthOk) {
    Write-Host "⚠️  健康检查失败, 看 $env:TEMP\health-backend.log.err + health-frontend.log.err" -ForegroundColor Yellow
}