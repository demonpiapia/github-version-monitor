# T23: md 替换失败 — Move-Item 替换主 md 失败时，主 md 不变，临时文件被清理
$ErrorActionPreference = 'Continue'
$base = 'D:\AI\Workspace\automatic\github-version-monitor\.production-validation-v18-final\T23'
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

# Phase 2: lock main md file via lock-holder process (FileShare.Read allows reads/copy but blocks Move-Item)
$mdPath = Join-Path $base '.output\GitHub更新监测列表.md'
$lockHolderScript = @'
$ErrorActionPreference = 'Stop'
$path = Join-Path $env:GITHUB_VERSION_MONITOR_BASE '.output\GitHub更新监测列表.md'
$fs = [System.IO.File]::Open($path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read)
Write-Output "LOCKED|PID=$PID"
Start-Sleep -Seconds 300
$fs.Close()
'@
$lockHolderPath = Join-Path $base 'lock-holder.ps1'
Set-Content -Path $lockHolderPath -Value $lockHolderScript -Encoding UTF8

$lockProc = Start-Process pwsh -ArgumentList '-NoProfile', '-File', $lockHolderPath -PassThru -RedirectStandardOutput (Join-Path $base 'lock-holder-stdout.txt') -RedirectStandardError (Join-Path $base 'lock-holder-stderr.txt')

# Wait for lock-holder to acquire the lock
$lockAcquired = $false
for ($i = 0; $i -lt 50; $i++) {
    Start-Sleep -Milliseconds 100
    $lockHolderStdout = Join-Path $base 'lock-holder-stdout.txt'
    if (Test-Path $lockHolderStdout) {
        $content = Get-Content $lockHolderStdout -Raw -ErrorAction SilentlyContinue
        if ($content -match 'LOCKED\|') { $lockAcquired = $true; break }
    }
}
Write-Host "LOCK_ACQUIRED=$lockAcquired"
if (-not $lockAcquired) { Write-Host "FATAL: lock-holder did not acquire lock"; exit 1 }

# Phase 3: manually create lock (step1's Copy-Item would fail since md is locked), then run step5-full
$lockPath = Join-Path $base '.monitor\run.lock'
$nowUtc = [DateTimeOffset]::UtcNow.ToString('o')
Set-Content -Path $lockPath -Value ("pid={0};start={1};step=1;beat={2}" -f $PID, $nowUtc, $nowUtc)
Write-Host "LOCK_CREATED_MANUALLY|pid=$PID"

$phase2Out = & pwsh -NoProfile -Command "`$env:GITHUB_VERSION_MONITOR_BASE='$base'; & '$lib\step5-full.ps1'" 2>&1
$phase2Out | Out-File (Join-Path $base 'stdout.txt') -Encoding UTF8
@() | Out-File (Join-Path $base 'stderr.txt') -Encoding UTF8
Write-Host "PHASE2_DONE"

# Kill lock-holder
if (-not $lockProc.HasExited) { Stop-Process -Id $lockProc.Id -Force -ErrorAction SilentlyContinue; $lockProc.WaitForExit(5000) | Out-Null }

# Phase 4: verify
Copy-Item $mdPath (Join-Path $base 'md-after.md')
$shaAfter = (Get-FileHash (Join-Path $base 'md-after.md') -Algorithm SHA256).Hash
Set-Content -Path (Join-Path $base 'sha256-after.txt') -Value $shaAfter

$tmpMdPath = Join-Path $base '.output\GitHub更新监测列表.md.tmp'
$tmpExists = Test-Path $tmpMdPath

$stdoutContent = Get-Content (Join-Path $base 'stdout.txt') -Raw
$hasCommitOk = $stdoutContent -match 'COMMIT_OK\|'
$hasMoveError = $stdoutContent -match 'Move-Item' -or $stdoutContent -match 'IOException|IOException|is being used' -or $stdoutContent -match 'denied'

Write-Host "SHA_BEFORE=$shaBefore"
Write-Host "SHA_AFTER=$shaAfter"
Write-Host "SHA_SAME=$($shaBefore -eq $shaAfter)"
Write-Host "TMP_EXISTS=$tmpExists"
Write-Host "HAS_COMMIT_OK=$hasCommitOk"
Write-Host "HAS_MOVE_ERROR=$hasMoveError"
