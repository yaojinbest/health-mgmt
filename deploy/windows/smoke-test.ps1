# ============================================================================
#  smoke-test.ps1 - 健康管理系统端到端冒烟测试
# ============================================================================
#
#  8 场景 (对齐 d7 smoke-test.sh 15/15 思路, 简化到 8 关键场景):
#    1. 后端 health / version
#    2. H5 dev server / preview
#    3. 患者登录 (user_wang / root)
#    4. 患者健康数据列表
#    5. 医生登录 (doctor_zhang / root)
#    6. 患者档案查询
#    7. 紧急联系人列表
#    8. 健康文章列表
#
#  用法:
#    PS> .\smoke-test.ps1                          # 默认 http://localhost:8090
#    PS> .\smoke-test.ps1 -Base http://10.0.0.5   # 远程主机
# ============================================================================

[CmdletBinding()]
param(
    [string]$Base = "http://localhost:8090",
    [string]$Frontend = "http://localhost:5176"
)

$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$pass = 0
$fail = 0

function Test-Step {
    param([string]$Name, [scriptblock]$Block, [string]$Expect = "200")
    Write-Host "`n▶ $Name" -ForegroundColor Cyan -NoNewline
    try {
        $r = & $Block
        if ($r -match "OK|200|✅") {
            Write-Host "  ✅ PASS" -ForegroundColor Green
            $script:pass++
            return
        }
    } catch {
        Write-Host "  ❌ FAIL: $($_.Exception.Message)" -ForegroundColor Red
        $script:fail++
        return
    }
    Write-Host "  ❌ FAIL" -ForegroundColor Red
    $script:fail++
}

# ---- 1. 后端活跃 ----
Test-Step "1. 后端 ROOT" {
    $r = Invoke-RestMethod "$Base/" -UseBasicParsing -TimeoutSec 5
    return "OK"
}

# ---- 2. 登录 ----
Test-Step "2. 患者登录 (user_wang/root)" {
    $body = @{username="user_wang"; password="root"} | ConvertTo-Json
    $r = Invoke-RestMethod "$Base/api/auth/login" -Method POST -ContentType "application/json" -Body $body -TimeoutSec 5
    if ($r.code -eq 200 -and $r.data.token) {
        $script:patientToken = $r.data.token
        $script:patientId = $r.data.id
        return "OK"
    }
    return $r.message
}

# ---- 3. 健康数据列表 ----
Test-Step "3. 患者健康数据列表" {
    $headers = @{Authorization = "Bearer $script:patientToken"}
    $r = Invoke-RestMethod "$Base/api/health-data/list?userId=$($script:patientId)" `
        -Headers $headers -TimeoutSec 5
    if ($r.code -eq 200) { return "OK" }
    return $r.message
}

# ---- 4. 紧急联系人列表 ----
Test-Step "4. 紧急联系人列表" {
    $headers = @{Authorization = "Bearer $script:patientToken"}
    $r = Invoke-RestMethod "$Base/api/emergency/contact/list?userId=$($script:patientId)" `
        -Headers $headers -TimeoutSec 5
    if ($r.code -eq 200) { return "OK" }
    return $r.message
}

# ---- 5. 健康文章列表 ----
Test-Step "5. 健康文章列表 (公开, 无需登录)" {
    $r = Invoke-RestMethod "$Base/api/article/list" -TimeoutSec 5
    if ($r.code -eq 200) { return "OK" }
    return $r.message
}

# ---- 6. 医生登录 ----
Test-Step "6. 医生登录 (doctor_zhang/root)" {
    $body = @{username="doctor_zhang"; password="root"} | ConvertTo-Json
    $r = Invoke-RestMethod "$Base/api/auth/login" -Method POST -ContentType "application/json" -Body $body -TimeoutSec 5
    if ($r.code -eq 200 -and $r.data.token) {
        $script:doctorToken = $r.data.token
        return "OK"
    }
    return $r.message
}

# ---- 7. 未授权访问 ----
Test-Step "7. 未授权访问被拒 (无 token)" {
    try {
        $r = Invoke-RestMethod "$Base/api/health-data/list" -TimeoutSec 5
        return "❌ 应该 401"
    } catch {
        if ($_.Exception.Response.StatusCode -eq "Unauthorized" -or
            $_.Exception.Response.StatusCode -eq 401) {
            return "OK"
        }
        throw
    }
}

# ---- 8. H5 可达 ----
Test-Step "8. H5 dev server 可达" {
    $r = Invoke-WebRequest "$Frontend/" -UseBasicParsing -TimeoutSec 5
    if ($r.StatusCode -eq 200) { return "OK" }
    return "$($r.StatusCode)"
}

# ---- 总结 ----
Write-Host ""
Write-Host "═════════════════════════════════════════" -ForegroundColor $(if($fail -eq 0){"Green"}else{"Yellow"})
Write-Host "  通过: $pass  |  失败: $fail" -ForegroundColor $(if($fail -eq 0){"Green"}else{"Yellow"})
Write-Host "═════════════════════════════════════════" -ForegroundColor $(if($fail -eq 0){"Green"}else{"Yellow"})

if ($fail -gt 0) { exit 1 } else { exit 0 }
