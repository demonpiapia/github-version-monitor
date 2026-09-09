# phase2-orchestrator.ps1 - Phase 2 T38 定向生产验证 (v3)
# 修复：
#   1. T38-A: 改用 ACL deny 方案（文件锁方案不阻止 Set-Content 覆盖）
#   2. T38-C/T38-heartbeat: Start-Process 移除 -NoNewWindow（与 -WindowStyle 冲突）
#   3. T38-stats-items: 保留 constraint #13 检查（已确认违反）

param([string]$ProjectRoot)

$ErrorActionPreference = 'Continue'
$global:TestResults = @{}

if (-not $ProjectRoot) { $ProjectRoot = 'D:\AI\Workspace\automatic\github-version-monitor' }
$pvDir = Join-Path $ProjectRoot '.production-validation-v110-final'
$libDir = Join-Path $pvDir 'lib'
$pwshPath = (Get-Command pwsh).Source

function Write-Log { param([string]$Msg) Write-Output ("[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss.fff'), $Msg) }

function Get-Sha256 {
    param([string]$Path)
    if (Test-Path $Path) { return (Get-FileHash $Path -Algorithm SHA256).Hash }
    return 'FILE_NOT_EXISTS'
}

function Capture-BeforeAfter {
    param([string]$TestDir, [string]$BaseDir)
    $mdPath = Join-Path $BaseDir '.output\GitHub更新监测列表.md'
    $resultPath = Join-Path $BaseDir '.monitor\result.json'
    $tmpPath = Join-Path $BaseDir '.monitor\result.review.tmp'
    $lockPath = Join-Path $BaseDir '.monitor\run.lock'
    $beforeDir = Join-Path $TestDir 'before'
    $afterDir = Join-Path $TestDir 'after'
    if (-not (Test-Path $beforeDir)) { New-Item -ItemType Directory -Force -Path $beforeDir | Out-Null }
    if (-not (Test-Path $afterDir)) { New-Item -ItemType Directory -Force -Path $afterDir | Out-Null }

    $mdBefore = Join-Path $TestDir 'md-before.md'
    $resultBefore = Join-Path $TestDir 'result-before.json'
    $lockBefore = Join-Path $TestDir 'lock-before.txt'
    if (Test-Path $mdPath) { Copy-Item $mdPath $mdBefore -Force }
    if (Test-Path $resultPath) { Copy-Item $resultPath $resultBefore -Force }
    if (Test-Path $lockPath) { Get-Content $lockPath -Raw | Set-Content $lockBefore -Encoding UTF8 } else { 'LOCK_FILE_NOT_EXISTS' | Set-Content $lockBefore -Encoding UTF8 }

    $shaBefore = Join-Path $TestDir 'sha256-before.txt'
    $sb = @()
    $sb += ("main_md: {0}" -f (Get-Sha256 $mdPath))
    $sb += ("result.json: {0}" -f (Get-Sha256 $resultPath))
    $sb += ("result.review.tmp: {0}" -f (Get-Sha256 $tmpPath))
    $sb += ("run.lock: {0}" -f (Get-Sha256 $lockPath))
    $sb | Set-Content $shaBefore -Encoding UTF8

    $beforeListing = Join-Path $TestDir 'before\dir-listing.txt'
    Get-ChildItem $BaseDir -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName.Replace($BaseDir,'') } | Set-Content $beforeListing -Encoding UTF8
}

function Capture-After {
    param([string]$TestDir, [string]$BaseDir)
    $mdPath = Join-Path $BaseDir '.output\GitHub更新监测列表.md'
    $resultPath = Join-Path $BaseDir '.monitor\result.json'
    $tmpPath = Join-Path $BaseDir '.monitor\result.review.tmp'
    $lockPath = Join-Path $baseDir '.monitor\run.lock'
    $afterDir = Join-Path $TestDir 'after'
    if (-not (Test-Path $afterDir)) { New-Item -ItemType Directory -Force -Path $afterDir | Out-Null }

    $mdAfter = Join-Path $TestDir 'md-after.md'
    $resultAfter = Join-Path $TestDir 'result-after.json'
    $lockAfter = Join-Path $TestDir 'lock-after.txt'
    if (Test-Path $mdPath) { Copy-Item $mdPath $mdAfter -Force }
    if (Test-Path $resultPath) { Copy-Item $resultPath $resultAfter -Force }
    if (Test-Path $lockPath) { Get-Content $lockPath -Raw | Set-Content $lockAfter -Encoding UTF8 } else { 'LOCK_FILE_NOT_EXISTS' | Set-Content $lockAfter -Encoding UTF8 }

    $shaAfter = Join-Path $TestDir 'sha256-after.txt'
    $sa = @()
    $sa += ("main_md: {0}" -f (Get-Sha256 $mdPath))
    $sa += ("result.json: {0}" -f (Get-Sha256 $resultPath))
    $sa += ("result.review.tmp: {0}" -f (Get-Sha256 $tmpPath))
    $sa += ("run.lock: {0}" -f (Get-Sha256 $lockPath))
    $sa | Set-Content $shaAfter -Encoding UTF8

    $afterListing = Join-Path $TestDir 'after\dir-listing.txt'
    Get-ChildItem $BaseDir -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName.Replace($BaseDir,'') } | Set-Content $afterListing -Encoding UTF8
}

function Write-Wrapper {
    param([string]$Path, [string[]]$Lines)
    [System.IO.File]::WriteAllLines($Path, $Lines, (New-Object System.Text.UTF8Encoding($false)))
}

function Run-Script {
    param([string]$ScriptPath, [string]$StdoutFile)
    & $pwshPath -NoProfile -NonInteractive -File $ScriptPath *> $StdoutFile
    return $LASTEXITCODE
}

function Judge-Test {
    param([string]$TestName, [string]$TestDir, [string[]]$ExpectedPatterns, [string[]]$ForbiddenPatterns)
    $stdout = Get-Content (Join-Path $TestDir 'stdout.txt') -Raw -ErrorAction SilentlyContinue
    if (-not $stdout) { $stdout = '' }

    $results = @{}
    $allPass = $true

    foreach ($pat in $ExpectedPatterns) {
        $found = $stdout -match [regex]::Escape($pat)
        $results["expected_contains:$pat"] = $found
        if (-not $found) { $allPass = $false }
    }
    foreach ($pat in $ForbiddenPatterns) {
        $absent = -not ($stdout -match [regex]::Escape($pat))
        $results["forbidden_absent:$pat"] = $absent
        if (-not $absent) { $allPass = $false }
    }

    $global:TestResults[$TestName] = @{
        Pass = $allPass
        Details = $results
        Stdout = $stdout
    }
    return $allPass
}

# ============================================================
# Main execution
# ============================================================

Write-Log "Phase 2 T38 Execution Started (v3 - ACL for T38-A, fixed Start-Process)"
Write-Log "ProjectRoot: $ProjectRoot"
Write-Log "PVDir: $pvDir"

# ============================================================
# T38-A: review tmp 创建/写入失败 (ACL deny 方案)
# 方法：对 .monitor 目录施加 ACL deny CreateFiles 权限，
#       阻止 Set-Content 创建 result.review.tmp。
# 注意：ACL deny CreateFiles 仅阻止新文件创建，不阻止覆盖。
#       因此须确保 result.review.tmp 不存在。
# ============================================================
Write-Log "=== T38-A: review tmp 创建/写入失败 (ACL) ==="
$testDir = Join-Path $pvDir 'T38-A'
$baseDir = $testDir
if (Test-Path $baseDir) { Remove-Item $baseDir -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Force -Path $baseDir | Out-Null

Write-Log "T38-A: Generating fixture"
& $pwshPath -NoProfile -NonInteractive -File (Join-Path $libDir 'create-fixture.ps1') -BaseDir $baseDir -Scenario 'normal' *> (Join-Path $testDir 'fixture-stdout.txt')

# Create .monitor directory (will be created by step1 anyway)
$monitorDir = Join-Path $baseDir '.monitor'
New-Item -ItemType Directory -Force -Path $monitorDir | Out-Null

# Ensure result.review.tmp does NOT exist (ACL only blocks creation, not overwrite)
$tmpPath = Join-Path $monitorDir 'result.review.tmp'
if (Test-Path $tmpPath) { Remove-Item $tmpPath -Force -ErrorAction SilentlyContinue }

Capture-BeforeAfter -TestDir $testDir -BaseDir $baseDir

# Define ACL before file path (used inside wrapper)
$aclBeforeFile = Join-Path $testDir 'acl-before.xml'

# Apply ACL deny BEFORE step4 (between step3 and step4), not before step1
# This allows step1 to create run.lock, but blocks step4 from creating result.review.tmp
$wrapperA = Join-Path $testDir 'step4-wrapper.ps1'
$linesA = @(
    "`$ErrorActionPreference = 'Continue'"
    "`$env:GITHUB_VERSION_MONITOR_BASE = '$baseDir'"
    ". '$libDir\step1.ps1'"
    ". '$libDir\step2.ps1'"
    ". '$libDir\step3.ps1'"
    "`$monitorDir = Join-Path `$env:GITHUB_VERSION_MONITOR_BASE '.monitor'"
    "`$tmpPath = Join-Path `$monitorDir 'result.review.tmp'"
    "if (Test-Path `$tmpPath) { Remove-Item `$tmpPath -Force -ErrorAction SilentlyContinue }"
    "`$aclBeforeFile = '$aclBeforeFile'"
    "Get-Acl `$monitorDir | Export-Clixml `$aclBeforeFile"
    "`$user = `$env:USERNAME"
    "`$identity = New-Object System.Security.Principal.NTAccount(`$user)"
    "`$rule = New-Object System.Security.AccessControl.FileSystemAccessRule(`$identity, [System.Security.AccessControl.FileSystemRights]::CreateFiles, [System.Security.AccessControl.AccessControlType]::Deny)"
    "`$acl = Get-Acl `$monitorDir"
    "`$acl.SetAccessRule(`$rule)"
    "Set-Acl `$monitorDir `$acl"
    ". '$libDir\step4.ps1'"
    "`$acl = Import-Clixml `$aclBeforeFile"
    "Set-Acl `$monitorDir `$acl"
)
Write-Wrapper -Path $wrapperA -Lines $linesA
$exitCode = Run-Script -ScriptPath $wrapperA -StdoutFile (Join-Path $testDir 'stdout.txt')

# Verify ACL restored
$verifyAcl = Get-Acl $monitorDir
$denyRemoved = -not ($verifyAcl.Access | Where-Object { $_.AccessControlType -eq 'Deny' -and $_.FileSystemRights -match 'CreateFiles' })
Write-Log "T38-A: ACL deny removed = $denyRemoved"

Capture-After -TestDir $testDir -BaseDir $baseDir

# Check if result.review.tmp was created (should NOT be created with ACL deny)
$tmpCreated = Test-Path $tmpPath
Write-Log "T38-A: result.review.tmp created = $tmpCreated (expected: False)"

$pass = Judge-Test -TestName 'T38-A' -TestDir $testDir `
    -ExpectedPatterns @('REVIEW_WRITE_ERROR|review 临时文件写入失败', 'RUN_STATUS|failed|review 写入失败') `
    -ForbiddenPatterns @('COMMIT_OK|', 'RUN_STATUS|success|')
Write-Log "T38-A: $($pass ? 'PASS' : 'FAIL')"

# ============================================================
# T38-B: review JSON validation failure (harness)
# ============================================================
Write-Log "=== T38-B: review JSON validation failure ==="
$testDir = Join-Path $pvDir 'T38-B'
$baseDir = $testDir
if (Test-Path $baseDir) { Remove-Item $baseDir -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Force -Path $baseDir | Out-Null

Write-Log "T38-B: Generating fixture"
& $pwshPath -NoProfile -NonInteractive -File (Join-Path $libDir 'create-fixture.ps1') -BaseDir $baseDir -Scenario 'normal' *> (Join-Path $testDir 'fixture-stdout.txt')

Capture-BeforeAfter -TestDir $testDir -BaseDir $baseDir

$wrapperB = Join-Path $testDir 'step4-wrapper.ps1'
$linesB = @(
    "`$ErrorActionPreference = 'Continue'"
    "`$env:GITHUB_VERSION_MONITOR_BASE = '$baseDir'"
    ". '$libDir\step1.ps1'"
    ". '$libDir\step2.ps1'"
    ". '$libDir\step3.ps1'"
    ". '$libDir\step4-t38b-harness.ps1'"
)
Write-Wrapper -Path $wrapperB -Lines $linesB
$exitCode = Run-Script -ScriptPath $wrapperB -StdoutFile (Join-Path $testDir 'stdout.txt')

Capture-After -TestDir $testDir -BaseDir $baseDir

$pass = Judge-Test -TestName 'T38-B' -TestDir $testDir `
    -ExpectedPatterns @('REVIEW_WRITE_ERROR|review 临时 JSON 校验失败', 'RUN_STATUS|failed|review 临时 JSON 校验失败') `
    -ForbiddenPatterns @('COMMIT_OK|', 'RUN_STATUS|success|')
Write-Log "T38-B: $($pass ? 'PASS' : 'FAIL')"

# ============================================================
# T38-C: review tmp → result.json 原子替换失败
# 方法：同进程执行 step1-3，然后在 step3 和 step4 之间启动
#       lock holder 锁定 result.json，再执行 step4。
# ============================================================
Write-Log "=== T38-C: review 原子替换失败 ==="
$testDir = Join-Path $pvDir 'T38-C'
$baseDir = $testDir
if (Test-Path $baseDir) { Remove-Item $baseDir -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Force -Path $baseDir | Out-Null

Write-Log "T38-C: Generating fixture"
& $pwshPath -NoProfile -NonInteractive -File (Join-Path $libDir 'create-fixture.ps1') -BaseDir $baseDir -Scenario 'normal' *> (Join-Path $testDir 'fixture-stdout.txt')

Capture-BeforeAfter -TestDir $testDir -BaseDir $baseDir

# Wrapper: step1-3, then start lock holder on result.json, then step4, then stop lock holder
# NOTE: -WindowStyle Hidden without -NoNewWindow (they conflict)
$wrapperC = Join-Path $testDir 'step4-wrapper.ps1'
$linesC = @(
    "`$ErrorActionPreference = 'Continue'"
    "`$env:GITHUB_VERSION_MONITOR_BASE = '$baseDir'"
    ". '$libDir\step1.ps1'"
    ". '$libDir\step2.ps1'"
    ". '$libDir\step3.ps1'"
    "`$resultPath = Join-Path `$env:GITHUB_VERSION_MONITOR_BASE '.monitor\result.json'"
    "`$pwshPath = (Get-Command pwsh).Source"
    "`$holderScript = '$libDir\lock-holder.ps1'"
    "`$holderProc = Start-Process -FilePath `$pwshPath -ArgumentList @('-NoProfile','-NonInteractive','-File',`$holderScript,'-FilePath',`$resultPath,'-ShareMode','Read') -WindowStyle Hidden -PassThru"
    "Start-Sleep -Seconds 3"
    ". '$libDir\step4.ps1'"
    "try { Stop-Process -Id `$holderProc.Id -Force -ErrorAction SilentlyContinue } catch {}"
)
Write-Wrapper -Path $wrapperC -Lines $linesC
$exitCode = Run-Script -ScriptPath $wrapperC -StdoutFile (Join-Path $testDir 'stdout.txt')

Capture-After -TestDir $testDir -BaseDir $baseDir

$pass = Judge-Test -TestName 'T38-C' -TestDir $testDir `
    -ExpectedPatterns @('REVIEW_WRITE_ERROR|review 原子替换失败', 'RUN_STATUS|failed|review 原子替换失败') `
    -ForbiddenPatterns @('COMMIT_OK|', 'RUN_STATUS|success|')
Write-Log "T38-C: $($pass ? 'PASS' : 'FAIL')"

# ============================================================
# T38-heartbeat: heartbeat 失败
# 方法：同进程执行 step1-3，然后在 step3 和 step4 之间启动
#       lock holder 锁定 run.lock，再执行 step4。
# ============================================================
Write-Log "=== T38-heartbeat: heartbeat 失败 ==="
$testDir = Join-Path $pvDir 'T38-heartbeat'
$baseDir = $testDir
if (Test-Path $baseDir) { Remove-Item $baseDir -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Force -Path $baseDir | Out-Null

Write-Log "T38-heartbeat: Generating fixture"
& $pwshPath -NoProfile -NonInteractive -File (Join-Path $libDir 'create-fixture.ps1') -BaseDir $baseDir -Scenario 'normal' *> (Join-Path $testDir 'fixture-stdout.txt')

Capture-BeforeAfter -TestDir $testDir -BaseDir $baseDir

# Wrapper: step1-3, then start lock holder on run.lock, then step4, then stop lock holder
$wrapperHB = Join-Path $testDir 'step4-wrapper.ps1'
$linesHB = @(
    "`$ErrorActionPreference = 'Continue'"
    "`$env:GITHUB_VERSION_MONITOR_BASE = '$baseDir'"
    ". '$libDir\step1.ps1'"
    ". '$libDir\step2.ps1'"
    ". '$libDir\step3.ps1'"
    "`$lockPath = Join-Path `$env:GITHUB_VERSION_MONITOR_BASE '.monitor\run.lock'"
    "`$pwshPath = (Get-Command pwsh).Source"
    "`$holderScript = '$libDir\lock-holder.ps1'"
    "`$holderProc = Start-Process -FilePath `$pwshPath -ArgumentList @('-NoProfile','-NonInteractive','-File',`$holderScript,'-FilePath',`$lockPath) -WindowStyle Hidden -PassThru"
    "Start-Sleep -Seconds 3"
    ". '$libDir\step4.ps1'"
    "try { Stop-Process -Id `$holderProc.Id -Force -ErrorAction SilentlyContinue } catch {}"
)
Write-Wrapper -Path $wrapperHB -Lines $linesHB
$exitCode = Run-Script -ScriptPath $wrapperHB -StdoutFile (Join-Path $testDir 'stdout.txt')

Capture-After -TestDir $testDir -BaseDir $baseDir

$pass = Judge-Test -TestName 'T38-heartbeat' -TestDir $testDir `
    -ExpectedPatterns @('RUNTIME_ERROR|步骤4 heartbeat 失败', 'RUN_STATUS|failed|步骤4 heartbeat 失败') `
    -ForbiddenPatterns @('RUN_STATUS|success|')
Write-Log "T38-heartbeat: $($pass ? 'PASS' : 'FAIL')"

# ============================================================
# T38-result-read: result.json 读取失败
# 方法：同进程执行 step1-3，然后删除 result.json，再执行 step4。
# ============================================================
Write-Log "=== T38-result-read: result.json 读取失败 ==="
$testDir = Join-Path $pvDir 'T38-result-read'
$baseDir = $testDir
if (Test-Path $baseDir) { Remove-Item $baseDir -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Force -Path $baseDir | Out-Null

Write-Log "T38-result-read: Generating fixture"
& $pwshPath -NoProfile -NonInteractive -File (Join-Path $libDir 'create-fixture.ps1') -BaseDir $baseDir -Scenario 'normal' *> (Join-Path $testDir 'fixture-stdout.txt')

Capture-BeforeAfter -TestDir $testDir -BaseDir $baseDir

# Wrapper: step1-3, delete result.json, then step4
$wrapperRR = Join-Path $testDir 'step4-wrapper.ps1'
$linesRR = @(
    "`$ErrorActionPreference = 'Continue'"
    "`$env:GITHUB_VERSION_MONITOR_BASE = '$baseDir'"
    ". '$libDir\step1.ps1'"
    ". '$libDir\step2.ps1'"
    ". '$libDir\step3.ps1'"
    "`$resultPath = Join-Path `$env:GITHUB_VERSION_MONITOR_BASE '.monitor\result.json'"
    "Remove-Item `$resultPath -Force -ErrorAction SilentlyContinue"
    ". '$libDir\step4.ps1'"
)
Write-Wrapper -Path $wrapperRR -Lines $linesRR
$exitCode = Run-Script -ScriptPath $wrapperRR -StdoutFile (Join-Path $testDir 'stdout.txt')

Capture-After -TestDir $testDir -BaseDir $baseDir

$pass = Judge-Test -TestName 'T38-result-read' -TestDir $testDir `
    -ExpectedPatterns @('RUNTIME_ERROR|读取 result.json 失败', 'RUN_STATUS|failed|读取 result.json 失败') `
    -ForbiddenPatterns @('RUN_STATUS|success|', 'REVIEW_WRITE_ERROR|')
Write-Log "T38-result-read: $($pass ? 'PASS' : 'FAIL')"

# ============================================================
# T38-stats-items: stats/items 完整性失败 (harness)
# ============================================================
Write-Log "=== T38-stats-items: stats/items 完整性失败 ==="
$testDir = Join-Path $pvDir 'T38-stats-items'
$baseDir = $testDir
if (Test-Path $baseDir) { Remove-Item $baseDir -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Force -Path $baseDir | Out-Null

Write-Log "T38-stats-items: Generating fixture"
& $pwshPath -NoProfile -NonInteractive -File (Join-Path $libDir 'create-fixture.ps1') -BaseDir $baseDir -Scenario 'normal' *> (Join-Path $testDir 'fixture-stdout.txt')

Capture-BeforeAfter -TestDir $testDir -BaseDir $baseDir

$wrapperSI = Join-Path $testDir 'step4-wrapper.ps1'
$linesSI = @(
    "`$ErrorActionPreference = 'Continue'"
    "`$env:GITHUB_VERSION_MONITOR_BASE = '$baseDir'"
    ". '$libDir\step1.ps1'"
    ". '$libDir\step2.ps1'"
    ". '$libDir\step3.ps1'"
    ". '$libDir\step4-t38-stats-items-harness.ps1'"
)
Write-Wrapper -Path $wrapperSI -Lines $linesSI
$exitCode = Run-Script -ScriptPath $wrapperSI -StdoutFile (Join-Path $testDir 'stdout.txt')

Capture-After -TestDir $testDir -BaseDir $baseDir

# Count RUN_STATUS|failed| occurrences
$stdoutSI = Get-Content (Join-Path $testDir 'stdout.txt') -Raw -ErrorAction SilentlyContinue
if (-not $stdoutSI) { $stdoutSI = '' }
$failedCount = ([regex]::Matches($stdoutSI, 'RUN_STATUS\|failed\|')).Count
$reviewWriteOkCount = ([regex]::Matches($stdoutSI, 'REVIEW_WRITE_OK\|')).Count

Write-Log "T38-stats-items: RUN_STATUS|failed| count = $failedCount"
Write-Log "T38-stats-items: REVIEW_WRITE_OK| count = $reviewWriteOkCount"

# Save counts to file for report
$countsFile = Join-Path $testDir 'run-status-counts.txt'
$counts = @(
    "RUN_STATUS|failed| count: $failedCount"
    "REVIEW_WRITE_OK| count: $reviewWriteOkCount"
    "Expected: RUN_STATUS|failed| count = 1 (constraint #13)"
    ""
    "Analysis:"
    "L480 stats/items integrity check failed (return removed in v1.10)"
    "→ Output RUN_STATUS|failed|review 程序事实完整性校验失败"
    "→ Execution falls into L481 try block"
    "→ Set-Content succeeds (tmp written)"
    "→ ConvertFrom-Json succeeds but stats mismatch detected"
    "→ Output RUN_STATUS|failed|review 临时 JSON 校验失败"
    "→ Total: 2 RUN_STATUS|failed| outputs (constraint #13 VIOLATION)"
)
$counts | Set-Content $countsFile -Encoding UTF8

# Judge: expected patterns + constraint #13 check
$pass = Judge-Test -TestName 'T38-stats-items' -TestDir $testDir `
    -ExpectedPatterns @('REVIEW_WRITE_ERROR|review 修改了 stats/items', 'RUN_STATUS|failed|review 程序事实完整性校验失败') `
    -ForbiddenPatterns @('COMMIT_OK|', 'RUN_STATUS|success|')

# Additional check: constraint #13 (RUN_STATUS|failed| must appear exactly once)
if ($failedCount -ne 1) {
    Write-Log "T38-stats-items: CONSTRAINT #13 VIOLATION - RUN_STATUS|failed| count=$failedCount (expected 1)"
    $global:TestResults['T38-stats-items'].Pass = $false
    $global:TestResults['T38-stats-items'].Details['constraint13_failed_count'] = $false
    $global:TestResults['T38-stats-items'].Details['constraint13_failed_count_value'] = $failedCount
} else {
    $global:TestResults['T38-stats-items'].Details['constraint13_failed_count'] = $true
}

Write-Log "T38-stats-items: $($global:TestResults['T38-stats-items'].Pass ? 'PASS' : 'FAIL') (failedCount=$failedCount, reviewWriteOkCount=$reviewWriteOkCount)"

# ============================================================
# Summary
# ============================================================
Write-Log "=== Phase 2 Summary ==="
foreach ($key in @('T38-A','T38-B','T38-C','T38-heartbeat','T38-result-read','T38-stats-items')) {
    if ($global:TestResults.ContainsKey($key)) {
        $r = $global:TestResults[$key]
        Write-Log ("{0}: {1}" -f $key, ($r.Pass ? 'PASS' : 'FAIL'))
    }
}

Write-Log "Phase 2 execution finished at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
