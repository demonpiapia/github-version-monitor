$ErrorActionPreference = 'Continue'
$base = 'd:\AI\Workspace\automatic\github-version-monitor\.production-validation-v19-final\T22'
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
$outputDir = Join-Path $base '.output'

# Save md-before
Copy-Item $md (Join-Path $base 'md-before.md')
$shaMdBefore = (Get-FileHash $md -Algorithm SHA256).Hash

# Combined script: step1 + step2 + step3, apply ACL deny, step5-full, restore ACL
$combinedScript = @'
$base = $env:GITHUB_VERSION_MONITOR_BASE
$lib = 'd:\AI\Workspace\automatic\github-version-monitor\.production-validation-v19-final\lib'
& (Join-Path $lib 'step1.ps1')
& (Join-Path $lib 'step2.ps1')
& (Join-Path $lib 'step3.ps1')
# Apply ACL deny on .output
$outputDir = Join-Path $base '.output'
$acl = Get-Acl $outputDir
$denyRule = New-Object System.Security.AccessControl.FileSystemAccessRule($env:USERNAME, 'CreateFiles', 'Deny')
$acl.SetAccessRule($denyRule)
Set-Acl -Path $outputDir -AclObject $acl
# Run step5-full (Set-Content $tmp will fail)
& (Join-Path $lib 'step5-full.ps1')
# Restore ACL
$restoredAcl = Import-Clixml -Path (Join-Path $base 'acl-before.xml')
Set-Acl -Path $outputDir -AclObject $restoredAcl
'@
$combinedPath = Join-Path $base 'combined.ps1'
Set-Content -Path $combinedPath -Value $combinedScript -Encoding UTF8

# Save ACL before applying deny
$acl = Get-Acl $outputDir
Export-Clixml -Path (Join-Path $base 'acl-before.xml') -InputObject $acl

& pwsh -NoProfile -NonInteractive -File $combinedPath *>&1 > (Join-Path $base 'stdout.txt') 2> (Join-Path $base 'stderr.txt')

# Ensure ACL restored (in case script crashed before restore)
$restoredAcl = Import-Clixml -Path (Join-Path $base 'acl-before.xml')
Set-Acl -Path $outputDir -AclObject $restoredAcl

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
$lines.Add('# T22-v19 Test Report: md 临时文件写入失败（Step 5 md.tmp）')
$lines.Add('')
$lines.Add('## 构造方法')
$lines.Add('通过 ACL deny 拒绝当前用户对 .output 目录的 CreateFiles 权限。')
$lines.Add('step1+step2+step3+step5-full 在同一 pwsh 进程中运行，确保锁 PID 一致。')
$lines.Add('ACL deny 在 step3 完成后、step5-full 执行前应用，测试后还原。')
$lines.Add('')
$lines.Add('## 验证项')
$lines.Add('')
$lines.Add('| 检查项 | 期望 | 实际 | 结果 |')
$lines.Add('|---|---|---|---|')
$lines.Add('| 主 md unchanged | yes | ' + $(if($mdUnchanged){'yes'}else{'no'}) + ' | ' + $(if($mdUnchanged){'PASS'}else{'FAIL'}) + ' |')
$lines.Add('| tmp 不残留 | yes | ' + $(if($tmpCleaned){'yes'}else{'no'}) + ' | ' + $(if($tmpCleaned){'PASS'}else{'FAIL'}) + ' |')
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

Write-Output "T22: $($pass ? 'PASS' : 'FAIL')"
Write-Output "  mdUnchanged=$mdUnchanged tmpCleaned=$tmpCleaned lockReleased=$lockReleased"
Write-Output "  hasRunFailed=$hasRunFailed hasCommitOk=$hasCommitOk hasRunSuccess=$hasRunSuccess"

