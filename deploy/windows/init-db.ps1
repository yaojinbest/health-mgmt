# ============================================================================
#  init-db.ps1 - MariaDB / MySQL 一键初始化（健康管理系统 v3）
# ============================================================================
#
#  作用:
#    1. 创建 health_management 库 (utf8mb4)
#    2. 导入 sql/init.sql (15 张表 + 15 份 seed 数据)
#
#  用法 (管理员 PowerShell):
#    PS> .\init-db.ps1                 # 默认: 127.0.0.1:3306, root, 提示输入密码
#    PS> .\init-db.ps1 -DbPassword root   # 直接传密码 (不安全, 留 history)
#    PS> .\init-db.ps1 -DbPort 3305       # 端口不是 3306
#    PS> .\init-db.ps1 -DbPassword opck2026  # 跟 application.yml 一致
#
#  OPC_K 部署 SOP (2026-07-06):
#    1. 文件加 UTF-8 BOM (本脚本已带)
#    2. sql 文件加 UTF-8 BOM (sql/init.sql 已带)
#    3. mysql 命令加 --default-character-set=utf8mb4 (本脚本已带)
#    4. 杀进程用 Get-Process + Stop-Process (PowerShell 原生 API, 不抛错)
#    5. 不用 < 重定向, 用 Get-Content | mysql 管道
#
#  历史踩坑 (2026-07-05/06):
#    - 默认端口从 3305 改为 3306 (跟 application.yml 对齐)
#    - password 不再走 $env:MYSQL_PWD (PowerShell 5.1 不生效), 改用参数
#    - 杀进程从 taskkill 改为 Get-Process (管道里 -ErrorAction 不生效)
#    - 加 --default-character-set=utf8mb4 (init.sql 中文注释不乱码)
# ============================================================================

[CmdletBinding()]
param(
    [string]$DbHost = "127.0.0.1",
    [int]$DbPort = 3306,
    [string]$DbName = "health_management",
    [string]$DbUser = "root",
    [string]$DbPassword = "",
    [string]$ProjectRoot = "..\..",
    [string]$MysqlPath = ""
)

# UTF-8 BOM 必备
$ErrorActionPreference = "Stop"
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# ---- 路径定位 ----
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$InitSql = Join-Path (Resolve-Path $ProjectRoot) "sql/init.sql"
if (-not (Test-Path $InitSql)) {
    Write-Host "[FAIL] 找不到 sql/init.sql, 请确认 $InitSql 存在" -ForegroundColor Red
    exit 1
}

# ---- 找 mysql.exe (PATH → 常见安装位置) ----
$mysqlExe = ""
if ($MysqlPath -and (Test-Path $MysqlPath)) {
    $mysqlExe = (Get-Item $MysqlPath).FullName
} else {
    try {
        $whereOut = & where.exe mysql 2>$null | Select-Object -First 1
        if ($whereOut -and (Test-Path $whereOut)) {
            $mysqlExe = (Get-Item $whereOut).FullName
        }
    } catch {}
    if (-not $mysqlExe) {
        $cmd = Get-Command mysql -ErrorAction SilentlyContinue
        if ($cmd) {
            $mysqlExe = if ($cmd.Source) { $cmd.Source } elseif ($cmd.Path) { $cmd.Path } else { "" }
            if ($mysqlExe -and -not (Test-Path $mysqlExe)) { $mysqlExe = "" }
        }
    }
    if (-not $mysqlExe) {
        $candidates = @(
            "C:\Program Files\MariaDB*\bin\mysql.exe",
            "C:\Program Files (x86)\MariaDB*\bin\mysql.exe",
            "C:\Program Files\MySQL\MySQL Server*\bin\mysql.exe",
            "D:\Program Files\MariaDB*\bin\mysql.exe"
        )
        foreach ($p in $candidates) {
            $found = Get-Item $p -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($found) { $mysqlExe = $found.FullName; break }
        }
    }
}
if (-not $mysqlExe) {
    Write-Host "[FAIL] 找不到 mysql.exe" -ForegroundColor Red
    Write-Host "  请确认 MariaDB / MySQL 已安装, 或用 -MysqlPath 指定" -ForegroundColor Yellow
    exit 1
}
Write-Host "mysql: $mysqlExe" -ForegroundColor Cyan
Write-Host "host:  $DbHost`:$DbPort" -ForegroundColor Cyan

# ---- 密码处理 (不再走 $env:MYSQL_PWD) ----
if (-not $DbPassword) {
    $secure = Read-Host "请输入 $DbUser 密码" -AsSecureString
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    $DbPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
}
if (-not $DbPassword) {
    Write-Host "[FAIL] 密码不能为空" -ForegroundColor Red
    exit 1
}

# ---- 测试连接 ----
Write-Host "测试数据库连接 $DbHost`:$DbPort ..." -ForegroundColor Cyan
$testOut = & $mysqlExe -h $DbHost -P "$DbPort" -u $DbUser -p$DbPassword --default-character-set=utf8mb4 -e "SELECT VERSION();" 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "[FAIL] 连接失败:" -ForegroundColor Red
    $testOut | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
    Write-Host ""
    Write-Host "常见原因:" -ForegroundColor Yellow
    Write-Host "  1. MariaDB / MySQL 服务没起: net start | findstr -i maria" -ForegroundColor Gray
    Write-Host "  2. 端口不对: 试 -DbPort 3305 或 3306" -ForegroundColor Gray
    Write-Host "  3. 密码不对: 重新输" -ForegroundColor Gray
    Write-Host "  4. root@127.0.0.1 没授权: 见 README 7.3 故障排查" -ForegroundColor Gray
    exit 2
}
Write-Host "OK" -ForegroundColor Green
Write-Host ""

# ---- 跑 init.sql (UTF-8 BOM + utf8mb4) ----
Write-Host "跑 init.sql (DROP + CREATE + 15 表 + seed)..." -ForegroundColor Cyan
Get-Content $InitSql | & $mysqlExe -h $DbHost -P "$DbPort" -u $DbUser -p$DbPassword --default-character-set=utf8mb4 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "[FAIL] init.sql 跑失败, 退出码 $LASTEXITCODE" -ForegroundColor Red
    exit 3
}
Write-Host "OK" -ForegroundColor Green

# ---- 验证 ----
Write-Host "验证..." -ForegroundColor Cyan
$tables = & $mysqlExe -h $DbHost -P "$DbPort" -u $DbUser -p$DbPassword -N -B --default-character-set=utf8mb4 -e "USE $DbName; SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='$DbName';" 2>&1
$users = & $mysqlExe -h $DbHost -P "$DbPort" -u $DbUser -p$DbPassword -N -B --default-character-set=utf8mb4 -e "USE $DbName; SELECT COUNT(*) FROM sys_user;" 2>&1

Write-Host ""
Write-Host "==== 验证结果 ====" -ForegroundColor Green
Write-Host "表数: $tables (期望 15)" -ForegroundColor White
Write-Host "用户数: $users (期望 6)" -ForegroundColor White
Write-Host ""

if ($tables -eq 15 -and $users -eq 6) {
    Write-Host "[OK] 初始化完成! 演示账号:" -ForegroundColor Green
    Write-Host "   - 患者:    user_wang / root" -ForegroundColor White
    Write-Host "   - 医生:    doctor_zhang / root" -ForegroundColor White
    Write-Host "   - 管理员:  admin / root" -ForegroundColor White
    Write-Host ""
    Write-Host "下一步:" -ForegroundColor Cyan
    Write-Host "   cd $ScriptDir" -ForegroundColor White
    Write-Host "   .\start-backend.ps1" -ForegroundColor White
    Write-Host "   (新窗口) .\start-frontend-pc.ps1" -ForegroundColor White
} else {
    Write-Host "[WARN] 数量不对" -ForegroundColor Yellow
    exit 4
}
