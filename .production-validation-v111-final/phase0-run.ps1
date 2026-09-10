#Requires -Version 7.0
# phase0-run.ps1 — SKILL-v1.11 Phase 0: Clean-Room + Git/SHA256 + 被测对象纳入 git
# 执行方式（后台静默）:
#   pwsh -NoProfile -NonInteractive -File .\.production-validation-v111-final\phase0-run.ps1 1> .\.production-validation-v111-final\phase0-stdout.txt 2> .\.production-validation-v111-final\phase0-stderr.txt
# 范围声明: 仅 Phase 0。不修改 SKILL-v1.10.md / SKILL-v1.11.md / .output/GitHub更新监测列表.md / .GPT prompt / task-tracker.md。
#          不创建 .monitor/。不复制旧 validation 目录产物。不 git commit。

$ErrorActionPreference = 'Stop'
$phase0Failed = $false

$root = 'D:\AI\Workspace\automatic\github-version-monitor'
$base = Join-Path $root '.production-validation-v111-final'
$startTime = Get-Date

Write-Output ('[phase0] start_time=' + $startTime.ToString('o'))
Write-Output ('[phase0] pwsh=' + $PSVersionTable.PSVersion.ToString())
Write-Output ('[phase0] root=' + $root)
Write-Output ('[phase0] base=' + $base)
Set-Location $root

# ============================================================
# STEP 1: 创建 clean-room 目录树（严格清单，禁止 .monitor/）
# ============================================================
Write-Output ''
Write-Output '=== STEP1: create clean-room directory tree ==='
$dirs = @(
  'lib', 'T22', 'T23', 'T37',
  'T38-A', 'T38-B', 'T38-C', 'T38-heartbeat', 'T38-result-read', 'T38-stats-items',
  'T39', 'T43', 'T46',
  'T04-PS7', 'T04-PS5.1', 'T05-PS5.1',
  'T18', 'T26', 'runtime-artifact',
  'lock-concurrency', 'lock-ownership', 'lock-stale-alive', 'lock-stale-dead',
  'process-kill', 'audit', '.selfreview'
)

if (-not (Test-Path $base)) {
  New-Item -ItemType Directory -Path $base -Force | Out-Null
  Write-Output '[dir] base created'
} else {
  Write-Output '[dir] base already exists'
}

foreach ($d in $dirs) {
  $p = Join-Path $base $d
  if (Test-Path $p) {
    Write-Output ('[dir] exists  ' + $d)
  } else {
    New-Item -ItemType Directory -Path $p -Force | Out-Null
    Write-Output ('[dir] created ' + $d)
  }
}
Write-Output ('[dir] requested_count=' + $dirs.Count)

# .monitor 禁止预创建断言（Prompt §24 / 计划 §3 第 12 条）
$monitorPath = Join-Path $base '.monitor'
$monitorExists = Test-Path $monitorPath
Write-Output ('[assert] .monitor pre-created=' + $monitorExists)
if ($monitorExists) {
  Write-Output '[assert] FAIL: .monitor must NOT be pre-created (Prompt §24)'
  $phase0Failed = $true
}

# 目录清单核对
Write-Output ''
Write-Output '=== STEP1.1: directory listing vs expected ==='
$actual = @(Get-ChildItem -Directory $base | Select-Object -ExpandProperty Name | Sort-Object)
Write-Output ('[actual] count=' + $actual.Count)
foreach ($a in $actual) { Write-Output ('[actual] ' + $a) }
$expected = @($dirs | Sort-Object)
$missing = @($expected | Where-Object { $_ -notin $actual })
$extra   = @($actual   | Where-Object { $_ -notin $expected })
Write-Output ('[diff] missing_count=' + $missing.Count)
foreach ($m in $missing) { Write-Output ('[diff] MISSING ' + $m) }
Write-Output ('[diff] extra_count=' + $extra.Count)
foreach ($e in $extra)   { Write-Output ('[diff] EXTRA   ' + $e) }
if ($missing.Count -eq 0 -and $extra.Count -eq 0) {
  Write-Output '[diff] RESULT=OK (actual == expected, 26 dirs, no .monitor)'
}

# ============================================================
# STEP 2: 旧 validation 目录存在性实测（Prompt §1 禁复用）
# ============================================================
Write-Output ''
Write-Output '=== STEP2: old validation dir existence (Test-Path) ==='
$oldDirs = @(
  '.production-validation-v110-final',
  '.production-validation-v19-final',
  '.production-validation-v17-final',
  '.production-validation-v18-final'
)
foreach ($o in $oldDirs) {
  $p = Join-Path $root $o
  Write-Output ('[old] ' + $o + ' exists=' + (Test-Path $p))
}
Write-Output '[old] OLD_EVIDENCE_USED_AS_CURRENT_PASS=NO (Phase 0 仅创建空目录，未从旧目录复制任何 fixture/stdout/result)'

# ============================================================
# STEP 3: 3 个 SHA256 基线（Prompt §3）
# 保存格式: <SHA256 值>  <相对路径>
# ============================================================
Write-Output ''
Write-Output '=== STEP3: SHA256 baseline ==='
$targets = @(
  @{ Out='v110.sha256';  Abs='.\SKILL-v1.10.md';                  Rel='SKILL-v1.10.md' },
  @{ Out='v111.sha256';  Abs='.\SKILL-v1.11.md';                  Rel='SKILL-v1.11.md' },
  @{ Out='state.sha256'; Abs='.\.output\GitHub更新监测列表.md';    Rel='.output/GitHub更新监测列表.md' }
)
foreach ($t in $targets) {
  $absPath = Join-Path $root $t.Abs
  if (-not (Test-Path $absPath)) {
    Write-Output ('[sha256] FAIL: source missing: ' + $t.Abs)
    $phase0Failed = $true
    continue
  }
  $h = (Get-FileHash $absPath -Algorithm SHA256).Hash
  $line = $h + '  ' + $t.Rel
  Set-Content -Path (Join-Path $base $t.Out) -Value $line -Encoding UTF8
  Write-Output ('[sha256] ' + $line)
}

Write-Output ''
Write-Output '=== STEP3.1: sha256 file existence + non-empty verify ==='
foreach ($t in $targets) {
  $f = Join-Path $base $t.Out
  if (-not (Test-Path $f)) {
    Write-Error ('[sha256-verify] FAIL: not found: ' + $t.Out)
    continue
  }
  $sz = (Get-Item $f).Length
  $content = (Get-Content $f -Raw).Trim()
  Write-Output ('[sha256-verify] ' + $t.Out + ' size=' + $sz + ' content="' + $content + '"')
  if ($sz -le 0 -or $content.Length -eq 0) {
    Write-Output ('[sha256-verify] FAIL: empty: ' + $t.Out)
    $phase0Failed = $true
  }
}

# ============================================================
# STEP 4: 抽查 T22 / T37 / T38-A 为空
# ============================================================
Write-Output ''
Write-Output '=== STEP4: spot check subdirs empty ==='
foreach ($d in @('T22', 'T37', 'T38-A')) {
  $p = Join-Path $base $d
  $items = @(Get-ChildItem -Force $p)
  Write-Output ('[spot] ' + $d + ' item_count=' + $items.Count)
  foreach ($i in $items) { Write-Output ('[spot]   ' + $i.Name) }
}

# ============================================================
# STEP 5: 被测对象与事实源纳入 git（Prompt §2 + §39）
# ============================================================
Write-Output ''
Write-Output '=== STEP5: git tracking status before add ==='
# 注: git 默认 core.quotepath=true 会把中文/非 ASCII 路径输出为 "\" + 八进制转义 形式，
#     导致字符串精确比较失效。此处显式 core.quotepath=false 以取得可读路径用于校验。
function Invoke-Git {
  param([Parameter(ValueFromRemainingArguments=$true)]$GitArgs)
  & git -c core.quotepath=false @GitArgs
}

$lsOut = @(Invoke-Git ls-files SKILL-v1.11.md)
Write-Output ('[git] ls-files SKILL-v1.11.md => "' + ($lsOut -join '') + '" (empty = untracked)')
$lsOut2 = @(Invoke-Git ls-files '.GPT/Production Validation Prompt — SKILL-v1.11 Targeted Validation.md')
Write-Output ('[git] ls-files .GPT prompt => "' + ($lsOut2 -join '') + '" (empty = untracked)')

Write-Output ''
Write-Output '=== STEP5.1: git add (only 2 files) ==='
Invoke-Git add SKILL-v1.11.md ".GPT/Production Validation Prompt — SKILL-v1.11 Targeted Validation.md"
Write-Output ('[git] add exit_code=' + $LASTEXITCODE)

Write-Output ''
Write-Output '=== STEP5.2: git status --short ==='
$st = @(Invoke-Git status --short)
foreach ($s in $st) { Write-Output ('[status] ' + $s) }

Write-Output ''
Write-Output '=== STEP5.3: staged verification ==='
$staged = @(Invoke-Git diff --cached --name-only)
Write-Output ('[staged] count=' + $staged.Count)
foreach ($s in $staged) { Write-Output ('[staged] ' + $s) }
$twoStaged = ($staged -contains 'SKILL-v1.11.md') -and
             ($staged -contains '.GPT/Production Validation Prompt — SKILL-v1.11 Targeted Validation.md')
Write-Output ('[staged] both_target_files_staged=' + $twoStaged)
if (-not $twoStaged) {
  Write-Output '[staged] FAIL: expected both target files staged'
  $phase0Failed = $true
}

# ============================================================
# STEP 6: 禁止项断言（无 commit / 无 .monitor / 被测对象未修改）
# ============================================================
Write-Output ''
Write-Output '=== STEP6: prohibition assertions ==='
Write-Output ('[git] HEAD=' + (git rev-parse --short HEAD))
Write-Output '[git] commit NOT executed (commit belongs to Phase 13)'
Write-Output ('[assert] .monitor pre-created=' + (Test-Path $monitorPath))
$modCheck = @(Invoke-Git status --short SKILL-v1.10.md SKILL-v1.11.md '.GPT/Production Validation Prompt — SKILL-v1.11 Targeted Validation.md' '.output/GitHub更新监测列表.md')
foreach ($m in $modCheck) { Write-Output ('[assert] ' + $m) }

$endTime = Get-Date
Write-Output ''
Write-Output ('[phase0] end_time=' + $endTime.ToString('o'))
Write-Output ('[phase0] duration_sec=' + [math]::Round(($endTime - $startTime).TotalSeconds, 3))
if ($phase0Failed) {
  Write-Output '[phase0] RESULT=FAILED (see FAIL lines above)'
} else {
  Write-Output '[phase0] RESULT=COMPLETED'
}
Write-Output '[phase0] DONE'
