#Requires -RunAsAdministrator
<#
.SYNOPSIS
  restart-all.ps1 - 重启健康管理系统 (stop + install 启动部分)
.NOTES
  v4.0
#>

[CmdletBinding()]
param()

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  健康管理系统 重启服务" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# 1. 停止
Write-Host "[1/2] 停止现有服务 ..." -ForegroundColor Cyan
& "$ScriptDir\stop-all.ps1"

# 2. 启动 (复用 install.ps1 的 step 7 逻辑, 或直接重跑 install)
Write-Host ""
Write-Host "[2/2] 重新部署 ..." -ForegroundColor Cyan
& "$ScriptDir\install.ps1"