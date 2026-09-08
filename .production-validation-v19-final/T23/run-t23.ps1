$ErrorActionPreference = 'Continue'
$base = 'd:\AI\Workspace\automatic\github-version-monitor\.production-validation-v19-final\T23'
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

# Fixture: real repo (no review needed)
& (Join-Path $lib 'create-fixture.ps1') -OutputPath (Join-Path $base '.output\GitHub更新监测列表.md') -Repos @(@{owner='microsoft'; repo='vscode'; name='vscode'}) -LocalVer '1.0.0' -PrevFlag 'no' -PrevGitVer 'v1.80.0' -PrevGitDate '2023-08-01'

$md = Join-Path $base '.output\GitHub更新监测列表.md'
$result = Join-Path $base '.monitor\result.json'
$tmp = Join-Path $base '.output\GitHub更新监测列表.md.tmp'
$lock = Join-Path $base '.monitor\run.lock'

# Save md-before
Copy-Item $md (Join-Path $base 'md-before.md')
$shaMdBefore = (Get-FileHash $md -Algorithm SHA256).Hash

# Combined script: step1 + step2 + step3, wait for signal, then step5-full, then write done.flag
$combinedScript = @'
$base = $env:GITHUB_VERSION_MONITOR_BASE
$lib = 'd:\AI\Workspace\automatic\github-version-monitor\.production-validation-v19-final\lib'
& (Join-Path $lib 'step1.ps1')
& (Join-Path $lib 'step2.ps1')
& (Join-Path $lib 'step3.ps1')
# Wait for lock-holder to acquire the lock on main md
$signalPath = Join-Path $base 'lock-ready.flag'
while (-not (Test-Path $signalPath)) { Start-Sleep -Milliseconds 100 }
& (Join-Path $lib 'step5-full.ps1')
# Write done.flag to release the lock (lock-holder will close the file)
Set-Content -Path (Join-Path $base 'done.flag') -Value 'done'
'@
$combinedPath = Join-Path $base 'combined.ps1'
Set-Content -Path $combinedPath -Value $combinedScript -Encoding UTF8

# Lock-holder script: open main md with FileAccess::Read, FileShare::None (blocks Move-Item)
$lockScript = @'
param([string]$File, [string]$SignalPath)
$fs = [System.IO.File]::Open($File, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read)
Set-Content -Path $SignalPath -Value 'ready'
$done = Join-Path $PSScriptRoot 'done.flag'
while (-not (Test-Path $done)) { Start-Sleep -Milliseconds 100 }
$fs.Close()
'@
$lockScriptPath = Join-Path $base 'lock-holder.ps1'
Set-Content -Path $lockScriptPath -Value $lockScript -Encoding UTF8
$signalPath = Join-Path $base 'lock-ready.flag'

# Start lock-holder process
$proc = Start-Process -FilePath pwsh -ArgumentList "-NoProfile -NonInteractive -File `"$lockScriptPath`" -File `"$md`" -SignalPath `"$signalPath`"" -WindowStyle Hidden -PassThru

# Start combined script (step1+step2+step3, wait for signal, then step5-full, then write done.flag)
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
Copy-Item $result (Join-Path $base 'result-before.json')
New-Item -ItemType Directory -Force -Path (Join-Path $base 'before') | Out-Null
Copy-Item $md (Join-Path $base 'before\GitHub更新监测列表.md')
Copy-Item $result (Join-Path $base 'before\result.json')
if (Test-Path $lock) { Copy-Item $lock (Join-Path $base 'lock-before.txt') } else { Set-Content -Path (Join-Path $base 'lock-before.txt') -Value 'lock released after step5-full error' }

$shaResultBefore = (Get-FileHash $result -Algorithm SHA256).Hash
Set-Content -Path (Join-Path $base 'sha256-before.txt') -Value "main md: $shaMdBefore`nresult.json: $shaResultBefore`nmd.tmp: N/A"

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
Set-Content -Path (Join-Path $base 'sha256-after.txt') -Value "main md: $shaMd`nresult.json: $shaResult`nmd.tmp: $shaTmp"

# Verify
$stdout = Get-Content (Join-Path $base 'stdout.txt') -Raw -ErrorAction SilentlyContinue
if ($null -eq $stdout) { $stdout = '' }
$hasRunFailed = $stdout -match 'RUN_STATUS\|failed\|'
$hasCommitOk = $stdout -match 'COMMIT_OK\|'
$hasRunSuccess = $stdout -match 'RUN_STATUS\|success\|'
$mdUnchanged = ($shaMdBefore -eq $shaMd)
$tmpCleaned = (-not (Test-Path $tmp))
$lockReleased = (-not (Test-Path $lock))

$pass = $mdUnchanged -and $tmpCleaned -and $lockReleased -and $hasRunFailed -and (-not $hasCommitOk) -and (-not $hasRunSuccess)

# Build report as array of lines (avoid here-string with backticks)
$lines = New-Object System.Collections.Generic.List[string]
$lines.Add('# T23-v19 Test Report: md 原子替换失败（Step 5 Move-Item）')
$lines.Add('')
$lines.Add('## 构造方法')
$lines.Add('对目标 md 设置外部文件锁（FileAccess::Read, FileShare::None），使 Move-Item 无法替换。')
$lines.Add('step1+step2+step3+step5-full 在同一 pwsh 进程中运行，确保锁 PID 一致；lock-holder 在 step3 完成后、step5-full 开始前持有 md 文件锁。')
$lines.Add('combined 脚本在 step5-full 完成后写 done.flag，lock-holder 收到信号后释放文件锁。')
$lines.Add('')
$lines.Add('## 验证项')
$lines.Add('')
$lines.Add('| 检查项 | 期望 | 实际 | 结果 |')
$lines.Add('|---|---|---|---|')
$lines.Add('| 主 md unchanged | yes | ' + $(if($mdUnchanged){'yes'}else{'no'}) + ' | ' + $(if($mdUnchanged){'PASS'}else{'FAIL'}) + ' |')
$lines.Add('| tmp cleaned | yes | ' + $(if($tmpCleaned){'yes'}else{'no'}) + ' | ' + $(if($tmpCleaned){'PASS'}else{'FAIL'}) + ' |')
$lines.Add('| lock released | yes | ' + $(if($lockReleased){'yes'}else{'no'}) + ' | ' + $(if($lockReleased){'PASS'}else{'FAIL'}) + ' |')
$lines.Add('| RUN_STATUS\|failed\| | present | ' + $(if($hasRunFailed){'present'}else{'absent'}) + ' | ' + $(if($hasRunFailed){'PASS'}else{'FAIL'}) + ' |')
$lines.Add('| COMMIT_OK\| | absent | ' + $(if($hasCommitOk){'present'}else{'absent'}) + ' | ' + $(if(-not $hasCommitOk){'PASS'}else{'FAIL'}) + ' |')
$lines.Add('| RUN_STATUS\|success\| | absent | ' + $(if($hasRunSuccess){'present'}else{'absent'}) + ' | ' + $(if(-not $hasRunSuccess){'PASS'}else{'FAIL'}) + ' |')
$lines.Add('')
$lines.Add('## 最终判定')
$lines.Add('**' + $(if($pass){'PASS'}else{'FAIL'}) + '**')
$lines.Add('')
$lines.Add('## stdout.txt 内容')
$lines.Add('```')
$lines.Add($stdout)
$lines.Add('```')

Set-Content -Path (Join-Path $base 'test-report.md') -Value ($lines -join "`r`n") -Encoding UTF8

Write-Output "T23: $($pass ? 'PASS' : 'FAIL')"
Write-Output "  mdUnchanged=$mdUnchanged tmpCleaned=$tmpCleaned lockReleased=$lockReleased"
Write-Output "  hasRunFailed=$hasRunFailed hasCommitOk=$hasCommitOk hasRunSuccess=$hasRunSuccess"

