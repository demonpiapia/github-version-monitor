# stdout-verify.ps1 - stdout 透传独立验证
# 用途：在隔离测试目录中运行 run-full-pipeline.ps1，验证 stdout 透传行为。
#
# 决策依据：
#   - 如果 stdout 透传正常 → T37/T43 使用 run-full-pipeline.ps1 单次执行 + 捕获 stdout
#   - 如果 stdout 透传异常 → T37/T43 改为逐 step 独立执行 + 拼接 stdout
#
# 隔离：通过 GITHUB_VERSION_MONITOR_BASE 指向 stdout-verify/ 目录，禁止触碰生产根目录。

param(
    [Parameter(Mandatory=$true)][string]$TestDir
)

$ErrorActionPreference = 'Stop'
$libDir = Join-Path (Get-Location) '.production-validation-v110-final\lib'

# 创建隔离测试目录
$verifyDir = Join-Path $TestDir 'stdout-verify'
if (-not (Test-Path $verifyDir)) { New-Item -ItemType Directory -Force -Path $verifyDir | Out-Null }

# 生成 fixture（normal 场景，1 个仓库）
& pwsh -NoProfile -NonInteractive -File (Join-Path $libDir 'create-fixture.ps1') -BaseDir $verifyDir -Scenario 'normal'
if ($LASTEXITCODE -ne 0) { throw 'create-fixture failed' }

# 运行完整管线，捕获 stdout 和 stderr
$stdoutFile = Join-Path $TestDir 'stdout-verify-stdout.txt'
$stderrFile = Join-Path $TestDir 'stdout-verify-stderr.txt'

# 使用 pwsh -File 执行，捕获 stdout 和 stderr 到文件
$proc = Start-Process -FilePath 'pwsh' -ArgumentList @(
    '-NoProfile', '-NonInteractive', '-File',
    (Join-Path $libDir 'run-full-pipeline.ps1'),
    '-BaseDir', $verifyDir
) -RedirectStandardOutput $stdoutFile -RedirectStandardError $stderrFile -NoNewWindow -Wait -PassThru

$exitCode = $proc.ExitCode

# 读取输出
$stdoutContent = Get-Content $stdoutFile -Raw
$stderrContent = Get-Content $stderrFile -Raw

# 验证 stdout 透传
$lines = @()
$lines += "=== stdout 透传独立验证 ==="
$lines += "测试目录: $verifyDir"
$lines += "执行时间: $(Get-Date -Format o)"
$lines += "退出码: $exitCode"
$lines += ""
$lines += "=== stdout 内容 ==="
$lines += $stdoutContent
$lines += ""
$lines += "=== stderr 内容 ==="
$lines += $stderrContent
$lines += ""

# 检查关键输出标记
$markers = @('BACKUP_OK|', 'FETCH_COMPLETE|', 'SUMMARY|', 'COMMIT_OK|', 'RUN_STATUS|success|')
$lines += "=== 关键输出标记检查 ==="
$allPresent = $true
foreach ($marker in $markers) {
    $present = $stdoutContent.Contains($marker)
    $lines += "  $marker : $(if ($present) { 'PRESENT' } else { 'ABSENT' })"
    if (-not $present) { $allPresent = $false }
}
$lines += ""

# 检查 stdout 透传行为
$lines += "=== stdout 透传行为分析 ==="
$stepMarkers = @('=== STEP 1 START ===', '=== STEP 1 END', '=== STEP 2 START ===', '=== STEP 2 END', '=== STEP 3 START ===', '=== STEP 3 END', '=== STEP 4 START ===', '=== STEP 4 END', '=== STEP 5 START ===', '=== STEP 5 END', '=== PIPELINE COMPLETE ===')
$stepMarkersPresent = 0
foreach ($sm in $stepMarkers) {
    if ($stdoutContent.Contains($sm)) { $stepMarkersPresent++ }
}
$lines += "  step 标记数: $stepMarkersPresent / $($stepMarkers.Count)"
$lines += ""

# 决策
if ($exitCode -eq 0 -and $allPresent -and $stepMarkersPresent -eq $stepMarkers.Count) {
    $lines += "=== 决策 ==="
    $lines += "stdout 透传正常。T37/T43 使用 run-full-pipeline.ps1 单次执行 + 捕获 stdout。"
    $decision = 'PIPELINE_OK'
} else {
    $lines += "=== 决策 ==="
    $lines += "stdout 透传异常。T37/T43 改为逐 step 独立执行 + 拼接 stdout。"
    $lines += "  - 退出码: $exitCode (期望 0)"
    $lines += "  - 关键标记缺失: $(if ($allPresent) { '无' } else { '有' })"
    $lines += "  - step 标记缺失: $($stepMarkers.Count - $stepMarkersPresent) 个"
    $decision = 'PIPELINE_BROKEN'
}

$lines += ""
$lines += "=== 最终决策 ==="
$lines += "DECISION: $decision"

$lines -join "`n" | Set-Content -Path (Join-Path $TestDir 'stdout-verification.txt') -Encoding UTF8
Write-Output "stdout verification complete. Decision: $decision"
