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
    [string]$ProjectRoot = "..\..",
    [string]$MysqlPath = ""
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

# ---- 检查 mysql 客户端 (PATH → 常见安装路径自动搜) ----
$mysql = $null
$mysqlExe = ""

if ($MysqlPath -and (Test-Path $MysqlPath)) {
    $mysqlExe = (Get-Item $MysqlPath).FullName
} else {
    # 1. 优先用 where.exe 拿 PATH 里的实际可执行路径 (避开 Get-Command 在 alias/function 时 .Source 为空的问题)
    try {
        $whereOut = & where.exe mysql 2>$null | Select-Object -First 1
        if ($whereOut -and (Test-Path $whereOut)) {
            $mysqlExe = (Get-Item $whereOut).FullName
        }
    } catch {}

    # 2. where.exe 没找到, 退回到 Get-Command
    if (-not $mysqlExe) {
        $cmd = Get-Command mysql -ErrorAction SilentlyContinue
        if ($cmd) {
            $mysqlExe = if ($cmd.Source) { $cmd.Source }
                        elseif ($cmd.Path) { $cmd.Path }
                        elseif ($cmd.Definition) { $cmd.Definition }
                        else { "" }
            if ($mysqlExe -and -not (Test-Path $mysqlExe)) { $mysqlExe = "" }
        }
    }

    # 3. 自动搜常见安装位置 (MariaDB / MySQL / phpStudy / XAMPP / MySQL Installer)
    if (-not $mysqlExe) {
        $candidates = @(
            "C:\Program Files\MariaDB*\bin\mysql.exe",
            "C:\Program Files (x86)\MariaDB*\bin\mysql.exe",
            "C:\Program Files\MySQL\MySQL Server*\bin\mysql.exe",
            "C:\Program Files\MySQL\MySQL Server*\bin\mariadb.exe",
            "D:\Program Files\MariaDB*\bin\mysql.exe",
            "D:\phpstudy_pro\Extensions\MySQL*\bin\mysql.exe",
            "C:\xampp\mysql\bin\mysql.exe",
            "C:\laragon\bin\mysql\mysql-*\bin\mysql.exe",
            "D:\tools\mysql*\bin\mysql.exe",
            "D:\tools\mariadb*\bin\mysql.exe"
        )
        foreach ($p in $candidates) {
            $found = Get-Item $p -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($found) { $mysqlExe = $found.FullName; break }
        }
    }
}
if (-not $mysqlExe) {
    Write-Host "❌ 未检测到 mysql 命令行客户端" -ForegroundColor Red
    Write-Host ""
    Write-Host "  🔍 已扫描的常见位置:" -ForegroundColor Yellow
    @(
        "C:\Program Files\MariaDB*\bin\mysql.exe",
        "C:\Program Files\MySQL\MySQL Server*\bin\mysql.exe",
        "D:\phpstudy_pro\Extensions\MySQL*\bin\mysql.exe",
        "C:\xampp\mysql\bin\mysql.exe",
        "C:\laragon\bin\mysql\mysql-*\bin\mysql.exe"
    ) | ForEach-Object { Write-Host "    - $_" -ForegroundColor Gray }
    Write-Host ""
    Write-Host "  📦 未装 MySQL/MariaDB? 推荐安装:" -ForegroundColor Yellow
    Write-Host "    MariaDB 11.x: https://mariadb.org/download/" -ForegroundColor Yellow
    Write-Host "    MySQL 8.x:    https://dev.mysql.com/downloads/installer/" -ForegroundColor Yellow
    Write-Host "    XAMPP:        https://www.apachefriends.org/" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  🛠️  三种修复方法 (任选一):" -ForegroundColor Yellow
    Write-Host "    1. 把 mysql.exe 所在 bin 目录加到 PATH (推荐)" -ForegroundColor Yellow
    Write-Host "       setx PATH `"$env:PATH;C:\Program Files\MariaDB 11.8\bin`"" -ForegroundColor Gray
    Write-Host "       (重开 PowerShell 生效)" -ForegroundColor Gray
    Write-Host "    2. 手动指定路径重跑:" -ForegroundColor Yellow
    Write-Host "       .\init-db.ps1 -MysqlPath 'D:\tools\mariadb\bin\mysql.exe'" -ForegroundColor Gray
    Write-Host "    3. 用 HeidiSQL / Navicat 等 GUI 客户端手动执行 sql/init.sql" -ForegroundColor Yellow
    exit 2
}
Write-Host "✅ mysql: $mysqlExe" -ForegroundColor Green

# ---- 输入密码 ----
$rootPwd = Read-Host -AsSecureString "MariaDB root 密码 (空密码直接回车)"
if ($rootPwd.Length -eq 0) {
    Write-Host "  ℹ️  检测到空密码 (装 MariaDB 时没设 root 密码常见)" -ForegroundColor Cyan
    $env:MYSQL_PWD = ""
} else {
    $env:MYSQL_PWD = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($rootPwd)
    )
    # 立刻清 SecureString 内存
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($rootPwd))
    [GC]::Collect()
}

function Run-Mysql {
    param([string[]]$Args_)
    # mysql.exe 警告 (如 --ssl-verify-server-cert) 会写 stderr,
    # PowerShell 的 & + $ErrorActionPreference=Stop 会拋 RemoteException。
    # 临时调成 Continue 避免中断。
    $prevPref = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        & $mysqlExe --default-character-set=utf8mb4 @Args_ 2>&1
    } finally {
        $ErrorActionPreference = $prevPref
    }
    return $LASTEXITCODE
}

# ---- 预检测: MariaDB 服务 + 端口 ----
Write-Host "`n🔍 预检测: MariaDB 服务 + 端口侦听 ..." -ForegroundColor Cyan

# 1. 检测 MariaDB 服务状态
$svc = Get-Service -Name "MariaDB" -ErrorAction SilentlyContinue
if (-not $svc) {
    # 换名字试 (有些版本叫 MySQL / mariadb)
    $svc = Get-Service | Where-Object { $_.Name -match "MariaDB|mysql" -and $_.Name -ne "mysqlsvc" } | Select-Object -First 1
}
if (-not $svc) {
    Write-Host "⚠️  未找到 MariaDB 服务" -ForegroundColor Yellow
    Write-Host "   可能服务名不同, 运行 'Get-Service | findstr Maria' 查看" -ForegroundColor Gray
} elseif ($svc.Status -ne "Running") {
    Write-Host "⚠️  MariaDB 服务未运行 (状态: $($svc.Status))" -ForegroundColor Yellow
    Write-Host "   尝试启动: net start $($svc.Name)" -ForegroundColor Cyan
    $startOut = & net.exe start $svc.Name 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ MariaDB 服务已启动" -ForegroundColor Green
    } else {
        Write-Host "❌ 启动失败: $startOut" -ForegroundColor Red
    }
} else {
    Write-Host "✅ MariaDB 服务运行中" -ForegroundColor Green
}

# 2. 检测端口是否在听 + 自动 fallback (3305 → 3306)
$portOpen = & netstat.exe -ano | Select-String ":$DbPort\s.*LISTENING" -ErrorAction SilentlyContinue
if (-not $portOpen) {
    Write-Host "⚠️  端口 $DbPort 未在 LISTENING" -ForegroundColor Yellow
    # 自动 fallback: 尝试 3306 / 3307 / 13306
    foreach ($p in @(3306, 3307, 13306)) {
        if ($p -eq $DbPort) { continue }
        $pOpen = & netstat.exe -ano | Select-String ":$p\s.*LISTENING" -ErrorAction SilentlyContinue
        if ($pOpen) {
            Write-Host "   🔍 发现端口 $p 在听, 自动切换 -DbPort (原默认 $DbPort 是 application.yml 里配的)" -ForegroundColor Cyan
            $DbPort = $p
            $portOpen = $pOpen
            break
        }
    }
    if (-not $portOpen) {
        Write-Host "   MariaDB 默认端口: 3306 (可能你装时改成了别的)" -ForegroundColor Gray
        Write-Host "   跟其他 DB 共享服务? 试 -DbPort 3306 / 3307 / 13306" -ForegroundColor Gray
        Write-Host "   查看所有 MySQL 端口: netstat -ano | findstr LISTENING" -ForegroundColor Gray
    }
}
if ($portOpen) {
    Write-Host "✅ 端口 $DbPort 在听" -ForegroundColor Green
}

# ---- 测试连接 ----
Write-Host "`n🔍 测试数据库连接 $DbHost`:$DbPort ..." -ForegroundColor Cyan
# 临时改 ErrorActionPreference = Continue (避免 mysql.exe WARNING 报 stderr 触发 $ErrorActionPreference=Stop)
$prevPref = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $connTestOut = & $mysqlExe --default-character-set=utf8mb4 `
        -h $DbHost -P "$DbPort" -u $DbUser `
        -e "SELECT VERSION();" 2>&1
    $connTest = $LASTEXITCODE
} finally {
    $ErrorActionPreference = $prevPref
}
if ($connTest -ne 0) {
    $errMsg = ($connTestOut | Out-String)
    Write-Host "❌ 数据库连接失败 (退出码 $connTest)" -ForegroundColor Red
    Write-Host "   $errMsg" -ForegroundColor Gray
    Write-Host ""
    # 根据 MySQL 错误码给针对性提示
    if ($errMsg -match "ERROR 2002 \(HY000\)") {
        Write-Host "  💡 ERROR 2002 = 服务没起 / 端口没听" -ForegroundColor Yellow
        Write-Host "     1) 确认 MariaDB 服务已启动: Get-Service MariaDB" -ForegroundColor Yellow
        Write-Host "     2) 确认端口: netstat -ano | findstr LISTENING" -ForegroundColor Yellow
        Write-Host "     3) 端口不对? 用 -DbPort 参数: -DbPort 3306 / 3307" -ForegroundColor Yellow
    } elseif ($errMsg -match "ERROR 1045 \(28000\)") {
        Write-Host "  💡 ERROR 1045 = 密码错" -ForegroundColor Yellow
        Write-Host "     1) 密码对吗?  重新输入" -ForegroundColor Yellow
        Write-Host "     2) 忘了密码? 用 --skip-grant-tables 重置 (网上查教程)" -ForegroundColor Yellow
    } elseif ($errMsg -match "ERROR 2003") {
        Write-Host "  💡 ERROR 2003 = 端口错 / 防火墙挡" -ForegroundColor Yellow
        Write-Host "     1) MariaDB 没听这个端口" -ForegroundColor Yellow
        Write-Host "     2) Windows 防火墙拦了: 控制面板 → Windows Defender 防火墙 → 允许应用" -ForegroundColor Yellow
    } elseif ($errMsg -match "ERROR 1049") {
        Write-Host "  💡 ERROR 1049 = 数据库不存在 (但这是初始化脚本,不应该出现)" -ForegroundColor Yellow
    }
    Write-Host ""
    Write-Host "  🔧 如果端口不对, 重跑: .\init-db.ps1 -DbPort 3306" -ForegroundColor Cyan
    Write-Host "  🔧 如果服务没起: net start MariaDB" -ForegroundColor Cyan
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
    Write-Host "   (看不到输出别担心, mysql 默认静默模式, 等待 10-30 秒)" -ForegroundColor Gray
    $import = Run-Mysql @('-h', $DbHost, '-P', "$DbPort", '-u', $DbUser)
    # 把内容通过管道喂给 mysql (同样要包 try/finally 避免 WARNING 拋 RemoteException)
    $prevPref = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        # Tee-Object 同时保存输出到变量 + 输出到控制台 (进哥能看到进度信息)
        $importOutput = @()
        Get-Content $tmpSql | & $mysqlExe --default-character-set=utf8mb4 `
            -h $DbHost -P "$DbPort" -u $DbUser `
            $DbName 2>&1 | Tee-Object -Variable importOutput | Out-Null
    } finally {
        $ErrorActionPreference = $prevPref
    }

    if ($LASTEXITCODE -ne 0) {
        $errStr = ($importOutput | Out-String)
        Write-Host "❌ 导入失败 (退出码 $LASTEXITCODE), 输出:`n$errStr" -ForegroundColor Red
        Remove-Item Env:MYSQL_PWD -ErrorAction SilentlyContinue
        Remove-Item $tmpSql -Force -ErrorAction SilentlyContinue
        exit 4
    } else {
        Write-Host "✅ init.sql 导入成功" -ForegroundColor Green
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
Write-Host ""
# 提醒端口不一致问题
$appYmlPort = 3305
if ($DbPort -ne $appYmlPort) {
    Write-Host "  ⚠️  端口提醒:" -ForegroundColor Yellow
    Write-Host "   init-db 实际使用的端口: $DbPort" -ForegroundColor Yellow
    Write-Host "   backend application.yml 配的端口: $appYmlPort" -ForegroundColor Yellow
    Write-Host "   如果不一致, 后端连不上数据库! 改 src\main\resources\application.yml:" -ForegroundColor Yellow
    Write-Host "     url: jdbc:mysql://localhost:$DbPort/health_management?..." -ForegroundColor Gray
    Write-Host "   改完后重新打 jar: mvn package -DskipTests" -ForegroundColor Yellow
}
