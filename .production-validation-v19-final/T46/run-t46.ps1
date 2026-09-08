$ErrorActionPreference = 'Continue'
$base = 'd:\AI\Workspace\automatic\github-version-monitor\.production-validation-v19-final\T46'
$lib  = 'd:\AI\Workspace\automatic\github-version-monitor\.production-validation-v19-final\lib'
$env:GITHUB_VERSION_MONITOR_BASE = $base

# 清理 base（保留本脚本自身）
if (Test-Path $base) {
    Get-ChildItem $base -Force | Where-Object { $_.Name -ne 'run-t46.ps1' } | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
}
New-Item -ItemType Directory -Force -Path $base | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $base '.output') | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $base 'before') | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $base 'after')  | Out-Null

# Fixture: 1 个真实仓库（microsoft/vscode）
& (Join-Path $lib 'create-fixture.ps1') -OutputPath (Join-Path $base '.output\GitHub更新监测列表.md') -Repos @(
    @{owner='microsoft'; repo='vscode'; name='vscode'}
) -LocalVer '1.0.0' -PrevFlag 'no' -PrevGitVer '1.136.0' -PrevGitDate '2026-09-01'

$md = Join-Path $base '.output\GitHub更新监测列表.md'
Copy-Item $md (Join-Path $base 'md-before.md')
Copy-Item $md (Join-Path $base 'before\GitHub更新监测列表.md')

# 执行 Step 1 + Step 2（分离 stdout/stderr）
& pwsh -NoProfile -NonInteractive -File (Join-Path $lib 'step1.ps1') > (Join-Path $base 'stdout.txt') 2> (Join-Path $base 'stderr.txt')
& pwsh -NoProfile -NonInteractive -File (Join-Path $lib 'step2.ps1') >> (Join-Path $base 'stdout.txt') 2>> (Join-Path $base 'stderr.txt')

# 收集 after 状态
Copy-Item $md (Join-Path $base 'md-after.md')
Copy-Item $md (Join-Path $base 'after\GitHub更新监测列表.md')

# 目录列表（T46 目录根）
Get-ChildItem $base -Force | Select-Object Name, PSIsContainer | Format-Table -AutoSize | Out-File (Join-Path $base 'directory-listing.txt') -Encoding UTF8

# 根目录检查：T46 目录根不应有 GitHub更新监测列表.md
$rootMdPath = Join-Path $base 'GitHub更新监测列表.md'
$rootMdExists = Test-Path $rootMdPath
Set-Content -Path (Join-Path $base 'root-md-check.txt') -Value "root md exists: $rootMdExists (expected: False)" -Encoding UTF8

# 验证
$outputMdExists = Test-Path $md
$backupDir = Join-Path $base '.monitor\backups'
$backupExists = (Test-Path $backupDir) -and ((Get-ChildItem $backupDir -Filter '*.md' -ErrorAction SilentlyContinue).Count -gt 0)

$pass = $outputMdExists -and (-not $rootMdExists) -and $backupExists

$y1 = if ($outputMdExists) { 'yes' } else { 'no' }
$r1 = if ($outputMdExists) { 'PASS' } else { 'FAIL' }
$y2 = if (-not $rootMdExists) { 'yes' } else { 'no' }
$r2 = if (-not $rootMdExists) { 'PASS' } else { 'FAIL' }
$y3 = if ($backupExists) { 'yes' } else { 'no' }
$r3 = if ($backupExists) { 'PASS' } else { 'FAIL' }
$verdict = if ($pass) { 'PASS' } else { 'FAIL' }

$dirListContent = Get-Content (Join-Path $base 'directory-listing.txt') -Raw
$rootCheckContent = Get-Content (Join-Path $base 'root-md-check.txt') -Raw
$stdoutContent = Get-Content (Join-Path $base 'stdout.txt') -Raw
$stderrContent = if (Test-Path (Join-Path $base 'stderr.txt')) { Get-Content (Join-Path $base 'stderr.txt') -Raw } else { '' }

$fence = '```'
$report = @(
'# T46-v19 Test Report: .output 状态路径回归'
''
'## 验证项'
''
'| 检查项 | 期望 | 实际 | 结果 |'
'|---|---|---|---|'
"| .output/GitHub更新监测列表.md 存在 | yes | $y1 | $r1 |"
"| 根目录不存在 GitHub更新监测列表.md | yes | $y2 | $r2 |"
"| backup 基于 .output 状态文件 | yes | $y3 | $r3 |"
''
'## 最终判定'
"**$verdict**"
''
'## stdout.txt'
$fence
$stdoutContent
$fence
''
'## stderr.txt'
$fence
$stderrContent
$fence
''
'## directory-listing.txt'
$fence
$dirListContent
$fence
''
'## root-md-check.txt'
$fence
$rootCheckContent
$fence
) -join "`r`n"

Set-Content -Path (Join-Path $base 'test-report.md') -Value $report -Encoding UTF8

Write-Output "T46: $verdict"
