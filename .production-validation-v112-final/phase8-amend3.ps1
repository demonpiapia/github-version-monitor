$ErrorActionPreference = 'Stop'
$repoRoot = 'D:\AI\Workspace\automatic\github-version-monitor'
Set-Location $repoRoot

Write-Output "=== Before amend3: git status --porcelain ==="
& git status --porcelain
Write-Output ""

Write-Output "=== Add updated files (only final JSON + AppendixB) ==="
$addFiles = @(
    '.production-validation-v112-final/phase-progress.json',
    '.production-validation-v112-final/phase8-appendixB.md'
)
foreach ($f in $addFiles) {
    Write-Output ("git add -A -- " + $f)
    & git add -A -- $f 2>&1 | ForEach-Object { Write-Output $_ }
}
Write-Output ""

Write-Output "=== git diff --cached --stat ==="
& git diff --cached --stat | ForEach-Object { Write-Output $_ }
Write-Output ""

Write-Output "=== git diff --check --cached ==="
& git diff --check --cached 2>&1 | ForEach-Object { Write-Output $_ }
Write-Output ("exit=" + $LASTEXITCODE)
Write-Output ""

Write-Output "=== git commit --amend --no-edit (FINAL) ==="
& git commit --amend --no-edit 2>&1 | Select-Object -First 6 | ForEach-Object { Write-Output $_ }
Write-Output ""

Write-Output "=== git log --oneline -1 (FINAL) ==="
& git log --oneline -1
Write-Output ""

Write-Output "=== git rev-parse HEAD (FINAL FULL SHA) ==="
$finalSha = & git rev-parse HEAD
Write-Output $finalSha
Write-Output ""

Write-Output "=== git show --stat HEAD --no-patch ==="
& git show --stat HEAD --no-patch | ForEach-Object { Write-Output $_ }
Write-Output ""

Write-Output "=== git status --porcelain FINAL ==="
& git status --porcelain
Write-Output ""

Write-Output "=== Final SHA256 recheck ==="
foreach ($f in @('SKILL-v1.11.md','SKILL-v1.12.md','.output\GitHub更新监测列表.md')) {
    $h = (Get-FileHash -Algorithm SHA256 -LiteralPath $f).Hash
    Write-Output ("SHA256 " + $f + " = " + $h)
}
Write-Output ""

Write-Output "=== END AMEND3 (FINAL HEAD: $finalSha) ==="
