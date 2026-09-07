# T38 - Review Failure Test
# Inject fault during Step 4 review write (lock result.json during result.review.tmp -> result.json move)
# Expected: REVIEW_WRITE_ERROR, no COMMIT_OK, RUN_STATUS|failed| (no success), main md unchanged

$ErrorActionPreference = 'Continue'
$baseDir = 'd:\AI\Workspace\automatic\github-version-monitor\.production-validation-v17-final\T37-T43'
$testDir = Join-Path $baseDir 'T38'
$libDir = Join-Path $baseDir 'lib'
$mdPath = Join-Path $testDir 'GitHub更新监测列表.md'
$monitorDir = Join-Path $testDir '.monitor'

# Clean any previous test artifacts
if (Test-Path (Join-Path $testDir '.monitor')) { Remove-Item (Join-Path $testDir '.monitor') -Recurse -Force }
if (Test-Path $mdPath) { Remove-Item $mdPath -Force }

# Create fixture: microsoft/vscode with localVer="some-weird-string" (triggers incomparable -> review=true)
$lines = @()
$lines += '> 最近核对时间：2026-09-01 00:00（北京时间，初始状态）'
$lines += ''
$lines += '## 监测列表'
$lines += ''
$lines += '| # | 项目名称 | GIT最新版本 | GIT更新日期 | 本地版本 | 是否更新 |'
$lines += '|---|---|---|---|---|---|'
$lines += '| 1 | [VSCode](https://github.com/microsoft/vscode/releases) | | | some-weird-string | no |'
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

$step1Combined = $step1Out | Out-String
if ($step1Combined -match 'STATE_MISSING\|' -or $step1Combined -match 'LOCKED\|') {
    $allOutput += "Step 1 blocked, stopping."
    $allOutput | ForEach-Object { Write-Output $_ }
    return
}

# Step 2: Parse + fetch + result.json
$allOutput += "===== EXECUTING step2 ====="
$step2Out = & (Join-Path $libDir 'step2.ps1') 2>&1
$allOutput += $step2Out
$allOutput += "===== END step2 ====="

$step2Combined = $step2Out | Out-String
if ($step2Combined -match 'PARSE_ERROR\|' -or $step2Combined -match 'RUNTIME_ERROR\|' -or $step2Combined -match 'LOCKED\|') {
    $allOutput += "Step 2 failed, stopping."
    $allOutput | ForEach-Object { Write-Output $_ }
    return
}

# Step 3: Cleanup
$allOutput += "===== EXECUTING step3 ====="
$step3Out = & (Join-Path $libDir 'step3.ps1') 2>&1
$allOutput += $step3Out
$allOutput += "===== END step3 ====="

# Verify result.json exists
$resultJsonPath = Join-Path $monitorDir 'result.json'
if (-not (Test-Path $resultJsonPath)) {
    $allOutput += "result.json not found after Step 2, cannot proceed with fault injection."
    $allOutput | ForEach-Object { Write-Output $_ }
    return
}

# Verify review=true exists in result.json
$resultJson = Get-Content $resultJsonPath -Raw | ConvertFrom-Json
$reviewCount = @($resultJson.items | Where-Object { $_.review -eq $true }).Count
$allOutput += "Review items found: $reviewCount"

if ($reviewCount -eq 0) {
    $allOutput += "No review items found, cannot test review failure."
    $allOutput | ForEach-Object { Write-Output $_ }
    return
}

# FAULT INJECTION: Open result.json with FileShare::Read (allows reads, blocks writes/moves)
$allOutput += "===== FAULT INJECTION: Locking result.json with FileShare::Read ====="
$resultJsonStream = [System.IO.File]::Open($resultJsonPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read)
$allOutput += "result.json locked for exclusive write access (FileShare::Read)"

# Step 4: Review (should fail at Move-Item)
$allOutput += "===== EXECUTING step4 (with fault) ====="
$step4Out = & (Join-Path $libDir 'step4.ps1') 2>&1
$allOutput += $step4Out
$allOutput += "===== END step4 ====="

# Release the file handle
$resultJsonStream.Close()
$allOutput += "Fault injection handle released"

# Do NOT run Step 5 (pipeline should stop at REVIEW_WRITE_ERROR)

# Save outputs
$stdoutText = $allOutput | Out-String
$stdoutText | Set-Content -Path (Join-Path $testDir 'stdout.txt') -Encoding UTF8
'' | Set-Content -Path (Join-Path $testDir 'stderr.txt') -Encoding UTF8

# Verify results
$results = @()
$results += "## T38 - Review Failure"
$results += ""
$results += "### Fixture"
$results += "- microsoft/vscode with localVer=some-weird-string (triggers incomparable -> review=true)"
$results += ""

$combined = $stdoutText

# Check REVIEW_WRITE_ERROR
$hasReviewWriteError = $combined -match 'REVIEW_WRITE_ERROR\|'
$results += "- REVIEW_WRITE_ERROR output: $hasReviewWriteError"

# Check no COMMIT_OK
$hasCommitOk = $combined -match 'COMMIT_OK\|'
$results += "- No COMMIT_OK: $(-not $hasCommitOk)"

# Check no RUN_STATUS|success|
$hasRunSuccess = $combined -match 'RUN_STATUS\|success\|'
$results += "- No RUN_STATUS|success|: $(-not $hasRunSuccess)"

# Check main md unchanged
$updatedSha = (Get-FileHash $mdPath -Algorithm SHA256).Hash
$mdUnchanged = ($updatedSha -eq $originalSha)
$results += "- Main md SHA256 unchanged: $mdUnchanged (original=$originalSha, updated=$updatedSha)"

# Check lock released (Step 4 error path should release it)
$lockPath = Join-Path $monitorDir 'run.lock'
$lockReleased = -not (Test-Path $lockPath)
$results += "- Lock released (by Step 4 error path): $lockReleased"

# Check review.tmp not left behind
$reviewTmpPath = Join-Path $monitorDir 'result.review.tmp'
$noReviewTmpLeft = -not (Test-Path $reviewTmpPath)
$results += "- result.review.tmp cleaned up: $noReviewTmpLeft"

# Overall
$allPass = $hasReviewWriteError -and (-not $hasCommitOk) -and (-not $hasRunSuccess) -and $mdUnchanged
$results += ""
$results += "### Result: $(if ($allPass) {'**PASS**'} else {'**FAIL**'})"

# Save test report
$results | Set-Content -Path (Join-Path $testDir 'test-report.md') -Encoding UTF8

# Output results
$results | ForEach-Object { Write-Output $_ }
Write-Output ""
Write-Output "=== STDOUT ==="
Write-Output $stdoutText
