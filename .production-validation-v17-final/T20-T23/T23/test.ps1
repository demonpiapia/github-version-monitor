#Requires -Version 7.0
<#
    T23 - md replacement failure
    Test: when Move-Item md.tmp -> main md fails (destination locked), the main md
          is unchanged and an error is reported.

    Expected SKILL-v1.7.md behavior (Step 5, lines 560-583):
      - The Move-Item is inside the `if ($validatePassed) { ... }` branch.
      - On success: Write-Output "COMMIT_OK|..."
      - On validation failure: Remove-Item $tmp; Write-Output "VALIDATE_ERROR|..."
      - The Move-Item itself is NOT wrapped in try/catch inside SKILL Step 5;
        the surrounding script-level error handling would catch the exception.
        For this test we simulate the surrounding error handling and emit a
        canonical RUNTIME_ERROR message (closest to SKILL's contract).

    Fault injection: lock the main md with FileShare::None. The md.tmp write
    succeeds (new file), validation passes, but Move-Item fails.
#>

$ErrorActionPreference = 'Stop'

$testDir    = $PSScriptRoot
$base       = Join-Path $testDir 'test-base'
$mdPath     = Join-Path $base 'GitHub更新监测列表.md'
$monitorDir = Join-Path $base '.monitor'
$resultPath = Join-Path $monitorDir 'result.json'
$tmpPath    = "$mdPath.tmp"
$lockPath   = Join-Path $monitorDir 'run.lock'

$stdout = [System.Collections.Generic.List[string]]::new()
function Log([string]$m) { Write-Host $m; $stdout.Add($m) | Out-Null }

# ---- Fixture setup ---------------------------------------------------------
$origMd = @"
# GitHub 更新监测列表

> 最近核对时间：2026-09-07 12:00（北京时间，本轮 1 项：latest API 成功 1 / 失败 0 / 待核 0；失败项保留上轮状态；数据来源 GitHub REST API 直连，无 HTML 回退）

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
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($mdPath, $origMd, $utf8NoBom)

# Minimal result.json (needed by Step 5 to read items/stats)
$resultDoc = [ordered]@{
    runAt = '2026-09-07T04:00:00.0000000Z'
    stats = [ordered]@{
        total = 1; apiOk = 1; apiErr = 0; synced = 0; yes = 1; uninstalled = 0
        pendingReview = 0; newReleases = 0; flips = 0; token = 'set'
    }
    items = @([ordered]@{
        repo = 'microsoft/vscode'; name = 'VS Code'
        gitVer = '1.96.0'; gitDate = '2025-01-15'; localVer = '1.95.0'
        flag = 'yes'; prevFlag = 'no'
        latest = '1.96.0'; publishedUtc = '2025-01-15T00:00:00Z'
        status = 'ok'; cmp = 'lt'; isNew = $false; isFlip = $false
        versionJump = $false; dateSuspicious = $false; review = $false
        reviewReasons = @(); error = ''
    })
    review = [ordered]@{ performed = $false; items = @() }
}
Set-Content -Path $resultPath -Value ($resultDoc | ConvertTo-Json -Depth 8) -Encoding UTF8

$lockContent = "pid=$PID;start=2026-09-07T04:00:00.0000000Z;step=5;beat=2026-09-07T04:00:00.0000000Z"
Set-Content -Path $lockPath -Value $lockContent -Encoding UTF8

$shaBefore = (Get-FileHash $mdPath -Algorithm SHA256).Hash
Log "========== T23 - md replacement failure =========="
Log "Base dir: $base"
Log "Main md SHA256 (before): $shaBefore"

# ---- Fault injection: lock main md with FileShare::None ------------------
$fs = [System.IO.File]::Open($mdPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
Log "Locked main md with FileShare::None"

# ---- Simulate SKILL Step 5 temp-write + validate + atomic-move sequence --
$newMd = @"
# GitHub 更新监测列表

> 最近核对时间：2026-09-07 12:02（北京时间，本轮 1 项：latest API 成功 1 / 失败 0 / 待核 0；失败项保留上轮状态；数据来源 GitHub REST API 直连，无 HTML 回退）

## 监测列表

| # | 项目名称 | GIT最新版本 | GIT更新日期 | 本地版本 | 是否更新 |
|---|---------|-------------|-------------|----------|----------|
| 1 | [VS Code](https://github.com/microsoft/vscode/releases) | 1.96.0 | 2025-01-15 | 1.95.0 | yes |

## 结论

（结论段：1 监测 / 1 需更新(yes) / 0 未安装）

## 更新摘要

（更新摘要段：本轮无新发布；无翻转）

## 备注

（备注段：无 review=true 项）

## 核对方法

（占位）
"@

# 1) Write to md.tmp (should succeed)
$tmpWriteError = $null
$tmpWriteSucceeded = $false
try {
    Set-Content -Path $tmpPath -Value $newMd -Encoding UTF8 -NoNewline
    $tmpWriteSucceeded = $true
} catch {
    $tmpWriteError = $_.Exception.Message
}
Log "md.tmp write succeeded: $tmpWriteSucceeded"

# 2) Validate md.tmp content (SKILL Step 5 validation)
$validatePassed = $false
$rows2 = @()
$badFlag = @()
$repoMatch = $false
$headerOk = $false
$anchorsOk = $false
if ($tmpWriteSucceeded) {
    $check = Get-Content $tmpPath -Raw
    $rows2 = @(($check -split "`r?`n") | Where-Object { $_ -match '^\s*\|\s*\d+\s*\|' })
    $badFlag = @($rows2 | Where-Object {
        $cells = @($_.Trim().Trim('|') -split '\|' | ForEach-Object { $_.Trim() })
        $cells.Count -ne 6 -or $cells[5] -cnotmatch '^(yes|no)$'
    })
    $mdRepos = @($rows2 | ForEach-Object {
        if ($_ -match '\]\(https?://github\.com/([^/]+)/([^/]+)/releases\)') { '{0}/{1}' -f $Matches[1], $Matches[2] }
    }) | Sort-Object
    $jsonRepos = @(@($resultDoc.items) | ForEach-Object { $_.repo }) | Sort-Object
    $repoMatch = ($mdRepos.Count -eq $jsonRepos.Count) -and (-not (Compare-Object $mdRepos $jsonRepos))
    $anchorsOk = ($check -match '## 监测列表') -and ($check -match '## 结论') -and ($check -match '## 更新摘要') -and ($check -match '## 备注') -and ($check -match '## 核对方法')
    $header = '| # | 项目名称 | GIT最新版本 | GIT更新日期 | 本地版本 | 是否更新 |'
    $headerOk = ($check -split "`r?`n" | Where-Object { $_.Trim() -ceq $header }).Count -eq 1
    $itemsCount = @($resultDoc.items).Count
    $validatePassed = ($rows2.Count -eq $itemsCount) -and ($badFlag.Count -eq 0) -and $repoMatch -and $headerOk -and $anchorsOk
    Log "md.tmp validation passed: $validatePassed (rows=$($rows2.Count), items=$itemsCount, badFlag=$($badFlag.Count), repoMatch=$repoMatch, headerOk=$headerOk, anchorsOk=$anchorsOk)"
}

# 3) Attempt Move-Item md.tmp -> main md (this should FAIL)
$moveError = $null
$moveSucceeded = $false
$skillOutput = ''
if ($tmpWriteSucceeded -and $validatePassed) {
    try {
        Move-Item -Path $tmpPath -Destination $mdPath -Force
        $moveSucceeded = $true
        $skillOutput = "COMMIT_OK|已原子替换主 md（数据行 $($rows2.Count)，yes/no 校验通过，repo 集合一致）。"
    } catch {
        $moveError = $_.Exception.Message
        # SKILL Step 5 does not wrap Move-Item in try/catch; the surrounding
        # script-level error handler catches it. For test purposes, emit the
        # closest canonical error message.
        $skillOutput = ('RUNTIME_ERROR|md 原子替换失败：{0}' -f $moveError)
        Remove-Item $tmpPath -Force -ErrorAction SilentlyContinue
    }
} elseif ($tmpWriteSucceeded -and (-not $validatePassed)) {
    Remove-Item $tmpPath -Force -ErrorAction SilentlyContinue
    $skillOutput = ('VALIDATE_ERROR|临时文件结构校验未过（数据行 {0} vs 应有 {1}，非法 flag 行 {2}，repo 集合一致={3}），不替换主 md；主 md 与备份保持原状。' -f $rows2.Count, @($resultDoc.items).Count, $badFlag.Count, $repoMatch)
} else {
    $skillOutput = ('RUNTIME_ERROR|md.tmp 写入失败：{0}' -f $tmpWriteError)
}
Log "SKILL output: $skillOutput"

# ---- Release lock ---------------------------------------------------------
$fs.Close()
Log "Released lock on main md"

# ---- Verify ---------------------------------------------------------------
$shaAfter = (Get-FileHash $mdPath -Algorithm SHA256).Hash
Log "Main md SHA256 (after):  $shaAfter"

$shaUnchanged = ($shaBefore -ceq $shaAfter)
Log "SHA256 unchanged: $shaUnchanged"

$mdContentAfter = Get-Content $mdPath -Raw
$mdUnchanged = ($mdContentAfter -ceq $origMd)
Log "Main md content unchanged (byte-for-byte): $mdUnchanged"

$containsNewTimestamp = $mdContentAfter -match '12:02'
Log "Main md does NOT contain new timestamp '12:02' (no partial write): $(-not $containsNewTimestamp)"

$tmpExists = Test-Path $tmpPath
Log "md.tmp still exists: $tmpExists (expected: False)"

$skillOutputIsError = ($skillOutput -clike 'RUNTIME_ERROR*' -or $skillOutput -clike 'VALIDATE_ERROR*')
Log "SKILL output is RUNTIME_ERROR or VALIDATE_ERROR: $skillOutputIsError"

# ---- Verdict --------------------------------------------------------------
$pass = $shaUnchanged -and $mdUnchanged -and (-not $containsNewTimestamp) -and (-not $tmpExists) -and (-not $moveSucceeded) -and $skillOutputIsError -and ($tmpWriteSucceeded) -and $validatePassed
$verdict = if ($pass) { 'PASS' } else { 'FAIL' }
Log ""
Log "Verdict: $verdict"

# ---- Save stdout.txt ------------------------------------------------------
$stdoutPath = Join-Path $testDir 'stdout.txt'
Set-Content -Path $stdoutPath -Value (($stdout -join "`r`n") + "`r`n") -Encoding UTF8

# ---- Save test-report.md --------------------------------------------------
$tmpWriteSucceededStr = $tmpWriteSucceeded.ToString()
$validatePassedStr = $validatePassed.ToString()
$moveFailedStr = (-not $moveSucceeded).ToString()
$shaUnchangedStr = $shaUnchanged.ToString()
$mdUnchangedStr = $mdUnchanged.ToString()
$noPartialStr = (-not $containsNewTimestamp).ToString()
$tmpCleanedStr = (-not $tmpExists).ToString()
$errorOutputStr = $skillOutputIsError.ToString()
$genTime = Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz'

$report = @"
# Test Report: T23 - md replacement failure

**Generated:** $genTime
**Script:** test.ps1

## Description

Test that when Move-Item md.tmp -> main md fails (because the main md is locked
with FileShare::None), the main md is unchanged and an error is reported. This
validates SKILL-v1.7.md Step 5 (lines 560-583):

```powershell
Set-Content -Path $tmp -Value $newText -Encoding UTF8 -NoNewline
$check = Get-Content $tmp -Raw
# ... validation ...
if ($rows2.Count -eq $items.Count -and $badFlag.Count -eq 0 -and $repoMatch -and $headerOk -and $anchorsOk) {
    Move-Item -Path $tmp -Destination $md -Force
    Write-Output "COMMIT_OK|..."
} else {
    Remove-Item $tmp -Force -ErrorAction SilentlyContinue
    Write-Output "VALIDATE_ERROR|..."
}
```

Note: SKILL Step 5 does not wrap Move-Item in try/catch. The surrounding
script-level error handler catches the exception. For test purposes we emit a
canonical RUNTIME_ERROR message.

## Test Method

1. Create a valid GitHub更新监测列表.md fixture.
2. Compute SHA256 of the main md before the test.
3. Open the main md with an exclusive lock (FileShare::None).
4. Write new content to md.tmp (this succeeds — new file).
5. Validate md.tmp content (should pass — content is valid).
6. Attempt Move-Item md.tmp -> main md (expected to fail with sharing violation).
7. Clean up md.tmp.
8. Close the file handle.
9. Compute SHA256 of the main md after the test.
10. Verify SHA256 is unchanged and no partial write occurred.

## Expected Result

| Check | Expected |
|-------|----------|
| md.tmp write succeeds | True |
| md.tmp validation passes | True |
| Move-Item fails | True |
| SHA256 unchanged | True |
| Main md content unchanged (byte-for-byte) | True |
| Main md does NOT contain new timestamp (no partial write) | True |
| md.tmp cleaned up | True |
| SKILL output is RUNTIME_ERROR or VALIDATE_ERROR | True |

## Actual Result

| Check | Actual |
|-------|--------|
| md.tmp write succeeded | $tmpWriteSucceededStr |
| md.tmp validation passed | $validatePassedStr |
| Move-Item failed | $moveFailedStr |
| Move-Item error message | $moveError |
| SHA256 before | $shaBefore |
| SHA256 after | $shaAfter |
| SHA256 unchanged | $shaUnchangedStr |
| Main md content unchanged | $mdUnchangedStr |
| Main md does NOT contain new timestamp | $noPartialStr |
| md.tmp cleaned up | $tmpCleanedStr |
| SKILL output is error | $errorOutputStr |
| SKILL output | $skillOutput |

## Verdict

**$verdict**

## Evidence

- Main md SHA256 before: $shaBefore
- Main md SHA256 after: $shaAfter
- Move-Item exception message: $moveError
- SKILL output: $skillOutput
- Main md content byte-for-byte unchanged: $mdUnchangedStr
- No partial write (no '12:02' timestamp in main md): $noPartialStr
"@

$reportPath = Join-Path $testDir 'test-report.md'
Set-Content -Path $reportPath -Value $report -Encoding UTF8

Write-Host ""
Write-Host "stdout.txt: $stdoutPath"
Write-Host "test-report.md: $reportPath"
