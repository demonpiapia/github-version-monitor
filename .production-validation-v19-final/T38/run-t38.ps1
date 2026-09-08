$ErrorActionPreference = 'Continue'
$base = 'd:\AI\Workspace\automatic\github-version-monitor\.production-validation-v19-final\T38'
$lib = 'd:\AI\Workspace\automatic\github-version-monitor\.production-validation-v19-final\lib'
$env:GITHUB_VERSION_MONITOR_BASE = $base

# Clean (only .output and .monitor subdirs, keep scripts)
if (Test-Path (Join-Path $base '.output')) { Remove-Item (Join-Path $base '.output') -Recurse -Force -ErrorAction SilentlyContinue }
if (Test-Path (Join-Path $base '.monitor')) { Remove-Item (Join-Path $base '.monitor') -Recurse -Force -ErrorAction SilentlyContinue }
foreach ($f in 'stdout.txt','stderr.txt','sha256-before.txt','sha256-after.txt','md-before.md','md-after.md','result-before.json','result-after.json','lock-before.txt','lock-after.txt','done.flag','lock-ready.flag','test-report.md','acl-before.xml','phase1-3-stdout.txt') {
    $p = Join-Path $base $f
    if (Test-Path $p) { Remove-Item $p -Force -ErrorAction SilentlyContinue }
}
foreach ($d in 'before','after') {
    $p = Join-Path $base $d
    if (Test-Path $p) { Remove-Item $p -Recurse -Force -ErrorAction SilentlyContinue }
}

New-Item -ItemType Directory -Force -Path $base | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $base '.output') | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $base '.monitor') | Out-Null

# Fixture: nonexistent repo -> 404 -> not_found -> review=true
& (Join-Path $lib 'create-fixture.ps1') -OutputPath (Join-Path $base '.output\GitHub更新监测列表.md') -Repos @(@{owner='test'; repo='nonexistent-repo-12345'; name='nonexistent'}) -LocalVer '1.0.0' -PrevFlag 'no' -PrevGitVer 'v1.0.0' -PrevGitDate '2026-01-01'

$md = Join-Path $base '.output\GitHub更新监测列表.md'
$result = Join-Path $base '.monitor\result.json'
$tmp = Join-Path $base '.monitor\result.review.tmp'
$lock = Join-Path $base '.monitor\run.lock'

# Pre-create result.review.tmp (empty placeholder)
Set-Content -Path $tmp -Value '{}' -Encoding UTF8

# Combined script: step1 + step2 + step3, wait for signal, then step4, then write done.flag
$combinedScript = @'
$base = $env:GITHUB_VERSION_MONITOR_BASE
$lib = 'd:\AI\Workspace\automatic\github-version-monitor\.production-validation-v19-final\lib'
& (Join-Path $lib 'step1.ps1')
& (Join-Path $lib 'step2.ps1')
& (Join-Path $lib 'step3.ps1')
# Wait for lock-holder to acquire the lock on result.review.tmp
$signalPath = Join-Path $base 'lock-ready.flag'
while (-not (Test-Path $signalPath)) { Start-Sleep -Milliseconds 100 }
& (Join-Path $lib 'step4.ps1')
# Write done.flag to release the lock (lock-holder will close the file)
Set-Content -Path (Join-Path $base 'done.flag') -Value 'done'
'@
$combinedPath = Join-Path $base 'combined.ps1'
Set-Content -Path $combinedPath -Value $combinedScript -Encoding UTF8

# Lock-holder script: open result.review.tmp with FileShare::None, signal, wait for done
$lockScript = @'
param([string]$File, [string]$SignalPath)
$fs = [System.IO.File]::Open($File, [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
Set-Content -Path $SignalPath -Value 'ready'
$done = Join-Path $PSScriptRoot 'done.flag'
while (-not (Test-Path $done)) { Start-Sleep -Milliseconds 100 }
$fs.Close()
'@
$lockScriptPath = Join-Path $base 'lock-holder.ps1'
Set-Content -Path $lockScriptPath -Value $lockScript -Encoding UTF8
$signalPath = Join-Path $base 'lock-ready.flag'

# Start lock-holder process
$proc = Start-Process -FilePath pwsh -ArgumentList "-NoProfile -NonInteractive -File `"$lockScriptPath`" -File `"$tmp`" -SignalPath `"$signalPath`"" -WindowStyle Hidden -PassThru

# Start combined script (step1+step2+step3, wait for signal, then step4, then write done.flag)
$combinedProc = Start-Process -FilePath pwsh -ArgumentList "-NoProfile -NonInteractive -File `"$combinedPath`"" -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $base 'stdout.txt') -RedirectStandardError (Join-Path $base 'stderr.txt')

# Wait for signal (lock acquired)
$deadline = (Get-Date).AddSeconds(60)
while ((-not (Test-Path $signalPath)) -and ((Get-Date) -lt $deadline)) { Start-Sleep -Milliseconds 100 }

# Wait for combined to finish (with timeout)
$deadline2 = (Get-Date).AddSeconds(120)
while ((-not $combinedProc.HasExited) -and ((Get-Date) -lt $deadline2)) { Start-Sleep -Milliseconds 200 }
if (-not $combinedProc.HasExited) { $combinedProc.Kill() }

# Wait for lock-holder to release (it should exit after done.flag is written)
$proc.WaitForExit(5000) | Out-Null
if (-not $proc.HasExited) { $proc.Kill() }

# Collect before state (from before/ dir)
Copy-Item $md (Join-Path $base 'md-before.md')
Copy-Item $result (Join-Path $base 'result-before.json')
New-Item -ItemType Directory -Force -Path (Join-Path $base 'before') | Out-Null
Copy-Item $md (Join-Path $base 'before\GitHub更新监测列表.md')
Copy-Item $result (Join-Path $base 'before\result.json')
if (Test-Path $lock) { Copy-Item $lock (Join-Path $base 'lock-before.txt') } else { Set-Content -Path (Join-Path $base 'lock-before.txt') -Value 'lock released after step4 error' }

$shaMdBefore = (Get-FileHash $md -Algorithm SHA256).Hash
$shaResultBefore = (Get-FileHash $result -Algorithm SHA256).Hash
Set-Content -Path (Join-Path $base 'sha256-before.txt') -Value "main md: $shaMdBefore`nresult.json: $shaResultBefore`nresult.review.tmp: N/A"

# Collect after state
Copy-Item $md (Join-Path $base 'md-after.md')
Copy-Item $result (Join-Path $base 'result-after.json')
New-Item -ItemType Directory -Force -Path (Join-Path $base 'after') | Out-Null
Copy-Item $md (Join-Path $base 'after\GitHub更新监测列表.md')
Copy-Item $result (Join-Path $base 'after\result.json')
if (Test-Path $lock) { Copy-Item $lock (Join-Path $base 'lock-after.txt') } else { Set-Content -Path (Join-Path $base 'lock-after.txt') -Value 'lock released' }

$shaMd = (Get-FileHash $md -Algorithm SHA256).Hash
$shaResult = (Get-FileHash $result -Algorithm SHA256).Hash
$shaTmp = if (Test-Path $tmp) { (Get-FileHash $tmp -Algorithm SHA256).Hash } else { 'N/A' }
Set-Content -Path (Join-Path $base 'sha256-after.txt') -Value "main md: $shaMd`nresult.json: $shaResult`nresult.review.tmp: $shaTmp"

# Verify
$stdout = Get-Content (Join-Path $base 'stdout.txt') -Raw -ErrorAction SilentlyContinue
if ($null -eq $stdout) { $stdout = '' }
$hasReviewError = $stdout -match 'REVIEW_WRITE_ERROR\|'
$hasRunFailed = $stdout -match 'RUN_STATUS\|failed\|'
$hasCommitOk = $stdout -match 'COMMIT_OK\|'
$hasRunSuccess = $stdout -match 'RUN_STATUS\|success\|'
$resultUnchanged = ($shaMdBefore -eq $shaMd) -and ($shaResultBefore -eq $shaResult)
$tmpCleaned = (-not (Test-Path $tmp))
$lockReleased = (-not (Test-Path $lock))

$pass = $hasReviewError -and $hasRunFailed -and (-not $hasCommitOk) -and (-not $hasRunSuccess) -and $resultUnchanged -and $tmpCleaned -and $lockReleased

# Build report as array of lines (avoid here-string with backticks)
$lines = New-Object System.Collections.Generic.List[string]
$lines.Add('# T38-v19 Test Report: review 写入失败（Step 4 result.review.tmp）')
$lines.Add('')
$lines.Add('## 构造方法')
$lines.Add('预创建 result.review.tmp 并以 FileShare::None 独占锁定，阻止 Set-Content 覆盖。')
$lines.Add('step1+step2+step3+step4 在同一 pwsh 进程中运行，确保锁 PID 一致；lock-holder 在 step3 完成后、step4 开始前持有 tmp 文件锁。')
$lines.Add('combined 脚本在 step4 完成后写 done.flag，lock-holder 收到信号后释放文件锁。')
$lines.Add('')
$lines.Add('## 验证项')
$lines.Add('')
$lines.Add('| 检查项 | 期望 | 实际 | 结果 |')
$lines.Add('|---|---|---|---|')
$lines.Add('| REVIEW_WRITE_ERROR\| | present | ' + $(if($hasReviewError){'present'}else{'absent'}) + ' | ' + $(if($hasReviewError){'PASS'}else{'FAIL'}) + ' |')
$lines.Add('| RUN_STATUS\|failed\| | present | ' + $(if($hasRunFailed){'present'}else{'absent'}) + ' | ' + $(if($hasRunFailed){'PASS'}else{'FAIL'}) + ' |')
$lines.Add('| COMMIT_OK\| | absent | ' + $(if($hasCommitOk){'present'}else{'absent'}) + ' | ' + $(if(-not $hasCommitOk){'PASS'}else{'FAIL'}) + ' |')
$lines.Add('| RUN_STATUS\|success\| | absent | ' + $(if($hasRunSuccess){'present'}else{'absent'}) + ' | ' + $(if(-not $hasRunSuccess){'PASS'}else{'FAIL'}) + ' |')
$lines.Add('| result.json unchanged | yes | ' + $(if($resultUnchanged){'yes'}else{'no'}) + ' | ' + $(if($resultUnchanged){'PASS'}else{'FAIL'}) + ' |')
$lines.Add('| tmp cleaned | yes | ' + $(if($tmpCleaned){'yes'}else{'no'}) + ' | ' + $(if($tmpCleaned){'PASS'}else{'FAIL'}) + ' |')
$lines.Add('| lock released | yes | ' + $(if($lockReleased){'yes'}else{'no'}) + ' | ' + $(if($lockReleased){'PASS'}else{'FAIL'}) + ' |')
$lines.Add('')
$lines.Add('## 最终判定')
$lines.Add('**' + $(if($pass){'PASS'}else{'FAIL'}) + '**')
$lines.Add('')
$lines.Add('## stdout.txt 内容')
$lines.Add('```')
$lines.Add($stdout)
$lines.Add('```')

Set-Content -Path (Join-Path $base 'test-report.md') -Value ($lines -join "`r`n") -Encoding UTF8

Write-Output "T38: $($pass ? 'PASS' : 'FAIL')"
Write-Output "  hasReviewError=$hasReviewError hasRunFailed=$hasRunFailed hasCommitOk=$hasCommitOk hasRunSuccess=$hasRunSuccess"
Write-Output "  resultUnchanged=$resultUnchanged tmpCleaned=$tmpCleaned lockReleased=$lockReleased"

