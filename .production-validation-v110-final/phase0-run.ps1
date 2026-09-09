$ErrorActionPreference = 'Stop'
$root = 'd:\AI\Workspace\automatic\github-version-monitor'
$base = Join-Path $root '.production-validation-v110-final'

$startTime = Get-Date -Format o
Write-Host "PHASE0_START=$startTime"
Write-Host "ROOT=$root"
Write-Host "BASE=$base"

# Step 1: Create directory tree
$dirs = @(
    'lib',
    'T22',
    'T23',
    'T37',
    'T38-A',
    'T38-B',
    'T38-C',
    'T38-heartbeat',
    'T38-result-read',
    'T38-stats-items',
    'T39',
    'T43',
    'T46',
    'T02',
    'T04-PS7',
    'T04-PS5.1',
    'T05-PS7',
    'T05-PS5.1',
    'T08',
    'T14',
    'T15',
    'T16',
    'T17',
    'T18',
    'T19',
    'T26',
    'schema',
    'lock-concurrency',
    'lock-ownership',
    'lock-stale-alive',
    'lock-stale-dead',
    'runtime-error-contract',
    'process-kill',
    'invariant-verification',
    '.selfreview'
)

Write-Host ""
Write-Host "=== STEP 1: Create directory tree ==="
Write-Host "Target base: $base"
Write-Host "Forbidden to create: .monitor (dynamic), reuse .production-validation* (old)"
Write-Host ""

# Verify base does not already exist (clean-room)
if (Test-Path $base) {
    Write-Host "WARNING: $base already exists (may be from previous run or partial)"
} else {
    Write-Host "Base directory does not exist yet; creating fresh."
}

# Ensure base exists
if (-not (Test-Path $base)) {
    New-Item -ItemType Directory -Path $base -Force | Out-Null
    Write-Host "Created base: $base"
}

# Create each subdir
$created = @()
foreach ($d in $dirs) {
    $p = Join-Path $base $d
    if (Test-Path $p) {
        Write-Host "EXISTS: $d"
    } else {
        New-Item -ItemType Directory -Path $p -Force | Out-Null
        Write-Host "CREATED: $d"
    }
    $created += $d
}

Write-Host ""
Write-Host "Total directories created/ensured: $($created.Count)"

# Verify .monitor was NOT created (must be dynamic)
$monitorPath = Join-Path $base '.monitor'
if (Test-Path $monitorPath) {
    Write-Host "ERROR: .monitor should NOT be pre-created"
    exit 1
} else {
    Write-Host "OK: .monitor not pre-created (dynamic creation by Step 1)"
}

# Verify no reuse of old directories (informational check)
$oldDirs = @('.production-validation', '.production-validation-v17-final', '.production-validation-v18-final', '.production-validation-v19-final')
Write-Host ""
Write-Host "=== Old-directory reuse check (informational) ==="
foreach ($old in $oldDirs) {
    $op = Join-Path $root $old
    $exists = Test-Path $op
    Write-Host "Old dir '$old' exists in root: $exists (must NOT be reused)"
}

# Step 2: SHA256
Write-Host ""
Write-Host "=== STEP 2: Compute SHA256 ==="
$v19File = Join-Path $root 'SKILL-v1.9.md'
$v110File = Join-Path $root 'SKILL-v1.10.md'
$stateFile = Join-Path $root '.output\GitHub更新监测列表.md'

foreach ($f in @($v19File, $v110File, $stateFile)) {
    if (-not (Test-Path $f)) {
        Write-Host "ERROR: Missing input file: $f"
        exit 2
    }
}

$v19Hash = (Get-FileHash $v19File -Algorithm SHA256).Hash
$v110Hash = (Get-FileHash $v110File -Algorithm SHA256).Hash
$stateHash = (Get-FileHash $stateFile -Algorithm SHA256).Hash

Write-Host "v19.sha256:   $v19Hash  SKILL-v1.9.md"
Write-Host "v110.sha256:  $v110Hash  SKILL-v1.10.md"
Write-Host "state.sha256: $stateHash  .output/GitHub更新监测列表.md"

Set-Content -Path (Join-Path $base 'v19.sha256')   -Value "$v19Hash  SKILL-v1.9.md"                    -Encoding UTF8
Set-Content -Path (Join-Path $base 'v110.sha256')  -Value "$v110Hash  SKILL-v1.10.md"                   -Encoding UTF8
Set-Content -Path (Join-Path $base 'state.sha256') -Value "$stateHash  .output/GitHub更新监测列表.md"    -Encoding UTF8

Write-Host "SHA256 files written."

# Step 3: git add SKILL-v1.10.md
Write-Host ""
Write-Host "=== STEP 3: git tracking ==="
Set-Location $root
$lsFiles = & git ls-files SKILL-v1.10.md 2>&1
Write-Host "git ls-files SKILL-v1.10.md => '$lsFiles'"

if ([string]::IsNullOrWhiteSpace($lsFiles)) {
    Write-Host "SKILL-v1.10.md is untracked; running git add..."
    & git add SKILL-v1.10.md
    $addExit = $LASTEXITCODE
    Write-Host "git add exit code: $addExit"
    if ($addExit -ne 0) {
        Write-Host "ERROR: git add failed"
        exit 3
    }
} else {
    Write-Host "SKILL-v1.10.md already tracked by git."
}

$statusShort = & git status --short SKILL-v1.10.md 2>&1
Write-Host "git status --short SKILL-v1.10.md => '$statusShort'"

$endTime = Get-Date -Format o
Write-Host ""
Write-Host "PHASE0_END=$endTime"
Write-Host "PHASE0_STATUS=completed"
