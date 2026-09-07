# T43 - Full Extended Pipeline
# 6 rows covering all scenarios:
# 1. Normal upgrade: microsoft/vscode, localVer=1.0.0
# 2. Synced: microsoft/vscode with localVer=1.136.1 (from previous tests, we know this is latest)
#    -- BUT can't use same repo twice! Use facebook/react for normal upgrade instead
# 3. Uninstalled: golang/go, localVer=未安装
# 4. Unsupported version: python/cpython, localVer="some-weird-string"
# 5. 404: octocat/this-does-not-exist-99999
# 6. versionJump: nodejs/node, gitVer=1.0.0, localVer=1.0.0

$ErrorActionPreference = 'Continue'
$baseDir = 'd:\AI\Workspace\automatic\github-version-monitor\.production-validation-v17-final\T37-T43'
$testDir = Join-Path $baseDir 'T43'
$libDir = Join-Path $baseDir 'lib'
$mdPath = Join-Path $testDir 'GitHub更新监测列表.md'
$monitorDir = Join-Path $testDir '.monitor'

# Clean any previous test artifacts
if (Test-Path (Join-Path $testDir '.monitor')) { Remove-Item (Join-Path $testDir '.monitor') -Recurse -Force }
if (Test-Path $mdPath) { Remove-Item $mdPath -Force }

# Build fixture with 6 rows
# Row 1: Normal upgrade - facebook/react, localVer=1.0.0
# Row 2: Synced - microsoft/vscode, localVer=1.136.1 (known latest from prior tests)
# Row 3: Uninstalled - golang/go, localVer=未安装
# Row 4: Unsupported version - python/cpython, localVer=some-weird-string
# Row 5: 404 - octocat/this-does-not-exist-99999, localVer=1.0.0
# Row 6: versionJump - nodejs/node, gitVer=1.0.0, gitDate=2024-01-01, localVer=1.0.0

$lines = @()
$lines += '> 最近核对时间：2026-09-01 00:00（北京时间，初始状态）'
$lines += ''
$lines += '## 监测列表'
$lines += ''
$lines += '| # | 项目名称 | GIT最新版本 | GIT更新日期 | 本地版本 | 是否更新 |'
$lines += '|---|---|---|---|---|---|'
$lines += '| 1 | [React](https://github.com/facebook/react/releases) | | | 1.0.0 | no |'
$lines += '| 2 | [VSCode](https://github.com/microsoft/vscode/releases) | | | 1.136.1 | no |'
$lines += '| 3 | [Go](https://github.com/golang/go/releases) | | | 未安装 | no |'
$lines += '| 4 | [CPython](https://github.com/python/cpython/releases) | | | some-weird-string | no |'
$lines += '| 5 | [NotFound](https://github.com/octocat/this-does-not-exist-99999/releases) | | | 1.0.0 | no |'
$lines += '| 6 | [Node.js](https://github.com/nodejs/node/releases) | 1.0.0 | 2024-01-01 | 1.0.0 | no |'
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

# Ensure token is set
$env:GITHUB_VERSION_MONITOR_BASE = $testDir

$allOutput = @()

# Run the full pipeline
$allOutput += "===== Running full pipeline (Steps 1-5) ====="
$pipeOut = & pwsh -NoProfile -File (Join-Path $libDir 'run-full-pipeline.ps1') -TestDir $testDir -LibDir $libDir 2>&1
$allOutput += $pipeOut
$allOutput += "===== Pipeline complete ====="

# Save outputs
$stdoutText = $allOutput | Out-String
$stdoutText | Set-Content -Path (Join-Path $testDir 'stdout.txt') -Encoding UTF8
'' | Set-Content -Path (Join-Path $testDir 'stderr.txt') -Encoding UTF8

# Verify results
$results = @()
$results += "## T43 - Full Extended Pipeline"
$results += ""
$results += "### Fixture (6 rows)"
$results += "1. facebook/react, localVer=1.0.0 (normal upgrade)"
$results += "2. microsoft/vscode, localVer=1.136.1 (synced)"
$results += "3. golang/go, localVer=未安装 (uninstalled)"
$results += "4. python/cpython, localVer=some-weird-string (incomparable)"
$results += "5. octocat/this-does-not-exist-99999 (404)"
$results += "6. nodejs/node, gitVer=1.0.0, localVer=1.0.0 (versionJump)"
$results += ""

$combined = $stdoutText

# Check key markers
$hasBackupOk = $combined -match 'BACKUP_OK\|'
$hasFetchComplete = $combined -match 'FETCH_COMPLETE\|'
$hasSummary = $combined -match 'SUMMARY\|'
$hasReviewWriteOk = $combined -match 'REVIEW_WRITE_OK\|'
$hasCommitOk = $combined -match 'COMMIT_OK\|'
$hasRunSuccess = $combined -match 'RUN_STATUS\|success\|'

$results += "### Pipeline Markers"
$results += "- BACKUP_OK: $hasBackupOk"
$results += "- FETCH_COMPLETE: $hasFetchComplete"
$results += "- SUMMARY: $hasSummary"
$results += "- REVIEW_WRITE_OK: $hasReviewWriteOk"
$results += "- COMMIT_OK: $hasCommitOk"
$results += "- RUN_STATUS|success|: $hasRunSuccess"

# Check result.json
$resultJsonPath = Join-Path $monitorDir 'result.json'
$resultValid = $false
$items = $null
$stats = $null
if (Test-Path $resultJsonPath) {
    try {
        $rj = Get-Content $resultJsonPath -Raw | ConvertFrom-Json
        $items = $rj.items
        $stats = $rj.stats
        $resultValid = ($null -ne $rj -and $null -ne $rj.stats -and $null -ne $rj.items)
    } catch { $resultValid = $false }
}
$results += "- result.json valid: $resultValid"

if ($resultValid) {
    $results += ""
    $results += "### Item Details"
    foreach ($it in $items) {
        $results += "- $($it.repo): status=$($it.status), flag=$($it.flag), cmp=$($it.cmp), review=$($it.review), isNew=$($it.isNew), isFlip=$($it.isFlip), versionJump=$($it.versionJump)"
        if ($it.reviewReasons.Count -gt 0) {
            $results += "  reasons: $($it.reviewReasons -join ', ')"
        }
    }
    
    $results += ""
    $results += "### Stats"
    $results += "- total=$($stats.total) apiOk=$($stats.apiOk) apiErr=$($stats.apiErr) synced=$($stats.synced) yes=$($stats.yes) uninstalled=$($stats.uninstalled) pendingReview=$($stats.pendingReview) newReleases=$($stats.newReleases) flips=$($stats.flips) token=$($stats.token)"
    
    # Verify specific row expectations
    $results += ""
    $results += "### Row Verification"
    
    # Row 1: facebook/react - normal upgrade
    $r1 = $items | Where-Object { $_.repo -eq 'facebook/react' }
    if ($r1) {
        $r1Ok = ($r1.status -eq 'ok' -and $r1.flag -eq 'yes' -and $r1.cmp -eq 'lt')
        $results += "- Row 1 (facebook/react, normal upgrade): status=$($r1.status), flag=$($r1.flag), cmp=$($r1.cmp) -> $(if ($r1Ok) {'OK'} else {'MISMATCH'})"
    }
    
    # Row 2: microsoft/vscode - synced
    $r2 = $items | Where-Object { $_.repo -eq 'microsoft/vscode' }
    if ($r2) {
        $r2Ok = ($r2.status -eq 'ok' -and $r2.flag -eq 'no' -and $r2.cmp -eq 'eq')
        $results += "- Row 2 (microsoft/vscode, synced): status=$($r2.status), flag=$($r2.flag), cmp=$($r2.cmp) -> $(if ($r2Ok) {'OK'} else {'MISMATCH'})"
    }
    
    # Row 3: golang/go - uninstalled
    $r3 = $items | Where-Object { $_.repo -eq 'golang/go' }
    if ($r3) {
        $r3Ok = ($r3.status -eq 'ok' -and $r3.flag -eq 'no' -and $r3.localVer -match '未安装')
        $results += "- Row 3 (golang/go, uninstalled): status=$($r3.status), flag=$($r3.flag) -> $(if ($r3Ok) {'OK'} else {'MISMATCH'})"
    }
    
    # Row 4: python/cpython - incomparable
    $r4 = $items | Where-Object { $_.repo -eq 'python/cpython' }
    if ($r4) {
        $r4Ok = ($r4.status -eq 'ok' -and $r4.cmp -eq 'incomparable' -and $r4.review -eq $true)
        $results += "- Row 4 (python/cpython, incomparable): status=$($r4.status), cmp=$($r4.cmp), review=$($r4.review) -> $(if ($r4Ok) {'OK'} else {'MISMATCH'})"
    }
    
    # Row 5: 404
    $r5 = $items | Where-Object { $_.repo -eq 'octocat/this-does-not-exist-99999' }
    if ($r5) {
        $r5Ok = ($r5.status -eq 'not_found' -and $r5.gitVer -eq '' -and $r5.review -eq $true)
        $results += "- Row 5 (404): status=$($r5.status), gitVer='$($r5.gitVer)', review=$($r5.review) -> $(if ($r5Ok) {'OK'} else {'MISMATCH'})"
    }
    
    # Row 6: versionJump
    $r6 = $items | Where-Object { $_.repo -eq 'nodejs/node' }
    if ($r6) {
        $r6Ok = ($r6.status -eq 'ok' -and $r6.versionJump -eq $true -and $r6.review -eq $true)
        $results += "- Row 6 (nodejs/node, versionJump): status=$($r6.status), versionJump=$($r6.versionJump), review=$($r6.review) -> $(if ($r6Ok) {'OK'} else {'MISMATCH'})"
    }
}

# Data consistency checks
$results += ""
$results += "### Data Consistency"

# Check main md was updated
$updatedSha = (Get-FileHash $mdPath -Algorithm SHA256).Hash
$mdChanged = ($updatedSha -ne $originalSha)
$results += "- Main md changed from original: $mdChanged"

# Check backup md exists
$backupDir = Join-Path $monitorDir 'backups'
$backups = Get-ChildItem $backupDir -Filter 'GitHub更新监测列表.backup.*.md' -ErrorAction SilentlyContinue
$hasBackup = ($backups.Count -gt 0)
$results += "- Backup md exists: $hasBackup"

# Check backup content matches original fixture
if ($hasBackup) {
    $backupContent = Get-Content $backups[0].FullName -Raw
    $backupSha = (Get-FileHash $backups[0].FullName -Algorithm SHA256).Hash
    $backupMatchesOriginal = ($backupSha -eq $originalSha)
    $results += "- Backup md matches original fixture: $backupMatchesOriginal"
}

# Check fetch_run.log exists
$logPath = Join-Path $monitorDir 'fetch_run.log'
$hasLog = Test-Path $logPath
$results += "- fetch_run.log exists: $hasLog"

# Check lock released
$lockPath = Join-Path $monitorDir 'run.lock'
$lockReleased = -not (Test-Path $lockPath)
$results += "- Lock released: $lockReleased"

# Cross-check: result.json items match main md rows
if ($resultValid) {
    $updatedMd = Get-Content $mdPath -Raw
    $mdRows = @($updatedMd -split "`r?`n" | Where-Object { $_ -match '^\s*\|\s*\d+\s*\|' })
    $results += "- Main md data rows count: $($mdRows.Count) (expected 6)"
    
    # Check that each result.json item's gitVer appears in the md
    $allGitVersInMd = $true
    foreach ($it in $items) {
        if ($it.gitVer -and $it.gitVer -ne '') {
            if ($updatedMd -notmatch [regex]::Escape($it.gitVer)) {
                $allGitVersInMd = $false
                $results += "  WARNING: gitVer '$($it.gitVer)' for $($it.repo) not found in md"
            }
        }
    }
    $results += "- All non-empty gitVers from result.json appear in md: $allGitVersInMd"
}

# Overall
$allPass = $hasBackupOk -and $hasFetchComplete -and $hasSummary -and $hasCommitOk -and $hasRunSuccess -and $resultValid -and $mdChanged -and $hasBackup -and $hasLog -and $lockReleased
$results += ""
$results += "### Result: $(if ($allPass) {'**PASS**'} else {'**FAIL**'})"

# Save test report
$results | Set-Content -Path (Join-Path $testDir 'test-report.md') -Encoding UTF8

# Output results
$results | ForEach-Object { Write-Output $_ }
Write-Output ""
Write-Output "=== STDOUT ==="
Write-Output $stdoutText
