# ============================================================================
#  smoke-test.ps1 - 端到端冒烟测试 (v2)
# ============================================================================
[CmdletBinding()]
param(
    [string]$BackendUrl = "http://localhost:8090",
    [string]$FrontendUrl = "http://localhost:5174"
)

$ErrorActionPreference = "Continue"
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$pass = 0; $fail = 0
function Test-OK($msg) { Write-Host "  PASS $msg" -ForegroundColor Green; $script:pass++ }
function Test-FAIL($msg) { Write-Host "  FAIL $msg" -ForegroundColor Red; $script:fail++ }

Write-Host "后端: $BackendUrl" -ForegroundColor Cyan
Write-Host "前端: $FrontendUrl" -ForegroundColor Cyan
Write-Host ""

# 1. 后端 health
try {
    $r = Invoke-WebRequest "$BackendUrl/api/auth/login" -Method OPTIONS -TimeoutSec 5 -ErrorAction Stop
    Test-OK "后端 8090 端口在听"
} catch {
    Test-FAIL "后端 8090 没起: $($_.Exception.Message)"
}

# 2. 登录 admin
try {
    $r = Invoke-WebRequest "$BackendUrl/api/auth/login" -Method POST `
        -ContentType "application/json" `
        -Body '{"username":"admin","password":"root","role":"ADMIN"}' `
        -TimeoutSec 10 -ErrorAction Stop
    $j = $r.Content | ConvertFrom-Json
    if ($j.code -eq 200 -and $j.data.token) {
        Test-OK "admin/root 登录成功 (token: $($j.data.token.Substring(0,20))...)"
        $token = $j.data.token
    } else {
        Test-FAIL "登录返回码不对: $($j.code) - $($j.message)"
    }
} catch {
    Test-FAIL "登录失败: $($_.Exception.Message)"
}

# 3. 前端首页
try {
    $r = Invoke-WebRequest $FrontendUrl -Method GET -TimeoutSec 5 -ErrorAction Stop
    if ($r.StatusCode -eq 200) { Test-OK "前端 5174 返回 200" } else { Test-FAIL "前端返回 $($r.StatusCode)" }
} catch {
    Test-FAIL "前端没起: $($_.Exception.Message)"
}

Write-Host ""
Write-Host "==== 总结 ====" -ForegroundColor Green
Write-Host "  PASS: $pass" -ForegroundColor Green
Write-Host "  FAIL: $fail" -ForegroundColor $(if ($fail -eq 0) { "Green" } else { "Red" })

if ($fail -gt 0) { exit 1 } else { exit 0 }
