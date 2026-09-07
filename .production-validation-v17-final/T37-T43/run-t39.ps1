# T39 - Commit Success + Lock Release Failure
# Run Steps 1-5 normally (COMMIT_OK), then inject foreign PID at Step 6
# Expected: COMMIT_OK, RUNTIME_ERROR, RUN_STATUS|failed|, foreign lock retained

$ErrorActionPreference = 'Continue'
$baseDir = 'd:\AI\Workspace\automatic\github-version-monitor\.production-validation-v17-final\T37-T43'
$testDir = Join-Path $baseDir 'T39'
$libDir = Join-Path $baseDir 'lib'
$mdPath = Join-Path $testDir 'GitHub更新监测列表.md'
$monitorDir = Join-Path $testDir '.monitor'

# Clean any previous test artifacts
if (Test-Path (Join-Path $testDir '.monitor')) { Remove-Item (Join-Path $testDir '.monitor') -Recurse -Force }
if (Test-Path $mdPath) { Remove-Item $mdPath -Force }

# Create fixture: microsoft/vscode with localVer=1.0.0
$lines = @()
$lines += '> 最近核对时间：2026-09-01 00:00（北京时间，初始状态）'
$lines += ''
$lines += '## 监测列表'
$lines += ''
$lines += '| # | 项目名称 | GIT最新版本 | GIT更新日期 | 本地版本 | 是否更新 |'
$lines += '|---|---|---|---|---|---|'
$lines += '| 1 | [VSCode](https://github.com/microsoft/vscode/releases) | | | 1.0.0 | no |'
$lines += ''
$lines += '## 结论'
$lines += ''
$lines += '（初始结论）'
$lines += ''
$lines += '## 更新摘要'
$lines += ''
$lines += '（初始摘要）'
$lines += ''
$lines += '## 备注'
$lines += ''
$lines += '（初始备注）'
$lines += ''
$lines += '## 核对方法'
$lines += ''
$lines += 'GitHub REST API 直连，无 HTML 回退。'

$fixtureContent = $lines -join "`r`n"
Set-Content -Path $mdPath -Value $fixtureContent -Encoding UTF8 -NoNewline
$originalSha = (Get-FileHash $mdPath -Algorithm SHA256).Hash

$env:GITHUB_VERSION_MONITOR_BASE = $testDir

$allOutput = @()

# Step 1: Lock + backup
$allOutput += "===== EXECUTING step1 ====="
$step1Out = & (Join-Path $libDir 'step1.ps1') 2>&1
$allOutput += $step1Out
$allOutput += "===== END step1 ====="

# Step 2: Parse + fetch + result.json
$allOutput += "===== EXECUTING step2 ====="
$step2Out = & (Join-Path $libDir 'step2.ps1') 2>&1
$allOutput += $step2Out
$allOutput += "===== END step2 ====="

# Step 3: Cleanup
$allOutput += "===== EXECUTING step3 ====="
$step3Out = & (Join-Path $libDir 'step3.ps1') 2>&1
$allOutput += $step3Out
$allOutput += "===== END step3 ====="

# Step 4: Review
$allOutput += "===== EXECUTING step4 ====="
$step4Out = & (Join-Path $libDir 'step4.ps1') 2>&1
$allOutput += $step4Out
$allOutput += "===== END step4 ====="

# Step 5 (commit only): Should output COMMIT_OK
$allOutput += "===== EXECUTING step5-commit ====="
$step5Out = & (Join-Path $libDir 'step5-commit.ps1') 2>&1
$allOutput += $step5Out
$allOutput += "===== END step5-commit ====="

# FAULT INJECTION: Modify lock file to have a foreign PID
$lockPath = Join-Path $monitorDir 'run.lock'
$allOutput += "===== FAULT INJECTION: Replacing lock PID with foreign PID 999998 ====="
$lockContent = Get-Content $lockPath -Raw
$startTok = if ($lockContent -match 'start=([^;\r\n]+)') { $Matches[1] } else { 'unknown' }
$foreignLockContent = "pid=999998;start=$startTok;step=5;beat=$([DateTimeOffset]::UtcNow.ToString('o'))"
Set-Content -Path $lockPath -Value $foreignLockContent -Encoding UTF8 -NoNewline
$allOutput += "Lock file modified to foreign PID=999998"

# Step 6 (lock release): Should fail ownership check
$allOutput += "===== EXECUTING step6-lockrelease (with foreign PID) ====="
$step6Out = & (Join-Path $libDir 'step6-lockrelease.ps1') 2>&1
$allOutput += $step6Out
$allOutput += "===== END step6-lockrelease ====="

# Save outputs
$stdoutText = $allOutput | Out-String
$stdoutText | Set-Content -Path (Join-Path $testDir 'stdout.txt') -Encoding UTF8
'' | Set-Content -Path (Join-Path $testDir 'stderr.txt') -Encoding UTF8

# Verify results
$results = @()
$results += "## T39 - Commit Success + Lock Release Failure"
$results += ""
$results += "### Fixture"
$results += "- microsoft/vscode with localVer=1.0.0"
$results += ""

$combined = $stdoutText

# Check COMMIT_OK was output
$hasCommitOk = $combined -match 'COMMIT_OK\|'
$results += "- COMMIT_OK output: $hasCommitOk"

# Check RUNTIME_ERROR
$hasRuntimeError = $combined -match 'RUNTIME_ERROR\|'
$results += "- RUNTIME_ERROR output: $hasRuntimeError"

# Check RUN_STATUS|failed|
$hasRunFailed = $combined -match 'RUN_STATUS\|failed\|'
$results += "- RUN_STATUS|failed|: $hasRunFailed"

# Check no RUN_STATUS|success|
$noRunSuccess = -not ($combined -match 'RUN_STATUS\|success\|')
$results += "- No RUN_STATUS|success|: $noRunSuccess"

# Check main md was updated (commit succeeded)
$updatedSha = (Get-FileHash $mdPath -Algorithm SHA256).Hash
$mdChanged = ($updatedSha -ne $originalSha)
$results += "- Main md was updated by commit: $mdChanged"

# Check foreign lock retained (not deleted)
$lockStillExists = Test-Path $lockPath
$results += "- Foreign lock retained (not deleted): $lockStillExists"

# Verify lock content has foreign PID
$lockContentAfter = Get-Content $lockPath -Raw
$hasForeignPid = $lockContentAfter -match 'pid=999998'
$results += "- Lock still has foreign PID 999998: $hasForeignPid"

# Overall
$allPass = $hasCommitOk -and $hasRuntimeError -and $hasRunFailed -and $noRunSuccess -and $lockStillExists -and $hasForeignPid
$results += ""
$results += "### Result: $(if ($allPass) {'**PASS**'} else {'**FAIL**'})"

# Save test report
$results | Set-Content -Path (Join-Path $testDir 'test-report.md') -Encoding UTF8

# Output results
$results | ForEach-Object { Write-Output $_ }
Write-Output ""
Write-Output "=== STDOUT ==="
Write-Output $stdoutText
