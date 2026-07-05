# ============================================================================
#  init-db.ps1 - MariaDB / MySQL 一键初始化（健康管理系统）
# ============================================================================
#
#  作用:
#    1. 创建 health_management 库 (utf8mb4)
#    2. 创建 / 重置 db_user 用户
#    3. 导入 sql/init.sql (15 张表 + 15 份 seed 数据)
#
#  用法 (管理员 PowerShell):
#    PS> .\init-db.ps1
#
#  注意:
#    - 必须用 MariaDB 客户端 mysql 命令
#    - 密码走 $env:MYSQL_PWD 环境变量 (避免命令行历史泄露)
#    - 需要 sql/init.sql 存在
# ============================================================================

[CmdletBinding()]
param(
    [string]$DbHost = "127.0.0.1",
    [int]$DbPort = 3305,
    [string]$DbName = "health_management",
    [string]$DbUser = "root",
    [string]$ProjectRoot = "..\.."
)

# UTF-8 BOM 必备 (PowerShell 5.1 中文系统防乱码)
$ErrorActionPreference = "Stop"
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# ---- 路径定位 ----
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$InitSql = Join-Path (Resolve-Path $ProjectRoot) "sql/init.sql"
if (-not (Test-Path $InitSql)) {
    Write-Host "❌ 找不到 sql/init.sql，请确认 $InitSql 存在" -ForegroundColor Red
    exit 1
}

# ---- 检查 mysql 客户端 ----
$mysql = Get-Command mysql -ErrorAction SilentlyContinue
if (-not $mysql) {
    Write-Host "❌ 未检测到 mysql 命令行客户端" -ForegroundColor Red
    Write-Host "   请先安装 MariaDB 10+ 或 MySQL 8+，并将 bin 加入 PATH" -ForegroundColor Yellow
    Write-Host "   下载: https://mariadb.org/download/" -ForegroundColor Yellow
    exit 2
}

# ---- 输入密码 ----
$rootPwd = Read-Host -AsSecureString "MariaDB root 密码"
$env:MYSQL_PWD = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($rootPwd)
)

# 立刻清 SecureString 内存
[System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($rootPwd))
[GC]::Collect()

function Run-Mysql {
    param([string[]]$Args_)
    & mysql --default-character-set=utf8mb4 @Args_
    return $LASTEXITCODE
}

# ---- 测试连接 ----
Write-Host "`n🔍 测试数据库连接 $DbHost`:$DbPort ..." -ForegroundColor Cyan
$connTest = Run-Mysql @('-h', $DbHost, '-P', "$DbPort", '-u', $DbUser, '-e', 'SELECT VERSION();')
if ($connTest -ne 0) {
    Write-Host "❌ 数据库连接失败，密码错 / 端口错 / 用户不存在" -ForegroundColor Red
    Write-Host "   常见问题: root 密码为空 → 直接回车重试" -ForegroundColor Yellow
    Write-Host "   端口不是 3305?  用 -DbPort 3306 (默认 MySQL)" -ForegroundColor Yellow
    Remove-Item Env:MYSQL_PWD -ErrorAction SilentlyContinue
    exit 3
}
Write-Host "✅ 数据库连接 OK`n" -ForegroundColor Green

# ---- 创建库 + 导入 init.sql ----
$tmpSql = [System.IO.Path]::GetTempFileName() + ".sql"
try {
    # init.sql 自带 CREATE DATABASE + USE 语句, 直接 mysql < init.sql 即可
    Get-Content $InitSql | Out-File -FilePath $tmpSql -Encoding UTF8

    Write-Host "📦 导入 sql/init.sql 到 $DbName ..." -ForegroundColor Cyan
    $import = Run-Mysql @('-h', $DbHost, '-P', "$DbPort", '-u', $DbUser)
    # 把内容通过管道喂给 mysql
    Get-Content $tmpSql | & mysql --default-character-set=utf8mb4 `
        -h $DbHost -P "$DbPort" -u $DbUser `
        $DbName 2>&1 | Tee-Object -Variable importOutput | Out-Null

    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ 导入失败, 输出:`n$importOutput" -ForegroundColor Red
        Remove-Item Env:MYSQL_PWD -ErrorAction SilentlyContinue
        Remove-Item $tmpSql -Force -ErrorAction SilentlyContinue
        exit 4
    }
} finally {
    Remove-Item $tmpSql -Force -ErrorAction SilentlyContinue
}

# ---- 验证 ----
Write-Host "`n🔍 验证数据 ..." -ForegroundColor Cyan
# PowerShell 5.1 不支持 bash 风格 '"'$var'"' 嵌套引号
# 改用双引号字符串 + $DbName 插值
$tablesSql = "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = '$DbName';"
$usersSql = "SELECT COUNT(*) FROM sys_user;"
$tablesCount = Run-Mysql @('-h', $DbHost, '-P', "$DbPort", '-u', $DbUser, $DbName, '-N', '-B', '-e', $tablesSql)
$usersCount = Run-Mysql @('-h', $DbHost, '-P', "$DbPort", '-u', $DbUser, $DbName, '-N', '-B', '-e', $usersSql)

Write-Host "✅ 创建数据库: $DbName (表数=$tablesCount, 演示用户数=$usersCount)" -ForegroundColor Green

# 清密码
Remove-Item Env:MYSQL_PWD -ErrorAction SilentlyContinue

Write-Host "`n🎉 初始化完成! 演示账号:" -ForegroundColor Green
Write-Host "   - 患者:  user_wang / root" -ForegroundColor White
Write-Host "   - 医生:  doctor_zhang / root" -ForegroundColor White
Write-Host "   - 管理员: admin / root" -ForegroundColor White
Write-Host ""
Write-Host "下一步:" -ForegroundColor Cyan
Write-Host "   PS> .\start-backend.ps1   # 启动后端" -ForegroundColor White
Write-Host "   PS> .\start-frontend.ps1  # 启动 H5 (开发模式)" -ForegroundColor White
