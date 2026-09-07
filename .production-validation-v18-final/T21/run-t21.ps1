# T21: review 原子性 — Move-Item result.review.tmp -> result.json 失败时，旧 result.json 不被损坏
$ErrorActionPreference = 'Continue'
$base = 'D:\AI\Workspace\automatic\github-version-monitor\.production-validation-v18-final\T21'
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

# Phase 1: run step1 + step2 in child to generate result.json (with lock)
$phase1Out = & pwsh -NoProfile -Command "`$env:GITHUB_VERSION_MONITOR_BASE='$base'; & '$lib\step1.ps1'; & '$lib\step2.ps1'" 2>&1
$phase1Out | Out-File (Join-Path $base 'phase1-output.txt') -Encoding UTF8
Write-Host "PHASE1_DONE|result_json=$(Test-Path (Join-Path $base '.monitor\result.json'))"

# Save result-before
$resultPath = Join-Path $base '.monitor\result.json'
Copy-Item $resultPath (Join-Path $base 'result-before.json')
$shaBefore = (Get-FileHash (Join-Path $base 'result-before.json') -Algorithm SHA256).Hash
Set-Content -Path (Join-Path $base 'sha256-before.txt') -Value $shaBefore

# Delete the lock from phase 1 (step2 does not release lock on success)
Remove-Item (Join-Path $base '.monitor\run.lock') -Force -ErrorAction SilentlyContinue

# Phase 2: lock result.json via lock-holder process (FileShare.Read allows reads but blocks writes/Move-Item)
$lockHolderScript = @'
$ErrorActionPreference = 'Stop'
$path = Join-Path $env:GITHUB_VERSION_MONITOR_BASE '.monitor\result.json'
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

# Phase 3: run step1 (creates fresh lock) + step4 in child (step4 will fail Move-Item)
$phase2Out = & pwsh -NoProfile -Command "`$env:GITHUB_VERSION_MONITOR_BASE='$base'; & '$lib\step1.ps1'; & '$lib\step4.ps1'" 2>&1
$phase2Out | Out-File (Join-Path $base 'stdout.txt') -Encoding UTF8
@() | Out-File (Join-Path $base 'stderr.txt') -Encoding UTF8
Write-Host "PHASE2_DONE"

# Kill lock-holder
if (-not $lockProc.HasExited) { Stop-Process -Id $lockProc.Id -Force -ErrorAction SilentlyContinue; $lockProc.WaitForExit(5000) | Out-Null }

# Phase 4: verify
$resultAfter = Join-Path $base 'result-after.json'
Copy-Item $resultPath $resultAfter
$shaAfter = (Get-FileHash $resultAfter -Algorithm SHA256).Hash
Set-Content -Path (Join-Path $base 'sha256-after.txt') -Value $shaAfter

$tmpResult = Join-Path $base '.monitor\result.review.tmp'
$lockPath = Join-Path $base '.monitor\run.lock'

$stdoutContent = Get-Content (Join-Path $base 'stdout.txt') -Raw
$hasReviewWriteError = $stdoutContent -match 'REVIEW_WRITE_ERROR\|review 原子替换失败'
$tmpExists = Test-Path $tmpResult
$lockStillPresent = Test-Path $lockPath

Write-Host "SHA_BEFORE=$shaBefore"
Write-Host "SHA_AFTER=$shaAfter"
Write-Host "SHA_SAME=$($shaBefore -eq $shaAfter)"
Write-Host "HAS_REVIEW_WRITE_ERROR=$hasReviewWriteError"
Write-Host "TMP_EXISTS=$tmpExists"
Write-Host "LOCK_STILL_PRESENT=$lockStillPresent"
