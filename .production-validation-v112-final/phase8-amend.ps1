$ErrorActionPreference = 'Stop'
$repoRoot = 'D:\AI\Workspace\automatic\github-version-monitor'
Set-Location $repoRoot

Write-Output "=== Before amend: git status --porcelain ==="
& git status --porcelain
Write-Output ""

Write-Output "=== Add amended files ==="
$addFiles = @(
    '.production-validation-v112-final/phase-progress.json',
    '.production-validation-v112-final/phase8-appendixB.md',
    '.production-validation-v112-final/phase8-git.ps1',
    'production-validation-report-v112-final.md'
)
foreach ($f in $addFiles) {
    Write-Output ("git add -A -- " + $f)
    & git add -A -- $f 2>&1 | ForEach-Object { Write-Output $_ }
}
Write-Output ""

Write-Output "=== git status --porcelain after add ==="
& git status --porcelain
Write-Output ""

Write-Output "=== git diff --cached --stat ==="
& git diff --cached --stat | ForEach-Object { Write-Output $_ }
Write-Output ""

Write-Output "=== git diff --check --cached ==="
$checkOut = & git diff --check --cached 2>&1
$checkOut | ForEach-Object { Write-Output $_ }
Write-Output "exit=$LASTEXITCODE"
Write-Output ""

Write-Output "=== git commit --amend --no-edit ==="
& git commit --amend --no-edit 2>&1 | ForEach-Object { Write-Output $_ }
Write-Output ""

Write-Output "=== git log --oneline -1 (new) ==="
& git log --oneline -1
Write-Output ""

Write-Output "=== git rev-parse HEAD (new full SHA) ==="
& git rev-parse HEAD
Write-Output ""

Write-Output "=== git show --stat HEAD | head ==="
& git show --stat HEAD | Select-Object -First 30 | ForEach-Object { Write-Output $_ }
Write-Output ""

Write-Output "=== git status --porcelain final ==="
& git status --porcelain
Write-Output ""

Write-Output "=== END AMEND ==="
