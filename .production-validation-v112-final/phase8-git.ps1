$ErrorActionPreference = 'Stop'
$repoRoot = 'D:\AI\Workspace\automatic\github-version-monitor'
Set-Location $repoRoot

# Explicit file list to git add (per Prompt / user task scope)
$files = @(
    'SKILL-v1.12.md',
    '.GPT/v1.12 最小修改与定向验证 Prompt.md',
    '.production-validation-v112-final',
    '.exec-plan/exec-plan-v1.12-a.md',
    '.exec-plan/exec-plan-v1.12-a-trae-review.md',
    '.exec-plan/exec-plan-v1.12-b.md',
    '.exec-plan/exec-plan-v1.12-b-codebuddy-review.md',
    '.exec-plan/exec-plan-v1.12-c.md',
    '.exec-plan/exec-plan-v1.12-c-trae-review.md',
    '.exec-plan/exec-plan-v1.12-d.md',
    'production-validation-report-v112-final.md',
    'audit-attempt1-fabricated'
)

# Explicit EXCLUSIONS (verify they remain untracked after add):
# - .Template/通用执行计划制定补充prompt.md (Phase 0 modification, out of scope)
# - .exec-plan/.backups/ (internal backup)
# - .exec-plan/phase0-exec.ps1 (internal Phase 0 tool)
# - .exec-plan/phase0-runner.ps1 (internal Phase 0 tool)
# - .production-validation-v112-final/lib/*.备份.* (internal backups)
# - .production-validation-v112-final/lib/mock-invoke-restmethod.ps1.bak-* (internal backups)
# - ' (stray empty file)

Write-Output "=== STEP 1: git status BEFORE git add ==="
& git status --porcelain
Write-Output ""

Write-Output "=== STEP 2: git add explicit file list ==="
foreach ($f in $files) {
    Write-Output ("git add -A -- " + $f)
    & git add -A -- $f 2>&1 | ForEach-Object { Write-Output $_ }
}
Write-Output ""

Write-Output "=== STEP 3: git status AFTER git add (staged + unstaged) ==="
& git status --porcelain
Write-Output ""

Write-Output "=== STEP 4: git status --short with staged markers ==="
& git status --short
Write-Output ""

Write-Output "=== STEP 5: verify EXCLUSIONS remain untracked ==="
$excludes = @(
    '.Template/通用执行计划制定补充prompt.md',
    '.exec-plan/.backups',
    '.exec-plan/phase0-exec.ps1',
    '.exec-plan/phase0-runner.ps1'
)
foreach ($x in $excludes) {
    $st = (& git status --porcelain -- "$x").Trim()
    Write-Output ("EXCLUDED " + $x + " -> status='" + $st + "'")
}
# stray '' file
$stray = (& git status --porcelain -- "'").Trim()
Write-Output ("EXCLUDED stray-' -> status='" + $stray + "'")
# internal backups in lib
$libBackups = & git status --porcelain -- .production-validation-v112-final/lib
Write-Output "=== lib/ status (should be limited to non-backup files) ==="
$libBackups | ForEach-Object { Write-Output $_ }
Write-Output ""

Write-Output "=== STEP 6: git diff --cached --stat (staged summary) ==="
& git diff --cached --stat | ForEach-Object { Write-Output $_ }
Write-Output ""

Write-Output "=== STEP 7: git diff --check --cached ==="
& git diff --check --cached 2>&1 | ForEach-Object { Write-Output $_ }
Write-Output ""

Write-Output "=== STEP 8: git commit ==="
$commitMsg = 'feat: refine skill runtime contract and housekeeping failure handling'
$commitOutput = & git commit -m $commitMsg 2>&1
$commitOutput | ForEach-Object { Write-Output $_ }
Write-Output ""

Write-Output "=== STEP 9: git log --oneline -1 ==="
& git log --oneline -1
Write-Output ""

Write-Output "=== STEP 10: git rev-parse HEAD (full commit SHA) ==="
& git rev-parse HEAD
Write-Output ""

Write-Output "=== STEP 11: git show --stat HEAD ==="
& git show --stat HEAD | ForEach-Object { Write-Output $_ }
Write-Output ""

Write-Output "=== STEP 12: git status --porcelain AFTER commit ==="
& git status --porcelain
Write-Output ""

Write-Output "=== STEP 13: Final SHA256 verification (post-commit) ==="
foreach ($f in @('SKILL-v1.11.md','SKILL-v1.12.md','.output\GitHub更新监测列表.md')) {
    $h = (Get-FileHash -Algorithm SHA256 -LiteralPath $f).Hash
    Write-Output ("SHA256 " + $f + " = " + $h)
}
Write-Output ""

Write-Output "=== END ==="
