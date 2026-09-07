#Requires -Version 7.0
<#
    T20 - result.json atomicity
    Test: when Move-Item result.fetch.tmp -> result.json fails (destination locked),
          the old result.json is NOT corrupted.

    Expected SKILL-v1.7.md behavior (Step 2, lines 407-412):
      try { Move-Item -Path $tmpResult -Destination $resultPath -Force }
      catch {
          Remove-Item $tmpResult -Force -ErrorAction SilentlyContinue
          Write-Output ('RUNTIME_ERROR|result.json 原子替换失败：{0}' -f $_.Exception.Message)
          Release-LockSafely
          return
      }

    Fault injection: lock result.json with FileShare::None before attempting Move-Item.
    This causes Move-Item to throw (sharing violation), which the SKILL catch block
    converts to RUNTIME_ERROR output.
#>

$ErrorActionPreference = 'Stop'

$testDir = $PSScriptRoot
$base    = Join-Path $testDir 'test-base'
$mdPath  = Join-Path $base 'GitHub更新监测列表.md'
$monitorDir = Join-Path $base '.monitor'
$resultPath = Join-Path $monitorDir 'result.json'
$tmpPath    = Join-Path $monitorDir 'result.fetch.tmp'
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

$lockContent = "pid=$PID;start=2026-09-07T04:00:00.0000000Z;step=2;beat=2026-09-07T04:00:00.0000000Z"
Set-Content -Path $lockPath -Value $lockContent -Encoding UTF8

# Original result.json - a valid, known JSON document
$origDoc = [ordered]@{
    runAt = '2026-09-07T04:00:00.0000000Z'
    stats = [ordered]@{
        total = 1; apiOk = 1; apiErr = 0; synced = 0; yes = 1; uninstalled = 0
        pendingReview = 0; newReleases = 1; flips = 0; token = 'set'
    }
    items = @([ordered]@{
        repo = 'microsoft/vscode'; name = 'VS Code'
        gitVer = '1.96.0'; gitDate = '2025-01-15'; localVer = '1.95.0'
        flag = 'yes'; prevFlag = 'no'
        latest = '1.96.0'; publishedUtc = '2025-01-15T00:00:00Z'
        status = 'ok'; cmp = 'lt'; isNew = $true; isFlip = $true
        versionJump = $false; dateSuspicious = $false; review = $false
        reviewReasons = @(); error = ''
    })
    review = [ordered]@{ performed = $false; items = @() }
}
$origJson = $origDoc | ConvertTo-Json -Depth 8
Set-Content -Path $resultPath -Value $origJson -Encoding UTF8

# ---- Compute SHA256 before -------------------------------------------------
$shaBefore = (Get-FileHash $resultPath -Algorithm SHA256).Hash
Log "========== T20 - result.json atomicity =========="
Log "Base dir: $base"
Log "result.json SHA256 (before): $shaBefore"

# ---- Fault injection: lock result.json with FileShare::None ---------------
$fs = [System.IO.File]::Open($resultPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
Log "Locked result.json with FileShare::None"

# ---- Simulate the SKILL Step 2 atomic-write sequence ----------------------
# 1) Write new content to result.fetch.tmp (simulating Step 2's fetch output)
$newDoc = [ordered]@{
    runAt = '2026-09-07T04:01:00.0000000Z'
    stats = $origDoc.stats
    items = $origDoc.items
    review = [ordered]@{ performed = $false; items = @() }
}
$newJson = $newDoc | ConvertTo-Json -Depth 8
Set-Content -Path $tmpPath -Value $newJson -Encoding UTF8
Log "Wrote result.fetch.tmp (new fetch result)"

# 2) Attempt Move-Item (this should fail because result.json is locked)
$moveError = $null
$moveSucceeded = $false
try {
    Move-Item -Path $tmpPath -Destination $resultPath -Force
    $moveSucceeded = $true
} catch {
    $moveError = $_.Exception.Message
}

# 3) Apply SKILL's catch-block cleanup (Remove-Item $tmpResult -Force -SilentlyContinue)
Remove-Item $tmpPath -Force -ErrorAction SilentlyContinue

# ---- Emit SKILL's canonical error message ---------------------------------
if ($moveSucceeded) {
    Log "UNEXPECTED: Move-Item succeeded while destination was locked"
    $skillOutput = 'COMMIT_OK|unexpected'
} else {
    $skillOutput = ('RUNTIME_ERROR|result.json 原子替换失败：{0}' -f $moveError)
    Log "Caught Move-Item error: $moveError"
}
Log "SKILL output: $skillOutput"

# ---- Release the lock -----------------------------------------------------
$fs.Close()
Log "Released lock on result.json"

# ---- Verify ---------------------------------------------------------------
$shaAfter = (Get-FileHash $resultPath -Algorithm SHA256).Hash
Log "result.json SHA256 (after):  $shaAfter"

$shaUnchanged = ($shaBefore -ceq $shaAfter)
Log "SHA256 unchanged: $shaUnchanged"

# Verify result.json is still valid JSON
$jsonValid = $false
try {
    $parsed = Get-Content $resultPath -Raw | ConvertFrom-Json
    $jsonValid = ($null -ne $parsed) -and ($null -ne $parsed.stats) -and ($null -ne $parsed.items) -and ($null -ne $parsed.review)
} catch {
    $jsonValid = $false
    Log "JSON parse error: $($_.Exception.Message)"
}
Log "result.json still valid JSON: $jsonValid"

# Verify temp file was cleaned up (per SKILL catch block)
$tmpExists = Test-Path $tmpPath
Log "result.fetch.tmp still exists: $tmpExists (expected: False)"

# Verify output message
$startsRuntime = $skillOutput -clike 'RUNTIME_ERROR*'
Log "Output starts with RUNTIME_ERROR: $startsRuntime"

# ---- Verdict --------------------------------------------------------------
$pass = $shaUnchanged -and $jsonValid -and (-not $tmpExists) -and $startsRuntime -and (-not $moveSucceeded)
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
$tmpCleanedStr = (-not $tmpExists).ToString()
$startsRuntimeStr = $startsRuntime.ToString()
$genTime = Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz'

$report = @"
# Test Report: T20 - result.json atomicity

**Generated:** $genTime
**Script:** test.ps1

## Description

Test that when the atomic move Move-Item result.fetch.tmp -> result.json fails
(because result.json is locked with FileShare::None), the old result.json
is NOT corrupted. This validates SKILL-v1.7.md Step 2 lines 407-412:

```powershell
try { Move-Item -Path $tmpResult -Destination $resultPath -Force }
catch {
    Remove-Item $tmpResult -Force -ErrorAction SilentlyContinue
    Write-Output ('RUNTIME_ERROR|result.json 原子替换失败：{0}' -f $_.Exception.Message)
    Release-LockSafely
    return
}
```

## Test Method

1. Create a valid result.json fixture with known content.
2. Compute SHA256 of result.json before the test.
3. Open result.json with an exclusive lock (FileShare::None).
4. Write new content to result.fetch.tmp.
5. Attempt Move-Item -Force (expected to fail with sharing violation).
6. Apply SKILL's catch-block cleanup (Remove-Item $tmpResult -Force -SilentlyContinue).
7. Close the file handle.
8. Compute SHA256 of result.json after the test.
9. Verify SHA256 is unchanged and JSON is still valid.

## Expected Result

| Check | Expected |
|-------|----------|
| Move-Item fails | True |
| SHA256 unchanged | True |
| result.json still valid JSON | True |
| result.fetch.tmp cleaned up | True |
| Output starts with RUNTIME_ERROR | True |

## Actual Result

| Check | Actual |
|-------|--------|
| Move-Item failed | $moveFailedStr |
| Move-Item error message | $moveError |
| SHA256 before | $shaBefore |
| SHA256 after | $shaAfter |
| SHA256 unchanged | $shaUnchangedStr |
| result.json still valid JSON | $jsonValidStr |
| result.fetch.tmp cleaned up | $tmpCleanedStr |
| SKILL output | $skillOutput |
| Output starts with RUNTIME_ERROR | $startsRuntimeStr |

## Verdict

**$verdict**

## Evidence

- result.json SHA256 before: $shaBefore
- result.json SHA256 after: $shaAfter
- Move-Item exception message: $moveError
- SKILL error output: $skillOutput
"@

$reportPath = Join-Path $testDir 'test-report.md'
Set-Content -Path $reportPath -Value $report -Encoding UTF8

Write-Host ""
Write-Host "stdout.txt: $stdoutPath"
Write-Host "test-report.md: $reportPath"
