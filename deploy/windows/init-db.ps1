#Requires -RunAsAdministrator
<#
.SYNOPSIS
  init-db.ps1 - MariaDB database init script (health-mgmt v3.2.10)
.DESCRIPTION
  2 modes:
  1. Normal: test conn, run init.sql (DROP+CREATE+seed)
  2. -ResetRootPassword: crack/reset MariaDB root password via mysql_install_db in NEW datadir

  Usage:
    .\init-db.ps1                          # interactive
    .\init-db.ps1 -DbPassword opck2026     # direct
    .\init-db.ps1 -ResetRootPassword       # force reset
    .\init-db.ps1 -DbPassword opck2026 -ResetRootPassword
.NOTES
  v3.2.10:
  - mysql_install_db.exe requires EMPTY datadir
  - Strategy: backup old datadir, create NEW datadir in temp, install_db in new,
    copy health_management/ from backup to new, point mariadbd to new datadir
  - JDBC URL in application.yml doesn't need change (still localhost:3306)
#>

param(
    [string]$DbPassword = "",
    [switch]$ResetRootPassword
)

# ---- Config ----
$DbHost = "127.0.0.1"
$DbPort = 3306
$DbUser = "root"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootDir   = (Get-Item $scriptDir).Parent.Parent
$InitSql   = Join-Path $rootDir "sql\init.sql"
$mariadbBase = "C:\Program Files\MariaDB 11.8"
$mariadbdExe = Join-Path $mariadbBase "bin\mariadbd.exe"
$mysqlExe    = Join-Path $mariadbBase "bin\mysql.exe"
$mariadbInstallDbExe = Join-Path $mariadbBase "bin\mysql_install_db.exe"

if (-not (Test-Path $mysqlExe)) {
    $candidates = Get-ChildItem "C:\Program Files\MariaDB*" -Directory -ErrorAction SilentlyContinue |
                  Where-Object { (Test-Path (Join-Path $_.FullName "bin\mariadbd.exe")) }
    if ($candidates) {
        $mariadbBase = $candidates[0].FullName
        $mariadbdExe = Join-Path $mariadbBase "bin\mariadbd.exe"
        $mysqlExe    = Join-Path $mariadbBase "bin\mysql.exe"
        $mariadbInstallDbExe = Join-Path $mariadbBase "bin\mysql_install_db.exe"
    }
}

# Default password
if (-not $DbPassword) {
    $secure = Read-Host "Enter $DbUser password (empty=reset flow)" -AsSecureString
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    $DbPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    if (-not $DbPassword) {
        $DbPassword = "opck2026"
        Write-Host "[INFO] Empty password, auto-enable -ResetRootPassword" -ForegroundColor Cyan
        $ResetRootPassword = $true
    }
}

Write-Host "mysql: $mysqlExe" -ForegroundColor Gray
Write-Host "host:  $DbHost`:$DbPort" -ForegroundColor Gray
Write-Host "target password: ********" -ForegroundColor Gray

# ---- Find MariaDB service name (dynamic) ----
$MariaService = $null
try {
    $svcList = & sc.exe query state= all 2>$null | Select-String "SERVICE_NAME:.*MariaDB" | ForEach-Object {
        if ($_ -match "SERVICE_NAME:\s*(\S+)") { $matches[1] }
    }
    if ($svcList) { $MariaService = $svcList | Select-Object -First 1 }
} catch {}
if (-not $MariaService) { $MariaService = "MariaDB" }

# ---- Test connection ----
Write-Host "Test connection $DbHost`:$DbPort ..." -ForegroundColor Cyan
$testOut = & $mysqlExe -h $DbHost -P "$DbPort" -u $DbUser -p$DbPassword --default-character-set=utf8mb4 -e "SELECT VERSION();" 2>&1
if ($LASTEXITCODE -ne 0) {
    if ($testOut -match "1045" -or $testOut -match "Access denied") {
        if (-not $ResetRootPassword) {
            Write-Host "[WARN] Access denied. Auto-enable -ResetRootPassword..." -ForegroundColor Yellow
            $ResetRootPassword = $true
        }
    } elseif ($testOut -match "10061" -or $testOut -match "Can't connect" -or $testOut -match "Connection refused") {
        if (-not $ResetRootPassword) {
            Write-Host "[WARN] Service not running (10061), auto-enable -ResetRootPassword..." -ForegroundColor Yellow
            $ResetRootPassword = $true
        }
    } else {
        Write-Host "[FAIL] Connection failed:" -ForegroundColor Red
        $testOut | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
        exit 2
    }
} else {
    Write-Host "OK" -ForegroundColor Green
}

# ---- -ResetRootPassword flow (v3.2.10, mysql_install_db in NEW datadir) ----
if ($ResetRootPassword) {
    Write-Host ""
    Write-Host "==== -ResetRootPassword flow ====" -ForegroundColor Cyan
    Write-Host "Target: reset $DbUser to -DbPassword" -ForegroundColor Gray
    Write-Host "Method: mysql_install_db in NEW datadir + copy health_management back" -ForegroundColor Gray
    Write-Host "Note: only the mysql system database is recreated, user databases preserved" -ForegroundColor Gray

    if (-not (Test-Path $mariadbdExe)) {
        Write-Host "[FAIL] mariadbd.exe not found, cannot reset" -ForegroundColor Red
        exit 5
    }
    if (-not (Test-Path $mariadbInstallDbExe)) {
        Write-Host "[FAIL] mysql_install_db.exe not found at: $mariadbInstallDbExe" -ForegroundColor Red
        exit 5
    }

    # 1) Kill all mariadbd/mysqld/mysql
    Write-Host "1) Kill all mariadbd/mysqld/mysql processes..." -ForegroundColor Cyan
    $svc = Get-Service -Name $MariaService -ErrorAction SilentlyContinue
    if ($svc -and $svc.Status -eq "Running") {
        Stop-Service -Name $MariaService -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
    }
    foreach ($name in @("mariadbd.exe", "mysqld.exe", "mysql.exe")) {
        & taskkill.exe /F /IM $name /T 2>&1 | Out-Null
    }
    Start-Sleep -Seconds 3

    $portBusy = Get-NetTCPConnection -LocalPort $DbPort -State Listen -ErrorAction SilentlyContinue
    if ($portBusy) {
        $pids = $portBusy.OwningProcess | Sort-Object -Unique
        Write-Host "  Port $DbPort still busy (PID: $($pids -join ',')), kill by PID..." -ForegroundColor Yellow
        foreach ($pid in $pids) {
            $procName = (Get-Process -Id $pid -ErrorAction SilentlyContinue).ProcessName
            Write-Host "    PID $pid = $procName" -ForegroundColor Gray
            & taskkill.exe /F /PID $pid /T 2>&1 | Out-Null
        }
        Start-Sleep -Seconds 3
    }
    $portBusy2 = Get-NetTCPConnection -LocalPort $DbPort -State Listen -ErrorAction SilentlyContinue
    if ($portBusy2) {
        $pids2 = $portBusy2.OwningProcess | Sort-Object -Unique
        $procs2 = $pids2 | ForEach-Object { "PID $_ = $((Get-Process -Id $_ -EA SilentlyContinue).ProcessName)" }
        Write-Host "  [FAIL] Port $DbPort still busy: $($procs2 -join '; ')" -ForegroundColor Red
        exit 8
    }
    Write-Host "  OK (port $DbPort free)" -ForegroundColor Green

    # 2) Find OLD datadir
    $oldDataDir = "C:\Program Files\MariaDB 11.8\data"
    if (-not (Test-Path $oldDataDir)) {
        $candidates = Get-ChildItem "C:\Program Files\MariaDB*" -Directory -ErrorAction SilentlyContinue
        if ($candidates) {
            $oldDataDir = $candidates[0].FullName + "\data"
        }
    }
    Write-Host "2) OLD datadir: $oldDataDir" -ForegroundColor Gray

    # 3) Define NEW datadir (empty, in temp) and copy health_management + other user dbs
    Write-Host "3) Prepare NEW datadir in temp..." -ForegroundColor Cyan
    $newDataDir = "C:/Users/84918/AppData/Local/Temp/mariadb-new-data"
    $oldDataDirFs = $newDataDir -replace "/", "\"
    if (Test-Path $newDataDir) {
        Write-Host "  Clean NEW datadir: $newDataDir" -ForegroundColor Gray
        Remove-Item -Path $newDataDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    New-Item -ItemType Directory -Path $newDataDir -Force | Out-Null
    Write-Host "  OK (NEW datadir ready: $newDataDir)" -ForegroundColor Green

    # 4) Run mysql_install_db.exe in NEW datadir
    Write-Host "4) Run mysql_install_db.exe --datadir=NEW_DIR ..." -ForegroundColor Cyan
    $installLog = Join-Path $env:TEMP "mysql-install-db.log"
    $installArgs = @("--datadir=`"$newDataDir`"")
    Write-Host "  args: $installArgs" -ForegroundColor Gray
    $installOut = & $mariadbInstallDbExe @installArgs 2>&1
    $installExit = $LASTEXITCODE
    Write-Host "  exit code: $installExit" -ForegroundColor Gray
    $installOut | Select-Object -First 30 | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
    if ($installExit -ne 0) {
        Write-Host "  [FAIL] mysql_install_db failed" -ForegroundColor Red
        exit 13
    }
    Write-Host "  OK (NEW mysql system db created, default root has empty password)" -ForegroundColor Green

    # 5) Copy user databases (health_management, etc.) from OLD to NEW datadir
    #    CRITICAL: only copy user db directories, NOT any system files
    #    (InnoDB undo/log files, sys schemas, mysql system db all corrupt if copied)
    Write-Host "5) Copy user databases (health_management, ...) from OLD to NEW datadir..." -ForegroundColor Cyan
    $oldItems = Get-ChildItem -Path $oldDataDir -ErrorAction SilentlyContinue
    # System files/dirs that MUST NOT be copied (let mariadbd recreate)
    $systemPatterns = @(
        "mysql",                    # System database
        "performance_schema",       # System schema
        "sys",                      # System schema
        "test",                     # Default test db
        "ibdata1",                  # InnoDB system tablespace
        "ib_logfile*",              # InnoDB redo logs
        "ibtmp1",                   # InnoDB temp tablespace
        "ib_buffer_pool",           # InnoDB buffer pool cache
        "undo001", "undo002", "undo003",  # InnoDB undo tablespaces
        "aria_log.*", "aria_log_control", # Aria engine logs
        "tc.log", "multi-master.info",    # Misc
        "my.ini", "my.cnf",         # Config (let mariadbd recreate or use --defaults-file)
        "*.err", "*.pid",           # Old logs
        "ddl_recovery*.log",
        "private_key.pem", "public_key.pem",  # SSL certs
        "binlog.*",                 # Binary logs
        "relay-log.*",              # Relay logs
        "master.info", "relay-log.info"
    )
    $copied = 0
    foreach ($item in $oldItems) {
        $isSystem = $false
        foreach ($pat in $systemPatterns) {
            if ($item.Name -like $pat) {
                $isSystem = $true
                break
            }
        }
        if ($isSystem) {
            Write-Host "  Skip system file: $($item.Name)" -ForegroundColor Gray
            continue
        }
        $src = $item.FullName
        $dst = Join-Path $newDataDir $item.Name
        Write-Host "  Copy: $($item.Name)" -ForegroundColor Gray
        Copy-Item -Path $src -Destination $dst -Recurse -Force -ErrorAction SilentlyContinue
        $copied++
    }
    Write-Host "  OK ($copied user db items copied)" -ForegroundColor Green

    # 6) Start mariadbd pointing at NEW datadir
    Write-Host "6) Start mariadbd --datadir=NEW_DIR (wait 8s)..." -ForegroundColor Cyan
    $normalLog = Join-Path $env:TEMP "mariadbd-normal.log"
    $normalArgString = "--datadir=`"$newDataDir`" --port=$DbPort --character-set-server=utf8mb4 --character-set-filesystem=utf8mb4 --console"
    Write-Host "  args: $normalArgString" -ForegroundColor Gray
    $procN = Start-Process -FilePath $mariadbdExe `
        -ArgumentList $normalArgString `
        -RedirectStandardOutput $normalLog `
        -RedirectStandardError "$normalLog.err" `
        -WindowStyle Hidden -PassThru
    Write-Host "  PID: $($procN.Id)" -ForegroundColor Gray
    Start-Sleep -Seconds 8

    $portNow = Get-NetTCPConnection -LocalPort $DbPort -State Listen -ErrorAction SilentlyContinue
    if (-not $portNow) {
        Write-Host "  [FAIL] mariadbd not listening on $DbPort, see log: $normalLog.err" -ForegroundColor Red
        if (Test-Path "$normalLog.err") {
            Get-Content "$normalLog.err" -Tail 30 | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
        }
        & taskkill.exe /F /IM mariadbd.exe /T 2>$null | Out-Null
        exit 9
    }
    Write-Host "  OK (mariadbd listening, NEW datadir active)" -ForegroundColor Green

    # 7) Login with empty password (default from mysql_install_db) and ALTER USER
    Write-Host "7) Login with empty password + ALTER USER..." -ForegroundColor Cyan
    $emptyLogin = & $mysqlExe -h $DbHost -P "$DbPort" -u $DbUser --default-character-set=utf8mb4 -e "SELECT VERSION();" 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  [FAIL] Empty password login failed: $($emptyLogin -join ' ')" -ForegroundColor Red
        & taskkill.exe /F /IM mariadbd.exe /T 2>$null | Out-Null
        exit 7
    }
    Write-Host "  OK (empty password login works)" -ForegroundColor Green

    # Diagnose: see current root entries
    Write-Host "  Diagnose: see current root entries..." -ForegroundColor Gray
    $diagSql = "SELECT User, Host, JSON_EXTRACT(Priv, '\$.plugin') AS plugin, LEFT(IFNULL(JSON_UNQUOTE(JSON_EXTRACT(Priv, '\$.authentication_string')), '<NULL>'), 30) AS auth_str_start FROM mysql.global_priv WHERE User='root';"
    $diagOut = & $mysqlExe -h $DbHost -P "$DbPort" -u $DbUser --default-character-set=utf8mb4 -e $diagSql 2>&1
    $diagOut | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }

    # DELETE + INSERT into mysql.global_priv (bypass GRANT/ALTER)
    # Use pre-computed password hash: *C9677062716458A38A41FA101A14725A3CE8F1FE
    Write-Host "  DELETE + INSERT root into mysql.global_priv (bypass GRANT/ALTER)..." -ForegroundColor Cyan
    $newHash = "*C9677062716458A38A41FA101A14725A3CE8F1FE"
    $insertSql = @"
DELETE FROM mysql.global_priv WHERE User='root';
INSERT INTO mysql.global_priv (Host, User, Priv) VALUES
  ('localhost', 'root', JSON_OBJECT('access', 18446744073709551615, 'plugin', 'mysql_native_password', 'authentication_string', '$newHash', 'is_role', 'N', 'default_role', '', 'max_connections', 18446744073709551615, 'max_user_connections', 18446744073709551615, 'max_statement_time', 0.0)),
  ('127.0.0.1', 'root', JSON_OBJECT('access', 18446744073709551615, 'plugin', 'mysql_native_password', 'authentication_string', '$newHash', 'is_role', 'N', 'default_role', '', 'max_connections', 18446744073709551615, 'max_user_connections', 18446744073709551615, 'max_statement_time', 0.0)),
  ('::1', 'root', JSON_OBJECT('access', 18446744073709551615, 'plugin', 'mysql_native_password', 'authentication_string', '$newHash', 'is_role', 'N', 'default_role', '', 'max_connections', 18446744073709551615, 'max_user_connections', 18446744073709551615, 'max_statement_time', 0.0));
FLUSH PRIVILEGES;
"@
    Write-Host "  SQL: $insertSql" -ForegroundColor Gray
    $insertOut = & $mysqlExe -h $DbHost -P "$DbPort" -u $DbUser --default-character-set=utf8mb4 -e $insertSql 2>&1
    $insertExit = $LASTEXITCODE
    $insertOut | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
    if ($insertExit -ne 0) {
        Write-Host "  [FAIL] DELETE+INSERT failed" -ForegroundColor Red
        & taskkill.exe /F /IM mariadbd.exe /T 2>$null | Out-Null
        exit 13
    }
    Write-Host "  OK (DELETE+INSERT succeeded)" -ForegroundColor Green

    # Verify root entries
    Write-Host "  Verify root entries after DELETE+INSERT..." -ForegroundColor Gray
    $verifySql = "SELECT User, Host, JSON_EXTRACT(Priv, '\$.plugin') AS plugin, LEFT(IFNULL(JSON_UNQUOTE(JSON_EXTRACT(Priv, '\$.authentication_string')), '<NULL>'), 30) AS auth_str_start FROM mysql.global_priv WHERE User='root';"
    $verifyOut = & $mysqlExe -h $DbHost -P "$DbPort" -u $DbUser --default-character-set=utf8mb4 -e $verifySql 2>&1
    $verifyOut | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }

    # Verify new password
    $testOut = & $mysqlExe -h $DbHost -P "$DbPort" -u $DbUser -p$DbPassword --default-character-set=utf8mb4 -e "SELECT VERSION();" 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  [FAIL] New password verify failed: $($testOut -join ' ')" -ForegroundColor Red
        & taskkill.exe /F /IM mariadbd.exe /T 2>$null | Out-Null
        exit 7
    }
    Write-Host "  [OK] New password works on TCP! Response: $($testOut -join ' ')" -ForegroundColor Green

    # 8) SHUTDOWN clean stop
    Write-Host "8) SHUTDOWN mariadbd..." -ForegroundColor Cyan
    & $mysqlExe -h $DbHost -P "$DbPort" -u $DbUser -p$DbPassword --default-character-set=utf8mb4 -e "SHUTDOWN;" 2>&1 | Out-Null
    Start-Sleep -Seconds 5
    & taskkill.exe /F /IM mariadbd.exe /T 2>$null | Out-Null
    Start-Sleep -Seconds 2
    Write-Host "  OK" -ForegroundColor Green

    # 9) Start MariaDB pointing at NEW datadir
    #    Use mariadbd.exe directly with --datadir (Windows service registration uses old datadir)
    Write-Host "9) Start mariadbd.exe (background) with NEW datadir..." -ForegroundColor Cyan
    $directLog = Join-Path $env:TEMP "mariadbd-direct.log"
    $directArgString = "--datadir=`"$newDataDir`" --port=$DbPort --character-set-server=utf8mb4 --console"
    Write-Host "  args: $directArgString" -ForegroundColor Gray
    $procD = Start-Process -FilePath $mariadbdExe `
        -ArgumentList $directArgString `
        -RedirectStandardOutput $directLog `
        -RedirectStandardError "$directLog.err" `
        -WindowStyle Hidden -PassThru
    Write-Host "  PID: $($procD.Id)" -ForegroundColor Gray
    Start-Sleep -Seconds 6

    $portNow3 = Get-NetTCPConnection -LocalPort $DbPort -State Listen -ErrorAction SilentlyContinue
    if (-not $portNow3) {
        Write-Host "  [FAIL] mariadbd failed to start, see log: $directLog.err" -ForegroundColor Red
        if (Test-Path "$directLog.err") {
            Get-Content "$directLog.err" -Tail 30 | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
        }
        exit 10
    }
    Write-Host "  OK (mariadbd listening on $DbPort with NEW datadir)" -ForegroundColor Green

    # 10) Final verify
    Write-Host "10) Final verify new password..." -ForegroundColor Cyan
    $finalTest = & $mysqlExe -h $DbHost -P "$DbPort" -u $DbUser -p$DbPassword --default-character-set=utf8mb4 -e "SELECT VERSION();" 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[FAIL] Final verify failed: $($finalTest -join ' ')" -ForegroundColor Red
        exit 7
    }
    Write-Host "  OK: $($finalTest -join ' ')" -ForegroundColor Green
    Write-Host ""
    Write-Host "[INFO] MariaDB is now running with NEW datadir: $newDataDir" -ForegroundColor Cyan
    Write-Host "[INFO] The OLD datadir is preserved at: $oldDataDir (not deleted)" -ForegroundColor Cyan
    Write-Host "[INFO] If you want to clean up, you can manually remove: $oldDataDir" -ForegroundColor Cyan
    Write-Host "==== -ResetRootPassword flow complete ====" -ForegroundColor Cyan
    Write-Host ""
}

# ---- Run init.sql ----
if (-not (Test-Path $InitSql)) {
    Write-Host "[FAIL] init.sql not found: $InitSql" -ForegroundColor Red
    exit 4
}
Write-Host "Run init.sql (DROP + CREATE + 15 tables + seed)..." -ForegroundColor Cyan
Get-Content $InitSql -Encoding UTF8 | & $mysqlExe -h $DbHost -P "$DbPort" -u $DbUser -p$DbPassword --default-character-set=utf8mb4 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "[FAIL] init.sql failed, exit code $LASTEXITCODE" -ForegroundColor Red
    exit 3
}
Write-Host "OK" -ForegroundColor Green
Write-Host ""
Write-Host "==== Init complete ====" -ForegroundColor Cyan
Write-Host "  Backend: .\start-backend.ps1" -ForegroundColor Gray
Write-Host "  PC Web:  .\start-frontend-pc.ps1" -ForegroundColor Gray
