# step2-mock-harness.ps1 — mock 测试包装（Phase 1 Step 7）
#
# 用途：定义 mock Invoke-RestMethod 覆盖 → 执行被测 step2 代码 → 输出请求计数与 result.json 摘要。
# 供 Phase 8（T04-PS7 / T26 / T18）与 Phase 9（T04-PS5.1 / T05-PS5.1）复用。
# PS5.1 兼容：本文件禁用 PS7-only 语法（?? / 三元 ? : / && / ||）。
#
# 用法：
#   pwsh -NoProfile -NonInteractive -File step2-mock-harness.ps1 -BaseDir <dir> -Scenario <name> [-RateRemaining 0|50]
#   powershell.exe -NoProfile -NonInteractive -File step2-mock-harness.ps1 -BaseDir <dir> -Scenario 403 -RateRemaining 0
#
# 前置：base 目录下须已存在 .output/GitHub更新监测列表.md（用 create-fixture.ps1 生成）。
# 注意：Step 2 需要运行锁（Step 1 创建）。本 harness 不执行 Step 1，
#       而是按 §0.5 锁 PID 一致性机制直接写入"当前进程 PID"的锁文件，模拟"同进程连续持有"。

param(
    [Parameter(Mandatory)][string]$BaseDir,
    [Parameter(Mandatory)][string]$Scenario,
    [string]$RateRemaining = '50'
)

$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot

# 1. 载入 mock 库（定义 Invoke-RestMethod 覆盖 + 场景配置）
. (Join-Path $here 'mock-invoke-restmethod.ps1')
$script:MockScenario = $Scenario
$script:MockRateRemaining = $RateRemaining
Write-Output ('MOCK_SCENARIO|{0}|rateRemaining={1}' -f $Scenario, $RateRemaining)

# 2. 隔离 base
$env:GITHUB_VERSION_MONITOR_BASE = $BaseDir

# 3. 锁 PID 一致性机制（§0.5）：Step 2 要求 run.lock 存在且 pid= 当前进程 PID
$monitorDir = Join-Path $BaseDir '.monitor'
New-Item -ItemType Directory -Force -Path $monitorDir | Out-Null
$lockPath = Join-Path $monitorDir 'run.lock'
$nowUtc = [DateTimeOffset]::UtcNow.ToString('o')
Set-Content -Path $lockPath -Value ('pid={0};start={1};step=2;beat={2}' -f $PID, $nowUtc, $nowUtc) -Encoding UTF8
Write-Output ('LOCK_SEEDED|pid={0}|path={1}' -f $PID, $lockPath)

# 4. 执行被测 step2（提取脚本，已验证与 SKILL 原文零差异）
. (Join-Path $here 'step2.ps1')

# 5. 输出请求计数（T04 请求计数验证依据）
Write-Output ('REQUEST_COUNT|latest={0}|reviewApi={1}|html={2}|other={3}' -f $script:MockRequestCounts['releases_latest'], $script:MockRequestCounts['releases_list'], $script:MockRequestCounts['html'], $script:MockRequestCounts['other'])

# 6. result.json 摘要（状态机判定结果）
$resultPath = Join-Path $monitorDir 'result.json'
if (Test-Path $resultPath) {
    $doc = Get-Content $resultPath -Raw | ConvertFrom-Json
    $statuses = @($doc.items | ForEach-Object { $_.repo + '=' + $_.status + '/flag=' + $_.flag + '/review=' + $_.review }) -join '; '
    Write-Output ('RESULT_SUMMARY|total={0}|apiOk={1}|apiErr={2}|pendingReview={3}' -f $doc.stats.total, $doc.stats.apiOk, $doc.stats.apiErr, $doc.stats.pendingReview)
    Write-Output ('RESULT_ITEMS|{0}' -f $statuses)
} else {
    Write-Output 'RESULT_SUMMARY|result.json 不存在（Step 2 未落盘）'
}

# 7. 清理锁（保持测试目录干净；Step 2 正常路径已释放锁，此处兜底）
if (Test-Path $lockPath) {
    $raw = Get-Content $lockPath -Raw -ErrorAction SilentlyContinue
    if ($raw -match ('pid=' + [regex]::Escape([string]$PID) + ';')) {
        Remove-Item $lockPath -Force -ErrorAction SilentlyContinue
        Write-Output 'LOCK_CLEANED'
    } else {
        Write-Output ('LOCK_RETAINED|foreign pid|content={0}' -f $raw)
    }
}

Write-Output 'MOCK_HARNESS_DONE'
