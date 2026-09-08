$ErrorActionPreference = 'Continue'
$base = 'd:\AI\Workspace\automatic\github-version-monitor\.production-validation-v19-final\T39'
$lib  = 'd:\AI\Workspace\automatic\github-version-monitor\.production-validation-v19-final\lib'
$env:GITHUB_VERSION_MONITOR_BASE = $base

# Clean (only .output and .monitor subdirs, keep scripts)
if (Test-Path (Join-Path $base '.output'))  { Remove-Item (Join-Path $base '.output')  -Recurse -Force -ErrorAction SilentlyContinue }
if (Test-Path (Join-Path $base '.monitor')) { Remove-Item (Join-Path $base '.monitor') -Recurse -Force -ErrorAction SilentlyContinue }
foreach ($f in 'stdout.txt','stderr.txt','md-before.md','md-after.md','result-before.json','result-after.json','lock-before.txt','lock-after.txt','test-report.md','combined.ps1') {
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

# Fixture: 1 real repo (microsoft/vscode). prevFlag=no + prevGitVer=v1.136.0 → likely no review trigger.
& (Join-Path $lib 'create-fixture.ps1') -OutputPath (Join-Path $base '.output\GitHub更新监测列表.md') -Repos @(
    @{owner='microsoft'; repo='vscode'; name='vscode'}
) -LocalVer '1.0.0' -PrevFlag 'no' -PrevGitVer 'v1.136.0' -PrevGitDate '2026-09-01'

$md     = Join-Path $base '.output\GitHub更新监测列表.md'
$result = Join-Path $base '.monitor\result.json'
$lock   = Join-Path $base '.monitor\run.lock'

# Collect before state
Copy-Item $md (Join-Path $base 'md-before.md')
if (Test-Path $result) { Copy-Item $result (Join-Path $base 'result-before.json') } else { Set-Content -Path (Join-Path $base 'result-before.json') -Value '{}' }
if (Test-Path $lock)   { Copy-Item $lock   (Join-Path $base 'lock-before.txt') }    else { Set-Content -Path (Join-Path $base 'lock-before.txt') -Value 'no lock' }

New-Item -ItemType Directory -Force -Path (Join-Path $base 'before') | Out-Null
Copy-Item $md (Join-Path $base 'before\GitHub更新监测列表.md')

# Combined script: step1 -> step2 -> step3 -> step4 -> step5-t39-harness (dot-source, single pwsh process)
$combinedScript = @'
$ErrorActionPreference = 'Continue'
$base = $env:GITHUB_VERSION_MONITOR_BASE
$lib  = 'd:\AI\Workspace\automatic\github-version-monitor\.production-validation-v19-final\lib'
. (Join-Path $lib 'step1.ps1')
. (Join-Path $lib 'step2.ps1')
. (Join-Path $lib 'step3.ps1')
. (Join-Path $lib 'step4.ps1')
. (Join-Path $lib 'step5-t39-harness.ps1')
'@
$combinedPath = Join-Path $base 'combined.ps1'
Set-Content -Path $combinedPath -Value $combinedScript -Encoding UTF8

# Execute combined (single pwsh process, stdout+stderr redirected)
$proc = Start-Process -FilePath pwsh -ArgumentList "-NoProfile -NonInteractive -File `"$combinedPath`"" -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $base 'stdout.txt') -RedirectStandardError (Join-Path $base 'stderr.txt')
$deadline = (Get-Date).AddSeconds(180)
while ((-not $proc.HasExited) -and ((Get-Date) -lt $deadline)) { Start-Sleep -Milliseconds 200 }
if (-not $proc.HasExited) { $proc.Kill() }

# Collect after state
Copy-Item $md (Join-Path $base 'md-after.md')
if (Test-Path $result) { Copy-Item $result (Join-Path $base 'result-after.json') } else { Set-Content -Path (Join-Path $base 'result-after.json') -Value '{}' }
if (Test-Path $lock)   { Copy-Item $lock   (Join-Path $base 'lock-after.txt') }    else { Set-Content -Path (Join-Path $base 'lock-after.txt') -Value 'lock released' }

New-Item -ItemType Directory -Force -Path (Join-Path $base 'after') | Out-Null
Copy-Item $md (Join-Path $base 'after\GitHub更新监测列表.md')
if (Test-Path $result) { Copy-Item $result (Join-Path $base 'after\result.json') }

# Verify
$stdout = Get-Content (Join-Path $base 'stdout.txt') -Raw -ErrorAction SilentlyContinue
if ($null -eq $stdout) { $stdout = '' }

$hasCommitOk     = $stdout -match 'COMMIT_OK\|'
$hasRuntimeError = $stdout -match 'RUNTIME_ERROR\|'
$hasRunFailed    = $stdout -match 'RUN_STATUS\|failed\|'
$hasRunSuccess   = $stdout -match 'RUN_STATUS\|success\|'
$lockStillPresent = (Test-Path $lock)
$lockPid = 'N/A'
if ($lockStillPresent) {
    $lockRaw = Get-Content $lock -Raw -ErrorAction SilentlyContinue
    if ($lockRaw -match 'pid=(\d+)') { $lockPid = $Matches[1] } else { $lockPid = 'N/A' }
} else { $lockPid = 'released' }

# Core invariant: commitSucceeded=true AND lockReleased=false -> RUN_STATUS|failed|
# Observable: COMMIT_OK present + RUN_STATUS|success| absent + RUN_STATUS|failed| present + lock still present + lock PID=999999
$pass = $hasCommitOk -and $hasRunFailed -and (-not $hasRunSuccess) -and $lockStillPresent -and ($lockPid -eq '999999')

# Build report as array of lines (avoid here-string with backticks)
$lines = New-Object System.Collections.Generic.List[string]
$lines.Add('# T39-v19 Test Report: commit 成功 + 锁释放失败 → RUN_STATUS|failed|')
$lines.Add('')
$lines.Add('## 构造方法')
$lines.Add('step5-t39-harness.ps1 同进程执行：Step 5 commit 段成功后（Move-Item → COMMIT_OK），在 if/else 块之后、锁释放段之前注入 `Set-Content $lockPath -Value "pid=999999;..."` 修改锁 PID，使后续锁释放段 ownership 校验失败（锁内 PID=999999 ≠ 当前进程 PID）。')
$lines.Add('step1→step4 与 step5-t39-harness 在同一 pwsh 进程（dot-source 模式）中运行，确保锁 PID 一致（step1 创建锁时写入当前进程 PID）。')
$lines.Add('')
$lines.Add('## Fixture')
$lines.Add('1 个真实仓库：microsoft/vscode (prevFlag=no, prevGitVer=v1.136.0, prevGitDate=2026-09-01)')
$lines.Add('')
$lines.Add('## 验证项')
$lines.Add('')
$lines.Add('| 检查项 | 期望 | 实际 | 结果 |')
$lines.Add('|---|---|---|---|')
$lines.Add('| COMMIT_OK\| | present | ' + $(if($hasCommitOk){'present'}else{'absent'}) + ' | ' + $(if($hasCommitOk){'PASS'}else{'FAIL'}) + ' |')
$lines.Add('| RUNTIME_ERROR\| | present | ' + $(if($hasRuntimeError){'present'}else{'absent'}) + ' | ' + $(if($hasRuntimeError){'PASS'}else{'FAIL'}) + ' |')
$lines.Add('| RUN_STATUS\|failed\| | present | ' + $(if($hasRunFailed){'present'}else{'absent'}) + ' | ' + $(if($hasRunFailed){'PASS'}else{'FAIL'}) + ' |')
$lines.Add('| RUN_STATUS\|success\| | absent | ' + $(if($hasRunSuccess){'present'}else{'absent'}) + ' | ' + $(if(-not $hasRunSuccess){'PASS'}else{'FAIL'}) + ' |')
$lines.Add('| lock still present | yes | ' + $(if($lockStillPresent){'yes'}else{'no'}) + ' | ' + $(if($lockStillPresent){'PASS'}else{'FAIL'}) + ' |')
$lines.Add('| lock PID = 999999 | yes | ' + $lockPid + ' | ' + $(if($lockPid -eq '999999'){'PASS'}else{'FAIL'}) + ' |')
$lines.Add('')
$lines.Add('## 核心 invariant 验证')
$lines.Add('```')
$lines.Add('commitSucceeded = true')
$lines.Add('lockReleased    = false')
$lines.Add('        ↓')
$lines.Add('RUN_STATUS|failed|')
$lines.Add('```')
$lines.Add('')
$lines.Add('## 最终判定')
$lines.Add('**' + $(if($pass){'PASS'}else{'FAIL'}) + '**')
$lines.Add('')
$lines.Add('## stdout.txt 内容')
$lines.Add('```')
$lines.Add($stdout)
$lines.Add('```')

Set-Content -Path (Join-Path $base 'test-report.md') -Value ($lines -join "`r`n") -Encoding UTF8

Write-Output "T39: $($pass ? 'PASS' : 'FAIL')"
Write-Output "  hasCommitOk=$hasCommitOk hasRuntimeError=$hasRuntimeError hasRunFailed=$hasRunFailed hasRunSuccess=$hasRunSuccess"
Write-Output "  lockStillPresent=$lockStillPresent lockPid=$lockPid"
