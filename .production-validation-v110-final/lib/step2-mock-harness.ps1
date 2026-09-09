# step2-mock-harness.ps1 - mock 测试包装脚本
# 用途：定义 mock Invoke-RestMethod → dot-source step2.ps1
#
# 用法：
#   pwsh -NoProfile -NonInteractive -File step2-mock-harness.ps1 -Scenario <name> -BaseDir <path> [-TagName <t>] [-PublishedAt <ts>]
#
# PS5.1 语法兼容要求：本脚本在 Phase 1（PS7）创建，被 Phase 8（PS5.1）复用。
# 禁用 PS7-only 运算符：?? / ? :（三元）/ && / ||（管道链）。
#
# 场景列表（详见 mock-invoke-restmethod.ps1）：
#   normal / versionJump / metadata_incomplete / invalid_response
#   not_found / auth_error / rate_limited_429 / rate_limited_403 / forbidden
#   server_error / http_error / network_error

param(
    [Parameter(Mandatory=$true)][string]$Scenario,
    [Parameter(Mandatory=$true)][string]$BaseDir,
    [string]$TagName = 'v1.0.0',
    [string]$PublishedAt = '2026-09-01T00:00:00Z'
)

$ErrorActionPreference = 'Stop'

# 设置隔离 base 目录
$env:GITHUB_VERSION_MONITOR_BASE = $BaseDir

# 加载 mock 函数库（dot-source 使 mock Invoke-RestMethod 进入当前作用域）
$mockLibPath = Join-Path $PSScriptRoot 'mock-invoke-restmethod.ps1'
. $mockLibPath

# 设置场景
Set-MockScenario -Scenario $Scenario -TagName $TagName -PublishedAt $PublishedAt

# 加载被测代码（dot-source step2.ps1，使 mock Invoke-RestMethod 生效）
$step2Path = Join-Path $PSScriptRoot 'step2.ps1'
. $step2Path

# 输出 mock 调用日志（用于 T04 请求计数验证）
$callLog = Get-MockCallLog
Write-Output ("MOCK_CALLS|" + $callLog.Count)
foreach ($c in $callLog) {
    Write-Output ("MOCK_CALL|" + $c.Scenario + "|" + $c.Uri)
}
