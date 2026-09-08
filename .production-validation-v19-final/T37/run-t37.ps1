$ErrorActionPreference = 'Continue'
$base = 'd:\AI\Workspace\automatic\github-version-monitor\.production-validation-v19-final\T37'
$lib  = 'd:\AI\Workspace\automatic\github-version-monitor\.production-validation-v19-final\lib'
$env:GITHUB_VERSION_MONITOR_BASE = $base

# Clean (only .output and .monitor subdirs, keep scripts)
if (Test-Path (Join-Path $base '.output'))  { Remove-Item (Join-Path $base '.output')  -Recurse -Force -ErrorAction SilentlyContinue }
if (Test-Path (Join-Path $base '.monitor')) { Remove-Item (Join-Path $base '.monitor') -Recurse -Force -ErrorAction SilentlyContinue }
foreach ($f in 'stdout.txt','stderr.txt','sha256-before.txt','sha256-after.txt','md-before.md','md-after.md','result-before.json','result-after.json','lock-before.txt','lock-after.txt','test-report.md','combined.ps1') {
    $p = Join-Path $base $f
    if (Test-Path $p) { Remove-Item $p -Force -ErrorAction SilentlyContinue }
}
foreach ($d in 'before','after') {
    $p = Join-Path $base $d
    if (Test-Path $p) { Remove-Item $p -Recurse -Force -ErrorAction SilentlyContinue }
}

New-Item -ItemType Directory -Force -Path $base | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $base '.output')  | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $base '.monitor') | Out-Null

# Fixture: 2 real repos (microsoft/vscode + torvalds/linux) — both should succeed, no review
& (Join-Path $lib 'create-fixture.ps1') -OutputPath (Join-Path $base '.output\GitHub更新监测列表.md') -Repos @(
    @{owner='microsoft'; repo='vscode'; name='vscode'},
    @{owner='torvalds';  repo='linux';  name='linux'}
) -LocalVer '1.0.0' -PrevFlag 'no' -PrevGitVer 'v1.80.0' -PrevGitDate '2023-08-01'

$md     = Join-Path $base '.output\GitHub更新监测列表.md'
$result = Join-Path $base '.monitor\result.json'
$lock   = Join-Path $base '.monitor\run.lock'

# Collect before state
Copy-Item $md (Join-Path $base 'md-before.md')
if (Test-Path $result) { Copy-Item $result (Join-Path $base 'result-before.json') } else { Set-Content -Path (Join-Path $base 'result-before.json') -Value '{}' }
if (Test-Path $lock)   { Copy-Item $lock   (Join-Path $base 'lock-before.txt') }  else { Set-Content -Path (Join-Path $base 'lock-before.txt') -Value 'no lock' }

New-Item -ItemType Directory -Force -Path (Join-Path $base 'before') | Out-Null
Copy-Item $md (Join-Path $base 'before\GitHub更新监测列表.md')

$shaMd     = (Get-FileHash $md -Algorithm SHA256).Hash
$shaResult = if (Test-Path $result) { (Get-FileHash $result -Algorithm SHA256).Hash } else { 'N/A' }
Set-Content -Path (Join-Path $base 'sha256-before.txt') -Value "main md: $shaMd`nresult.json: $shaResult"

# Execute full pipeline (Step 1 -> 5) via dot-source mode
# stdout-verification.txt confirmed run-full-pipeline.ps1 stdout pass-through works in -File mode
$proc = Start-Process -FilePath pwsh -ArgumentList "-NoProfile -NonInteractive -File `"$lib\run-full-pipeline.ps1`" -Base `"$base`"" -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $base 'stdout.txt') -RedirectStandardError (Join-Path $base 'stderr.txt')
$deadline = (Get-Date).AddSeconds(180)
while ((-not $proc.HasExited) -and ((Get-Date) -lt $deadline)) { Start-Sleep -Milliseconds 200 }
if (-not $proc.HasExited) { $proc.Kill() }

# Collect after state
Copy-Item $md (Join-Path $base 'md-after.md')
if (Test-Path $result) { Copy-Item $result (Join-Path $base 'result-after.json') } else { Set-Content -Path (Join-Path $base 'result-after.json') -Value '{}' }
if (Test-Path $lock)   { Copy-Item $lock   (Join-Path $base 'lock-after.txt') }   else { Set-Content -Path (Join-Path $base 'lock-after.txt') -Value 'lock released' }

New-Item -ItemType Directory -Force -Path (Join-Path $base 'after') | Out-Null
Copy-Item $md (Join-Path $base 'after\GitHub更新监测列表.md')
if (Test-Path $result) { Copy-Item $result (Join-Path $base 'after\result.json') }

$shaMd2     = (Get-FileHash $md -Algorithm SHA256).Hash
$shaResult2 = if (Test-Path $result) { (Get-FileHash $result -Algorithm SHA256).Hash } else { 'N/A' }
Set-Content -Path (Join-Path $base 'sha256-after.txt') -Value "main md: $shaMd2`nresult.json: $shaResult2"

# Verify
$stdout = Get-Content (Join-Path $base 'stdout.txt') -Raw -ErrorAction SilentlyContinue
if ($null -eq $stdout) { $stdout = '' }

$hasBackupOk      = $stdout -match 'BACKUP_OK\|'
$hasFetchComplete = $stdout -match 'FETCH_COMPLETE\|'
$hasSummary       = $stdout -match 'SUMMARY\|'
$hasReviewWriteOk = $stdout -match 'REVIEW_WRITE_OK\|'
$hasCommitOk      = $stdout -match 'COMMIT_OK\|'
$hasRunSuccess    = $stdout -match 'RUN_STATUS\|success\|'
$hasRunFailed     = $stdout -match 'RUN_STATUS\|failed\|'
$lockReleased     = (-not (Test-Path $lock))
$mdUpdated        = ($shaMd -ne $shaMd2)

$resultValid = $false
if (Test-Path $result) {
    try {
        $r = Get-Content $result -Raw | ConvertFrom-Json
        $resultValid = ($null -ne $r.stats) -and ($null -ne $r.items) -and ($null -ne $r.review)
    } catch { $resultValid = $false }
}

# Hard gate: COMMIT_OK + RUN_STATUS|failed| => FAIL (P1)
$hardFail = $hasCommitOk -and $hasRunFailed

$pass = $hasBackupOk -and $hasFetchComplete -and $hasSummary -and $hasCommitOk -and $hasRunSuccess -and $lockReleased -and $mdUpdated -and $resultValid -and (-not $hasRunFailed)

# Build report as array of lines (avoid here-string with backticks)
$lines = New-Object System.Collections.Generic.List[string]
$lines.Add('# T37-v19 Test Report: 正常提交 -> RUN_STATUS|success|')
$lines.Add('')
$lines.Add('## Fixture')
$lines.Add('2 个真实仓库：microsoft/vscode, torvalds/linux')
$lines.Add('')
$lines.Add('## 执行方式')
$lines.Add('run-full-pipeline.ps1 单次执行（dot-source 模式，stdout 透传正常，依据 lib/stdout-verification.txt）')
$lines.Add('')
$lines.Add('## 验证项')
$lines.Add('')
$lines.Add('| 检查项 | 期望 | 实际 | 结果 |')
$lines.Add('|---|---|---|---|')
$lines.Add('| BACKUP_OK\| | present | ' + $(if($hasBackupOk){'present'}else{'absent'}) + ' | ' + $(if($hasBackupOk){'PASS'}else{'FAIL'}) + ' |')
$lines.Add('| FETCH_COMPLETE\| | present | ' + $(if($hasFetchComplete){'present'}else{'absent'}) + ' | ' + $(if($hasFetchComplete){'PASS'}else{'FAIL'}) + ' |')
$lines.Add('| SUMMARY\| | present | ' + $(if($hasSummary){'present'}else{'absent'}) + ' | ' + $(if($hasSummary){'PASS'}else{'FAIL'}) + ' |')
$lines.Add('| REVIEW_WRITE_OK\| | 条件性（本轮无 review 候选） | ' + $(if($hasReviewWriteOk){'present'}else{'absent'}) + ' | ' + $(if($hasReviewWriteOk){'PASS'}else{'N/A'}) + ' |')
$lines.Add('| COMMIT_OK\| | present | ' + $(if($hasCommitOk){'present'}else{'absent'}) + ' | ' + $(if($hasCommitOk){'PASS'}else{'FAIL'}) + ' |')
$lines.Add('| RUN_STATUS\|success\| | present | ' + $(if($hasRunSuccess){'present'}else{'absent'}) + ' | ' + $(if($hasRunSuccess){'PASS'}else{'FAIL'}) + ' |')
$lines.Add('| RUN_STATUS\|failed\| | absent | ' + $(if($hasRunFailed){'present'}else{'absent'}) + ' | ' + $(if(-not $hasRunFailed){'PASS'}else{'FAIL'}) + ' |')
$lines.Add('| lock released | yes | ' + $(if($lockReleased){'yes'}else{'no'}) + ' | ' + $(if($lockReleased){'PASS'}else{'FAIL'}) + ' |')
$lines.Add('| md updated | yes | ' + $(if($mdUpdated){'yes'}else{'no'}) + ' | ' + $(if($mdUpdated){'PASS'}else{'FAIL'}) + ' |')
$lines.Add('| result.json valid | yes | ' + $(if($resultValid){'yes'}else{'no'}) + ' | ' + $(if($resultValid){'PASS'}else{'FAIL'}) + ' |')
$lines.Add('')
$lines.Add('## 硬门槛检查')
$lines.Add('COMMIT_OK + RUN_STATUS|failed| -> ' + $(if($hardFail){'FAIL (P1)'}else{'PASS'}))
$lines.Add('')
$lines.Add('## 最终判定')
$lines.Add('**' + $(if($pass){'PASS'}else{'FAIL'}) + '**')
$lines.Add('')
$lines.Add('## stdout.txt 内容')
$lines.Add('```')
$lines.Add($stdout)
$lines.Add('```')

Set-Content -Path (Join-Path $base 'test-report.md') -Value ($lines -join "`r`n") -Encoding UTF8

Write-Output "T37: $($pass ? 'PASS' : 'FAIL')"
Write-Output "  hasBackupOk=$hasBackupOk hasFetchComplete=$hasFetchComplete hasSummary=$hasSummary"
Write-Output "  hasCommitOk=$hasCommitOk hasRunSuccess=$hasRunSuccess hasRunFailed=$hasRunFailed"
Write-Output "  hasReviewWriteOk=$hasReviewWriteOk lockReleased=$lockReleased mdUpdated=$mdUpdated resultValid=$resultValid"
Write-Output "  hardFail=$hardFail"
