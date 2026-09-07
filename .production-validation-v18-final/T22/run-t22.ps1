# T22: md 临时文件失败 — Set-Content 创建 md 临时文件失败时，主 md 不变
$ErrorActionPreference = 'Continue'
$base = 'D:\AI\Workspace\automatic\github-version-monitor\.production-validation-v18-final\T22'
$lib = 'D:\AI\Workspace\automatic\github-version-monitor\.production-validation-v18-final\lib'
$env:GITHUB_VERSION_MONITOR_BASE = $base

# Clean
if (Test-Path (Join-Path $base '.monitor')) { Remove-Item (Join-Path $base '.monitor') -Recurse -Force -ErrorAction SilentlyContinue }
if (Test-Path (Join-Path $base '.output\GitHub更新监测列表.md.tmp')) { Remove-Item (Join-Path $base '.output\GitHub更新监测列表.md.tmp') -Force -ErrorAction SilentlyContinue }
if (-not (Test-Path (Join-Path $base '.output'))) { New-Item -ItemType Directory -Force -Path (Join-Path $base '.output') | Out-Null }

# Fixture
$rows = @(
    [PSCustomObject]@{Id=1;Name='VS Code';Owner='microsoft';Repo='vscode';GitVer='v1.0.0';GitDate='2026-01-01';LocalVer='1.0.0';Flag='no'},
    [PSCustomObject]@{Id=2;Name='Linux';Owner='torvalds';Repo='linux';GitVer='v6.5.0';GitDate='2026-01-01';LocalVer='6.5.0';Flag='no'}
)
& (Join-Path $lib 'create-fixture.ps1') -OutputPath (Join-Path $base '.output\GitHub更新监测列表.md') -Rows $rows | Out-Null

# Save md-before
Copy-Item (Join-Path $base '.output\GitHub更新监测列表.md') (Join-Path $base 'md-before.md')
$shaBefore = (Get-FileHash (Join-Path $base 'md-before.md') -Algorithm SHA256).Hash
Set-Content -Path (Join-Path $base 'sha256-before.txt') -Value $shaBefore

# Phase 1: run step1 + step2 + step3 + step4 in child to generate result.json
$phase1Out = & pwsh -NoProfile -Command "`$env:GITHUB_VERSION_MONITOR_BASE='$base'; & '$lib\step1.ps1'; & '$lib\step2.ps1'; & '$lib\step3.ps1'; & '$lib\step4.ps1'" 2>&1
$phase1Out | Out-File (Join-Path $base 'phase1-output.txt') -Encoding UTF8
Write-Host "PHASE1_DONE|result_json=$(Test-Path (Join-Path $base '.monitor\result.json'))"

# Delete the lock from phase 1 (step4 does not release lock on success)
Remove-Item (Join-Path $base '.monitor\run.lock') -Force -ErrorAction SilentlyContinue

# Phase 2: pre-create the .tmp file as read-only (Set-Content will fail with UnauthorizedAccessException)
$tmpMdPath = Join-Path $base '.output\GitHub更新监测列表.md.tmp'
if (Test-Path $tmpMdPath) { Remove-Item $tmpMdPath -Force }
Set-Content -Path $tmpMdPath -Value 'BLOCKED' -Encoding UTF8
$fi = Get-Item $tmpMdPath
$fi.IsReadOnly = $true
Write-Host "TMP_MD_READONLY=$($fi.IsReadOnly)"

# Phase 3: run step1 (creates fresh lock) + step5-full in child (Set-Content will fail)
$phase2Out = & pwsh -NoProfile -Command "`$env:GITHUB_VERSION_MONITOR_BASE='$base'; & '$lib\step1.ps1'; & '$lib\step5-full.ps1'" 2>&1
$phase2Out | Out-File (Join-Path $base 'stdout.txt') -Encoding UTF8
@() | Out-File (Join-Path $base 'stderr.txt') -Encoding UTF8
Write-Host "PHASE2_DONE"

# Restore directory permissions
$dirItem = Get-Item $outputDir
$dirItem.Attributes = [System.IO.FileAttributes]::Normal
Write-Host "OUTPUT_DIR_READONLY_RESTORED=$($dirItem.Attributes -band [System.IO.FileAttributes]::ReadOnly)"

# Phase 4: verify
Copy-Item (Join-Path $base '.output\GitHub更新监测列表.md') (Join-Path $base 'md-after.md')
$shaAfter = (Get-FileHash (Join-Path $base 'md-after.md') -Algorithm SHA256).Hash
Set-Content -Path (Join-Path $base 'sha256-after.txt') -Value $shaAfter

$stdoutContent = Get-Content (Join-Path $base 'stdout.txt') -Raw
$hasSetContentError = $stdoutContent -match 'Set-Content' -or $stdoutContent -match 'is denied|UnauthorizedAccess|IOException'
$hasCommitOk = $stdoutContent -match 'COMMIT_OK\|'

Write-Host "SHA_BEFORE=$shaBefore"
Write-Host "SHA_AFTER=$shaAfter"
Write-Host "SHA_SAME=$($shaBefore -eq $shaAfter)"
Write-Host "HAS_SET_CONTENT_ERROR=$hasSetContentError"
Write-Host "HAS_COMMIT_OK=$hasCommitOk"
