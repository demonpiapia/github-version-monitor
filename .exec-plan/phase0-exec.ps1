$ErrorActionPreference = 'Continue'
# Encoding declaration (user rule): normalize console + PS output stream to UTF8.
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$base = 'd:\AI\Workspace\automatic\github-version-monitor'
$root = Join-Path $base '.production-validation-v112-final'
$stdoutFile = Join-Path $root 'phase0-stdout.txt'
$stderrFile = Join-Path $root 'phase0-stderr.txt'

# Pre-create root for evidence redirection
if (-not (Test-Path $root)) {
    New-Item -ItemType Directory -Path $root -Force | Out-Null
}

$startTimeUtc = [DateTimeOffset]::UtcNow
$startTimeLocal = $startTimeUtc.ToOffset([TimeSpan]::FromHours(8)).ToString('yyyy-MM-ddTHH:mm:ss.fffzzz')

# ---------- Redirect streams for the actual execution block ----------
# stdout -> phase0-stdout.txt (UTF8), stderr -> phase0-stderr.txt (UTF8)
# Both are captured by the wrapper invocation's *>&1 > and 2> redirections.

# --- STEP 1: PS7 version ---
Write-Output "========== [STEP 1] PS7 version check =========="
Write-Output ("PS_VERSION|" + $PSVersionTable.PSVersion.ToString())
Write-Output ("PS_MAJOR|" + $PSVersionTable.PSVersion.Major)
$major = [int]$PSVersionTable.PSVersion.Major
if ($major -lt 7) {
    Write-Output "RUNTIME_ERROR|PowerShell 7.x required"
    exit 1
}
Write-Output "PS7_CHECK|PASS"
Write-Output ""

# --- STEP 3: ENV_CHECK (read-only probes) ---
Write-Output "========== [STEP 3] ENV_CHECK (read-only) =========="
$hasToken = [bool]$env:GITHUB_TOKEN
if (-not $hasToken) {
    $envFile = Join-Path $base '.env'
    if (Test-Path $envFile) {
        $envContent = Get-Content $envFile -Raw -ErrorAction SilentlyContinue
        $hasToken = [bool]($envContent -match 'GITHUB_TOKEN')
    }
}
Write-Output ("ENV_CHECK|token_available=" + $hasToken)

try {
    $resp = Invoke-WebRequest 'https://api.github.com' -TimeoutSec 5
    Write-Output 'ENV_CHECK|network_github=ok'
} catch {
    $errMsg = $_.Exception.Message
    if ($null -ne $errMsg -and $errMsg.Length -gt 200) { $errMsg = $errMsg.Substring(0,200) }
    Write-Output ("ENV_CHECK|network_github=failed:" + $errMsg)
}
Write-Output ""

# --- STEP 4: Create directory tree (9 subdirectories) ---
Write-Output "========== [STEP 4] Create directory tree =========="
$dirs = @('lib','T1-PS7','T2-success','T3-api-failure','T4-write-failure','T5-housekeeping','T6-final-status','audit','.selfreview')
foreach ($d in $dirs) {
    $full = Join-Path $root $d
    if (-not (Test-Path $full)) {
        New-Item -ItemType Directory -Path $full -Force | Out-Null
        Write-Output ("DIR_CREATED|" + $d)
    } else {
        Write-Output ("DIR_EXISTS|" + $d)
    }
}
# Verify .monitor/ is NOT present
$monitorCheck = Test-Path (Join-Path $root '.monitor')
Write-Output ("MONITOR_DIR_PRESENT=" + $monitorCheck)
if ($monitorCheck) { Write-Output "RUNTIME_ERROR|.monitor/ must not be pre-created" }
Write-Output ""

# --- STEP 5: Compute 2 SHA256 (v111 + state) ---
Write-Output "========== [STEP 5] SHA256 (2 files; v112 deferred to Phase 1) =========="
$skillPath = Join-Path $base 'SKILL-v1.11.md'
$statePath = Join-Path $base (Join-Path '.output' 'GitHub更新监测列表.md')

if (-not (Test-Path $skillPath)) {
    Write-Output ("RUNTIME_ERROR|Skill file missing: " + $skillPath)
} else {
    $h1 = Get-FileHash $skillPath -Algorithm SHA256
    Write-Output ("SHA256|v111|" + $h1.Hash)
    Set-Content -Path (Join-Path $root 'v111.sha256') -Value $h1.Hash -Encoding UTF8 -NoNewline
    Write-Output "SHA256_WRITTEN|v111.sha256"
}
if (-not (Test-Path $statePath)) {
    Write-Output ("RUNTIME_ERROR|State file missing: " + $statePath)
} else {
    $h2 = Get-FileHash $statePath -Algorithm SHA256
    Write-Output ("SHA256|state|" + $h2.Hash)
    Set-Content -Path (Join-Path $root 'state.sha256') -Value $h2.Hash -Encoding UTF8 -NoNewline
    Write-Output "SHA256_WRITTEN|state.sha256"
}
Write-Output ""

# --- STEP 6: git status + git diff (baseline; no git add) ---
Write-Output "========== [STEP 6] git status + git diff (no git add per B5) =========="
Write-Output "---- git rev-parse --is-inside-work-tree ----"
try {
    $inside = (& git rev-parse --is-inside-work-tree 2>&1) | Out-String
    Write-Output $inside.TrimEnd()
} catch {
    Write-Output ("GIT_ERROR|" + $_.Exception.Message)
}
Write-Output "---- git HEAD ----"
try {
    $head = (& git rev-parse HEAD 2>&1) | Out-String
    Write-Output $head.TrimEnd()
} catch {
    Write-Output ("GIT_ERROR|" + $_.Exception.Message)
}
Write-Output "---- git status --porcelain=v1 ----"
try {
    $st = (& git status --porcelain=v1 2>&1) | Out-String
    Write-Output $st.TrimEnd()
} catch {
    Write-Output ("GIT_ERROR|" + $_.Exception.Message)
}
Write-Output "---- git status -sb (branch) ----"
try {
    $stb = (& git status -sb 2>&1) | Out-String
    Write-Output $stb.TrimEnd()
} catch {
    Write-Output ("GIT_ERROR|" + $_.Exception.Message)
}
Write-Output "---- git diff --stat HEAD ----"
try {
    $ds = (& git diff --stat HEAD 2>&1) | Out-String
    Write-Output $ds.TrimEnd()
} catch {
    Write-Output ("GIT_ERROR|" + $_.Exception.Message)
}
Write-Output "---- git diff HEAD (full) ----"
try {
    $df = (& git diff HEAD 2>&1) | Out-String
    if ([string]::IsNullOrWhiteSpace($df)) {
        Write-Output "(empty diff)"
    } else {
        Write-Output $df.TrimEnd()
    }
} catch {
    Write-Output ("GIT_ERROR|" + $_.Exception.Message)
}
Write-Output ""

# --- STEP 7: Directory tree snapshot ---
Write-Output "========== [STEP 7] Final directory snapshot =========="
Get-ChildItem -Force $root | ForEach-Object {
    if ($_.PSIsContainer) { Write-Output ("[DIR]  " + $_.Name) }
    else                  { Write-Output ("[FILE] " + $_.Name + " (" + $_.Length + " bytes)") }
}

$endTimeUtc = [DateTimeOffset]::UtcNow
$endTimeLocal = $endTimeUtc.ToOffset([TimeSpan]::FromHours(8)).ToString('yyyy-MM-ddTHH:mm:ss.fffzzz')

Write-Output ""
Write-Output ("PHASE0_START|" + $startTimeLocal)
Write-Output ("PHASE0_END  |" + $endTimeLocal)
Write-Output "PHASE0_STATUS|completed"
