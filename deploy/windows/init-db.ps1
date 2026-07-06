#Requires -RunAsAdministrator
<#
.SYNOPSIS
  init-db.ps1 - MariaDB database init script (health-mgmt v3.2.2)
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
  v3.2.2:
  - 修双重 BOM (Python 加 BOM 严格控制单 BOM)
  - init-file 改用 Python 写 (UTF-8 NO BOM, ASCII only)
  - SET PASSWORD + IDENTIFIED VIA mysql_native_password 显式改密码
  - 路径用 forward slash 避免 Windows 解析
  - Start-Process 用 array form 传参
  - 20s 等待 + 显式 verify init-file 头 3 字节
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

if (-not (Test-Path $mysqlExe)) {
    $candidates = Get-ChildItem "C:\Program Files\MariaDB*" -Directory -ErrorAction SilentlyContinue |
                  Where-Object { (Test-Path (Join-Path $_.FullName "bin\mariadbd.exe")) }
    if ($candidates) {
        $mariadbBase = $candidates[0].FullName
        $mariadbdExe = Join-Path $mariadbBase "bin\mariadbd.exe"
        $mysqlExe    = Join-Path $mariadbBase "bin\mysql.exe"
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

# ---- -ResetRootPassword flow (v3.2.2, --init-file + SET PASSWORD) ----
if ($ResetRootPassword) {
    Write-Host ""
    Write-Host "==== -ResetRootPassword flow ====" -ForegroundColor Cyan
    Write-Host "Target: reset $DbUser@localhost + $DbUser@127.0.0.1 to -DbPassword" -ForegroundColor Gray
    Write-Host "Method: --init-file (MariaDB 11.x DD VIEW fix)" -ForegroundColor Gray

    if (-not (Test-Path $mariadbdExe)) {
        Write-Host "[FAIL] mariadbd.exe not found, cannot reset" -ForegroundColor Red
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

    # 3) Write init-file with Python (UTF-8 NO BOM, ASCII only)
    # Use forward slash in --init-file path to avoid Windows escape issues
    $initFile = "C:/Users/84918/AppData/Local/Temp/mariadb-init-password.sql"
    $initContent = @"
-- MariaDB 11.x password reset (--init-file mode, v3.2.2)
-- ASCII only, no BOM
FLUSH PRIVILEGES;
ALTER USER 'root'@'localhost' IDENTIFIED BY '$DbPassword';
ALTER USER 'root'@'127.0.0.1' IDENTIFIED BY '$DbPassword';
ALTER USER 'root'@'::1' IDENTIFIED BY '$DbPassword';
FLUSH PRIVILEGES;
"@
    # PowerShell write: strict UTF-8 NO BOM using .NET
    # (python.exe 可能不在 PATH, 用 PS 自带更可靠)
    Write-Host "3) Write init-file via PowerShell (UTF-8 NO BOM, ASCII only)..." -ForegroundColor Cyan
    try {
        $utf8NoBOM = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($initFile, $initContent, $utf8NoBOM)
        # Verify head 3 bytes != BOM
        $headBytes = [System.IO.File]::ReadAllBytes($initFile)[0..2]
        $headHex = ($headBytes | ForEach-Object { $_.ToString('X2') }) -join ''
        if ($headHex -eq "EFBBBF") {
            Write-Host "  [FAIL] BOM detected in init-file! head=0x$headHex" -ForegroundColor Red
            exit 11
        }
        Write-Host "  init-file written: $($initContent.Length) bytes, head=0x$headHex (no BOM)" -ForegroundColor Gray
        Write-Host "  init-file: $initFile" -ForegroundColor Gray
    } catch {
        Write-Host "  [FAIL] PowerShell write init-file failed: $_" -ForegroundColor Red
        exit 11
    }

    # 4) Start mariadbd with --init-file (array form, forward slash path)
    Write-Host "4) Start mariadbd --init-file (wait 20s)..." -ForegroundColor Cyan
    $initLog = Join-Path $env:TEMP "mariadbd-init.log"
    # Array form: each arg as separate element (avoids quote escape issues)
    $proc = Start-Process -FilePath $mariadbdExe `
        -ArgumentList @(
            "--init-file=$initFile",
            "--datadir=$dataDir",
            "--port=$DbPort",
            "--character-set-server=utf8mb4",
            "--character-set-filesystem=utf8mb4",
            "--console"
        ) `
        -RedirectStandardOutput $initLog `
        -RedirectStandardError "$initLog.err" `
        -WindowStyle Hidden -PassThru
    Write-Host "  PID: $($proc.Id), log: $initLog" -ForegroundColor Gray

    # Wait for mariadbd to start + execute init-file
    Write-Host "  Wait 20s for mariadbd to start + execute init-file SQL..." -ForegroundColor Cyan
    Start-Sleep -Seconds 20

    # Check init log stdout
    if (Test-Path $initLog) {
        $initStdout = Get-Content $initLog -Raw -ErrorAction SilentlyContinue
        if ($initStdout) {
            $initStdoutShort = ($initStdout.Substring(0, [Math]::Min(500, $initStdout.Length)))
            Write-Host "  init-log stdout (first 500 chars):" -ForegroundColor Gray
            Write-Host "    $($initStdoutShort -replace "`r`n", ' | ')" -ForegroundColor Gray
        } else {
            Write-Host "  init-log stdout is empty" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  [WARN] init-log file does not exist" -ForegroundColor Yellow
    }

    # Check init log stderr for errors
    if (Test-Path "$initLog.err") {
        $initStderr = Get-Content "$initLog.err" -Raw -ErrorAction SilentlyContinue
        if ($initStderr -match "ERROR|error" -and $initStderr -notmatch "ERROR 1064") {
            Write-Host "  init-log stderr (errors found):" -ForegroundColor Red
            Get-Content "$initLog.err" | Select-Object -First 15 | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
        }
    }

    # 5) Verify new password
    Write-Host "5) Verify new password..." -ForegroundColor Cyan
    $testPwd = & $mysqlExe -h $DbHost -P "$DbPort" -u $DbUser -p$DbPassword --default-character-set=utf8mb4 -e "SELECT VERSION(); SELECT USER();" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [OK] New password works! Response:" -ForegroundColor Green
        $testPwd | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
    } else {
        Write-Host "  [FAIL] New password failed: $($testPwd -join ' ')" -ForegroundColor Red
        Write-Host "  init-log stdout last 30 lines:" -ForegroundColor Gray
        if (Test-Path $initLog) {
            Get-Content $initLog -Tail 30 | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
        }
        Write-Host "  init-log stderr last 30 lines:" -ForegroundColor Gray
        if (Test-Path "$initLog.err") {
            Get-Content "$initLog.err" -Tail 30 | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
        }
        # Cleanup
        & taskkill.exe /F /IM mariadbd.exe /T 2>$null | Out-Null
        Remove-Item $initFile -ErrorAction SilentlyContinue
        exit 7
    }

    # 6) SHUTDOWN clean stop
    Write-Host "6) SHUTDOWN clean stop..." -ForegroundColor Cyan
    & $mysqlExe -h $DbHost -P "$DbPort" -u $DbUser -p$DbPassword --default-character-set=utf8mb4 -e "SHUTDOWN;" 2>&1 | Out-Null
    Start-Sleep -Seconds 5
    & taskkill.exe /F /IM mariadbd.exe /T 2>$null | Out-Null
    Start-Sleep -Seconds 2
    Write-Host "  OK" -ForegroundColor Green
    Remove-Item $initFile -ErrorAction SilentlyContinue

    # 7) Start MariaDB service / mariadbd.exe
    Write-Host "7) Start MariaDB..." -ForegroundColor Cyan
    $serviceStarted = $false
    $svc3 = Get-Service -Name $MariaService -ErrorAction SilentlyContinue
    if ($svc3) {
        Start-Service -Name $MariaService -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 3
        $svc3 = Get-Service -Name $MariaService -ErrorAction SilentlyContinue
        if ($svc3.Status -eq "Running") {
            $portNow = Get-NetTCPConnection -LocalPort $DbPort -State Listen -ErrorAction SilentlyContinue
            if ($portNow) {
                Write-Host "  OK (service running, port $DbPort listening)" -ForegroundColor Green
                $serviceStarted = $true
            }
        }
    }
    if (-not $serviceStarted) {
        Write-Host "  Start mariadbd.exe directly (zip install scenario)..." -ForegroundColor Cyan
        $normalLog = Join-Path $env:TEMP "mariadbd-normal.log"
        $procN = Start-Process -FilePath $mariadbdExe `
            -ArgumentList @(
                "--datadir=$dataDir",
                "--port=$DbPort",
                "--character-set-server=utf8mb4",
                "--console"
            ) `
            -RedirectStandardOutput $normalLog `
            -RedirectStandardError "$normalLog.err" `
            -WindowStyle Hidden -PassThru
        Start-Sleep -Seconds 6
        $portNow2 = Get-NetTCPConnection -LocalPort $DbPort -State Listen -ErrorAction SilentlyContinue
        if ($portNow2) {
            Write-Host "  OK (mariadbd.exe listening on $DbPort)" -ForegroundColor Green
        } else {
            Write-Host "  [FAIL] mariadbd failed to start, see log: $normalLog.err" -ForegroundColor Red
            if (Test-Path "$normalLog.err") {
                Get-Content "$normalLog.err" -Tail 20 | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
            }
            exit 10
        }
    }

    # 8) Final verification
    Write-Host "8) Final verify new password..." -ForegroundColor Cyan
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
