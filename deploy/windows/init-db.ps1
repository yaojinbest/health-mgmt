#Requires -RunAsAdministrator
<#
.SYNOPSIS
  init-db.ps1 - MariaDB database init script (health-mgmt v3.2.8)
.DESCRIPTION
  2 modes:
  1. Normal: test conn, run init.sql (DROP+CREATE+seed)
  2. -ResetRootPassword: crack/reset MariaDB root password

  Usage:
    .\init-db.ps1                          # interactive
    .\init-db.ps1 -DbPassword opck2026     # direct
    .\init-db.ps1 -ResetRootPassword       # force reset
    .\init-db.ps1 -DbPassword opck2026 -ResetRootPassword
.NOTES
  v3.2.8:
  Reset strategy: mysql_install_db.exe --password=...
  - MariaDB official password reset tool
  - Recreates the mysql system database
  - Sets root password directly
  - Does NOT touch user databases (only mysql/* system tables)
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

# ---- -ResetRootPassword flow (v3.2.8, mysql_install_db --password) ----
if ($ResetRootPassword) {
    Write-Host ""
    Write-Host "==== -ResetRootPassword flow ====" -ForegroundColor Cyan
    Write-Host "Target: reset $DbUser to -DbPassword" -ForegroundColor Gray
    Write-Host "Method: mysql_install_db.exe --password (recreate mysql system db)" -ForegroundColor Gray
    Write-Host "Note: only the mysql system database is recreated, user databases untouched" -ForegroundColor Gray

    if (-not (Test-Path $mariadbdExe)) {
        Write-Host "[FAIL] mariadbd.exe not found, cannot reset" -ForegroundColor Red
        exit 5
    }
    if (-not (Test-Path $mariadbInstallDbExe)) {
        Write-Host "[FAIL] mysql_install_db.exe not found at: $mariadbInstallDbExe" -ForegroundColor Red
        Write-Host "  Cannot reset via this method, manual intervention required" -ForegroundColor Red
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

    # 2) Find datadir
    $dataDir = "C:\Program Files\MariaDB 11.8\data"
    if (-not (Test-Path $dataDir)) {
        $candidates = Get-ChildItem "C:\Program Files\MariaDB*" -Directory -ErrorAction SilentlyContinue
        if ($candidates) {
            $dataDir = $candidates[0].FullName + "\data"
        }
    }
    Write-Host "2) datadir: $dataDir" -ForegroundColor Gray

    # 3) Backup and remove mysql system database files (NOT user databases)
    Write-Host "3) Backup + remove mysql system db (recreate it)..." -ForegroundColor Cyan
    $mysqlDbDir = Join-Path $dataDir "mysql"
    $backupDir = "C:/Users/84918/AppData/Local/Temp/mariadb-mysql-backup"
    if (-not (Test-Path $backupDir)) {
        New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    }
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $backupTarget = Join-Path $backupDir "mysql-backup-$timestamp"
    Write-Host "  Backup: $mysqlDbDir -> $backupTarget" -ForegroundColor Gray
    Copy-Item -Path $mysqlDbDir -Destination $backupTarget -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "  Remove: $mysqlDbDir" -ForegroundColor Gray
    Remove-Item -Path $mysqlDbDir -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "  OK" -ForegroundColor Green

    # 4) Run mysql_install_db.exe to recreate system tables
    Write-Host "4) Run mysql_install_db.exe --password=... ..." -ForegroundColor Cyan
    $installLog = Join-Path $env:TEMP "mysql-install-db.log"
    $installArgs = "--datadir=`"$dataDir`" --password=`"$DbPassword`" --auth-root-authentication-method=normal"
    Write-Host "  args: $installArgs" -ForegroundColor Gray
    $installOut = & $mariadbInstallDbExe $installArgs.Split(" ") 2>&1
    $installExit = $LASTEXITCODE
    Write-Host "  exit code: $installExit" -ForegroundColor Gray
    $installOut | Select-Object -First 30 | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
    if ($installExit -ne 0) {
        Write-Host "  [FAIL] mysql_install_db failed" -ForegroundColor Red
        # Try to restore backup
        if (Test-Path $backupTarget) {
            Write-Host "  Restoring backup from: $backupTarget" -ForegroundColor Yellow
            Copy-Item -Path $backupTarget -Destination $mysqlDbDir -Recurse -Force
        }
        exit 13
    }
    Write-Host "  OK (mysql system db recreated)" -ForegroundColor Green

    # 5) Start mariadbd in normal mode
    Write-Host "5) Start mariadbd normal mode (wait 8s)..." -ForegroundColor Cyan
    $normalLog = Join-Path $env:TEMP "mariadbd-normal.log"
    $normalArgString = "--datadir=`"$dataDir`" --port=$DbPort --character-set-server=utf8mb4 --character-set-filesystem=utf8mb4 --console"
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
            Get-Content "$normalLog.err" -Tail 20 | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
        }
        & taskkill.exe /F /IM mariadbd.exe /T 2>$null | Out-Null
        exit 9
    }
    Write-Host "  OK (mariadbd listening)" -ForegroundColor Green

    # 6) Verify new password + ensure root can access from TCP
    Write-Host "6) Verify new password + TCP access..." -ForegroundColor Cyan
    $testOut = & $mysqlExe -h $DbHost -P "$DbPort" -u $DbUser -p$DbPassword --default-character-set=utf8mb4 -e "SELECT VERSION();" 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  [FAIL] Verify failed: $($testOut -join ' ')" -ForegroundColor Red
        & taskkill.exe /F /IM mariadbd.exe /T 2>$null | Out-Null
        exit 7
    }
    Write-Host "  [OK] New password works on TCP! Response: $($testOut -join ' ')" -ForegroundColor Green

    # 7) SHUTDOWN clean stop
    Write-Host "7) SHUTDOWN mariadbd..." -ForegroundColor Cyan
    & $mysqlExe -h $DbHost -P "$DbPort" -u $DbUser -p$DbPassword --default-character-set=utf8mb4 -e "SHUTDOWN;" 2>&1 | Out-Null
    Start-Sleep -Seconds 5
    & taskkill.exe /F /IM mariadbd.exe /T 2>$null | Out-Null
    Start-Sleep -Seconds 2
    Write-Host "  OK" -ForegroundColor Green

    # 8) Start MariaDB service (preferred) or mariadbd.exe directly
    Write-Host "8) Start MariaDB service..." -ForegroundColor Cyan
    $serviceStarted = $false
    $svc3 = Get-Service -Name $MariaService -ErrorAction SilentlyContinue
    if ($svc3) {
        Start-Service -Name $MariaService -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 3
        $svc3 = Get-Service -Name $MariaService -ErrorAction SilentlyContinue
        if ($svc3.Status -eq "Running") {
            $portNow2 = Get-NetTCPConnection -LocalPort $DbPort -State Listen -ErrorAction SilentlyContinue
            if ($portNow2) {
                Write-Host "  OK (service running, port $DbPort listening)" -ForegroundColor Green
                $serviceStarted = $true
            }
        }
    }
    if (-not $serviceStarted) {
        Write-Host "  Start mariadbd.exe directly (zip install)..." -ForegroundColor Cyan
        $directLog = Join-Path $env:TEMP "mariadbd-direct.log"
        $directArgString = "--datadir=`"$dataDir`" --port=$DbPort --character-set-server=utf8mb4 --console"
        $procD = Start-Process -FilePath $mariadbdExe `
            -ArgumentList $directArgString `
            -RedirectStandardOutput $directLog `
            -RedirectStandardError "$directLog.err" `
            -WindowStyle Hidden -PassThru
        Start-Sleep -Seconds 6
        $portNow3 = Get-NetTCPConnection -LocalPort $DbPort -State Listen -ErrorAction SilentlyContinue
        if ($portNow3) {
            Write-Host "  OK (mariadbd.exe listening)" -ForegroundColor Green
        } else {
            Write-Host "  [FAIL] mariadbd failed, see log: $directLog.err" -ForegroundColor Red
            if (Test-Path "$directLog.err") {
                Get-Content "$directLog.err" -Tail 20 | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
            }
            exit 10
        }
    }

    # 9) Final verify
    Write-Host "9) Final verify new password..." -ForegroundColor Cyan
    $finalTest = & $mysqlExe -h $DbHost -P "$DbPort" -u $DbUser -p$DbPassword --default-character-set=utf8mb4 -e "SELECT VERSION();" 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[FAIL] Final verify failed: $($finalTest -join ' ')" -ForegroundColor Red
        exit 7
    }
    Write-Host "  OK: $($finalTest -join ' ')" -ForegroundColor Green
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
