#Requires -Version 7.0
<#
    T21 - review atomicity
    Test: when Move-Item result.review.tmp -> result.json fails (destination locked),
          the old result.json is NOT corrupted (stats/items/review all unchanged).

    Expected SKILL-v1.7.md behavior (Step 4, line 479):
      try { Move-Item $tmpPath $resultPath -Force }
      catch {
          Remove-Item $tmpPath -Force -ErrorAction SilentlyContinue
          Write-Output ('REVIEW_WRITE_ERROR|review 原子替换失败：{0}' -f $_.Exception.Message)
          Release-LockSafely
          return
      }
#>

$ErrorActionPreference = 'Stop'

$testDir    = $PSScriptRoot
$base       = Join-Path $testDir 'test-base'
$mdPath     = Join-Path $base 'GitHub更新监测列表.md'
$monitorDir = Join-Path $base '.monitor'
$resultPath = Join-Path $monitorDir 'result.json'
$tmpPath    = Join-Path $monitorDir 'result.review.tmp'
$lockPath   = Join-Path $monitorDir 'run.lock'

$stdout = [System.Collections.Generic.List[string]]::new()
function Log([string]$m) { Write-Host $m; $stdout.Add($m) | Out-Null }

# ---- Fixture setup ---------------------------------------------------------
$mdContent = @"
# GitHub 更新监测列表

> 最近核对时间：2026-09-07 12:00（北京时间）

## 监测列表

| # | 项目名称 | GIT最新版本 | GIT更新日期 | 本地版本 | 是否更新 |
|---|---------|-------------|-------------|----------|----------|
| 1 | [VS Code](https://github.com/microsoft/vscode/releases) | 1.96.0 | 2025-01-15 | 1.95.0 | yes |

## 结论

（占位）

## 更新摘要

（占位）

## 备注

（占位）

## 核对方法

（占位）
"@
Set-Content -Path $mdPath -Value $mdContent -Encoding UTF8

$lockContent = "pid=$PID;start=2026-09-07T04:00:00.0000000Z;step=4;beat=2026-09-07T04:00:00.0000000Z"
Set-Content -Path $lockPath -Value $lockContent -Encoding UTF8

# Original result.json: review=true item, review.performed=false (Step 4 will set performed=true)
$origDoc = [ordered]@{
    runAt = '2026-09-07T04:00:00.0000000Z'
    stats = [ordered]@{
        total = 1; apiOk = 0; apiErr = 1; synced = 0; yes = 0; uninstalled = 0
        pendingReview = 1; newReleases = 0; flips = 0; token = 'set'
    }
    items = @([ordered]@{
        repo = 'microsoft/vscode'; name = 'VS Code'
        gitVer = '1.96.0'; gitDate = '2025-01-15'; localVer = '1.95.0'
        flag = 'no'; prevFlag = 'no'
        latest = ''; publishedUtc = ''
        status = 'not_found'; cmp = ''; isNew = $false; isFlip = $false
        versionJump = $false; dateSuspicious = $false; review = $true
        reviewReasons = @('not_found'); error = '404'
    })
    review = [ordered]@{ performed = $false; items = @() }
}
$origJson = $origDoc | ConvertTo-Json -Depth 8
Set-Content -Path $resultPath -Value $origJson -Encoding UTF8

$shaBefore = (Get-FileHash $resultPath -Algorithm SHA256).Hash
$origStats = $origDoc.stats | ConvertTo-Json -Depth 8 -Compress
$origItems = $origDoc.items | ConvertTo-Json -Depth 8 -Compress

Log "========== T21 - review atomicity =========="
Log "Base dir: $base"
Log "result.json SHA256 (before): $shaBefore"

# ---- Fault injection: lock result.json -----------------------------------
$fs = [System.IO.File]::Open($resultPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
Log "Locked result.json with FileShare::None"

# ---- Simulate SKILL Step 4 atomic-write sequence --------------------------
# Step 4 builds a new doc with review.performed=true and review.items populated,
# then writes to result.review.tmp, then Move-Item.
# Build a fresh ordered dict (OrderedDictionary has no Clone); origDoc stays untouched.
$newDoc = [ordered]@{
    runAt  = $origDoc.runAt
    stats  = $origDoc.stats
    items  = $origDoc.items
    review = [ordered]@{
        performed = $true
        items = @([ordered]@{
            repo = 'microsoft/vscode'
            sources = @('releases_api','html')
            finding = 'HTML 诊断请求失败。'
            conclusion = 'pending'
            reasons = @('not_found')
            apiListStatus = 'error'
            apiList = @()
            htmlStatus = 'error'
            htmlTitle = ''
        })
    }
}
# SKILL invariant: stats and items must remain unchanged
$newStats = $newDoc.stats | ConvertTo-Json -Depth 8 -Compress
$newItems = $newDoc.items | ConvertTo-Json -Depth 8 -Compress
$statsUnchanged = ($newStats -ceq $origStats)
$itemsUnchanged = ($newItems -ceq $origItems)
Log "Pre-write stats unchanged: $statsUnchanged"
Log "Pre-write items unchanged: $itemsUnchanged"

Set-Content -Path $tmpPath -Value ($newDoc | ConvertTo-Json -Depth 8) -Encoding UTF8
Log "Wrote result.review.tmp (review.performed=true)"

# Attempt Move-Item (should fail)
$moveError = $null
$moveSucceeded = $false
try {
    Move-Item -Path $tmpPath -Destination $resultPath -Force
    $moveSucceeded = $true
} catch {
    $moveError = $_.Exception.Message
}

# Apply SKILL's catch-block cleanup
Remove-Item $tmpPath -Force -ErrorAction SilentlyContinue

# Emit SKILL's canonical error message
if ($moveSucceeded) {
    $skillOutput = 'REVIEW_WRITE_OK|unexpected'
    Log "UNEXPECTED: Move-Item succeeded while destination was locked"
} else {
    $skillOutput = ('REVIEW_WRITE_ERROR|review 原子替换失败：{0}' -f $moveError)
    Log "Caught Move-Item error: $moveError"
}
Log "SKILL output: $skillOutput"

# ---- Release lock ---------------------------------------------------------
$fs.Close()
Log "Released lock on result.json"

# ---- Verify ---------------------------------------------------------------
$shaAfter = (Get-FileHash $resultPath -Algorithm SHA256).Hash
Log "result.json SHA256 (after):  $shaAfter"

$shaUnchanged = ($shaBefore -ceq $shaAfter)
Log "SHA256 unchanged: $shaUnchanged"

# Verify result.json is still valid JSON and stats/items/review preserved
$jsonValid = $false
$statsStillUnchanged = $false
$itemsStillUnchanged = $false
$reviewStillNotPerformed = $false
try {
    $parsed = Get-Content $resultPath -Raw | ConvertFrom-Json
    $jsonValid = ($null -ne $parsed) -and ($null -ne $parsed.stats) -and ($null -ne $parsed.items) -and ($null -ne $parsed.review)
    if ($jsonValid) {
        $statsStillUnchanged   = ($parsed.stats | ConvertTo-Json -Depth 8 -Compress) -ceq $origStats
        $itemsStillUnchanged   = ($parsed.items | ConvertTo-Json -Depth 8 -Compress) -ceq $origItems
        $reviewStillNotPerformed = ($parsed.review.performed -eq $false)
    }
} catch {
    Log "JSON parse error: $($_.Exception.Message)"
}
Log "result.json still valid JSON: $jsonValid"
Log "stats still unchanged: $statsStillUnchanged"
Log "items still unchanged: $itemsStillUnchanged"
Log "review.performed still false (not overwritten): $reviewStillNotPerformed"

$tmpExists = Test-Path $tmpPath
Log "result.review.tmp still exists: $tmpExists (expected: False)"

$startsReviewErr = $skillOutput -clike 'REVIEW_WRITE_ERROR*'
Log "Output starts with REVIEW_WRITE_ERROR: $startsReviewErr"

# ---- Verdict --------------------------------------------------------------
$pass = $shaUnchanged -and $jsonValid -and $statsStillUnchanged -and $itemsStillUnchanged -and $reviewStillNotPerformed -and (-not $tmpExists) -and $startsReviewErr -and (-not $moveSucceeded)
$verdict = if ($pass) { 'PASS' } else { 'FAIL' }
Log ""
Log "Verdict: $verdict"

# ---- Save stdout.txt ------------------------------------------------------
$stdoutPath = Join-Path $testDir 'stdout.txt'
Set-Content -Path $stdoutPath -Value (($stdout -join "`r`n") + "`r`n") -Encoding UTF8

# ---- Save test-report.md --------------------------------------------------
$moveFailedStr = (-not $moveSucceeded).ToString()
$shaUnchangedStr = $shaUnchanged.ToString()
$jsonValidStr = $jsonValid.ToString()
$statsUnchangedStr = $statsStillUnchanged.ToString()
$itemsUnchangedStr = $itemsStillUnchanged.ToString()
$reviewPreservedStr = $reviewStillNotPerformed.ToString()
$tmpCleanedStr = (-not $tmpExists).ToString()
$startsReviewErrStr = $startsReviewErr.ToString()
$genTime = Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz'

$report = @"
# Test Report: T21 - review atomicity

**Generated:** $genTime
**Script:** test.ps1

## Description

Test that when the atomic move Move-Item result.review.tmp -> result.json fails
(because result.json is locked with FileShare::None), the old result.json is NOT
corrupted: stats, items, and review.performed are all preserved. This validates
SKILL-v1.7.md Step 4 (line 479):

```powershell
try { Move-Item $tmpPath $resultPath -Force }
catch {
    Remove-Item $tmpPath -Force -ErrorAction SilentlyContinue
    Write-Output ('REVIEW_WRITE_ERROR|review 原子替换失败：{0}' -f $_.Exception.Message)
    Release-LockSafely
    return
}
```

## Test Method

1. Create a valid result.json with a review=true item and review.performed=false.
2. Compute SHA256 of result.json before the test.
3. Open result.json with an exclusive lock (FileShare::None).
4. Build a new doc with review.performed=true (simulating Step 4 output).
5. Write new doc to result.review.tmp.
6. Attempt Move-Item -Force (expected to fail with sharing violation).
7. Apply SKILL's catch-block cleanup (Remove-Item $tmpPath -Force -SilentlyContinue).
8. Close the file handle.
9. Compute SHA256 of result.json after the test.
10. Verify SHA256 is unchanged; stats/items/review.performed all preserved.

## Expected Result

| Check | Expected |
|-------|----------|
| Move-Item fails | True |
| SHA256 unchanged | True |
| result.json still valid JSON | True |
| stats still unchanged | True |
| items still unchanged | True |
| review.performed still false (not overwritten) | True |
| result.review.tmp cleaned up | True |
| Output starts with REVIEW_WRITE_ERROR | True |

## Actual Result

| Check | Actual |
|-------|--------|
| Move-Item failed | $moveFailedStr |
| Move-Item error message | $moveError |
| SHA256 before | $shaBefore |
| SHA256 after | $shaAfter |
| SHA256 unchanged | $shaUnchangedStr |
| result.json still valid JSON | $jsonValidStr |
| stats still unchanged | $statsUnchangedStr |
| items still unchanged | $itemsUnchangedStr |
| review.performed still false | $reviewPreservedStr |
| result.review.tmp cleaned up | $tmpCleanedStr |
| SKILL output | $skillOutput |
| Output starts with REVIEW_WRITE_ERROR | $startsReviewErrStr |

## Verdict

**$verdict**

## Evidence

- result.json SHA256 before: $shaBefore
- result.json SHA256 after: $shaAfter
- Move-Item exception message: $moveError
- SKILL error output: $skillOutput
- stats JSON preserved: $statsUnchangedStr
- items JSON preserved: $itemsUnchangedStr
- review.performed preserved (still false): $reviewPreservedStr
"@

$reportPath = Join-Path $testDir 'test-report.md'
Set-Content -Path $reportPath -Value $report -Encoding UTF8

Write-Host ""
Write-Host "stdout.txt: $stdoutPath"
Write-Host "test-report.md: $reportPath"
