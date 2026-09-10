$ErrorActionPreference = 'Stop'
$repoRoot = 'D:\AI\Workspace\automatic\github-version-monitor'
Set-Location $repoRoot

Write-Output "=== Before amend2: git status --porcelain ==="
& git status --porcelain
Write-Output ""

Write-Output "=== Add updated files ==="
$addFiles = @(
    '.production-validation-v112-final/phase-progress.json',
    '.production-validation-v112-final/phase8-appendixB.md',
    '.production-validation-v112-final/phase8-amend.ps1',
    '.production-validation-v112-final/phase8-amend2.ps1'
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
& git diff --check --cached 2>&1 | ForEach-Object { Write-Output $_ }
Write-Output ("exit=" + $LASTEXITCODE)
Write-Output ""

Write-Output "=== git commit --amend --no-edit ==="
& git commit --amend --no-edit 2>&1 | ForEach-Object { Write-Output $_ }
Write-Output ""

Write-Output "=== git log --oneline -1 (final) ==="
& git log --oneline -1
Write-Output ""

Write-Output "=== git rev-parse HEAD (final full SHA) ==="
$finalSha = & git rev-parse HEAD
Write-Output $finalSha
Write-Output ""

Write-Output "=== git show --stat HEAD | header only ==="
& git show --stat HEAD --no-patch
Write-Output ""

Write-Output "=== git status --porcelain final ==="
& git status --porcelain
Write-Output ""

Write-Output "=== post-amend SHA256 recheck ==="
foreach ($f in @('SKILL-v1.11.md','SKILL-v1.12.md','.output\GitHub更新监测列表.md')) {
    $h = (Get-FileHash -Algorithm SHA256 -LiteralPath $f).Hash
    Write-Output ("SHA256 " + $f + " = " + $h)
}
Write-Output ""

Write-Output "=== END AMEND2 (final HEAD: " + $finalSha + ") ==="
