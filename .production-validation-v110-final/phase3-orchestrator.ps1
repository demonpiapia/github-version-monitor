# phase3-orchestrator.ps1 - Phase 3 T22/T23 定向生产验证
# 目标：验证 SKILL-v1.10 Step 5 的 md tmp 写入失败 (T22) 与 md 原子替换失败 (T23)
# 隔离：通过 GITHUB_VERSION_MONITOR_BASE 指向测试子目录，禁止触碰生产根目录
# 前置：Phase 1 (lib/step1-5.ps1) + Phase 2 (lib/lock-holder.ps1) 已完成

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

# Capture before state for Step 5 tests (main md + result.json + md.tmp + run.lock)
function Capture-BeforeAfter {
    param([string]$TestDir, [string]$BaseDir)
    $mdPath = Join-Path $BaseDir '.output\GitHub更新监测列表.md'
    $resultPath = Join-Path $BaseDir '.monitor\result.json'
    $tmpPath = Join-Path $BaseDir '.output\GitHub更新监测列表.md.tmp'
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
    $sb += ("md.tmp: {0}" -f (Get-Sha256 $tmpPath))
    $sb += ("run.lock: {0}" -f (Get-Sha256 $lockPath))
    $sb | Set-Content $shaBefore -Encoding UTF8

    $beforeListing = Join-Path $TestDir 'before\dir-listing.txt'
    Get-ChildItem $BaseDir -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName.Replace($BaseDir,'') } | Set-Content $beforeListing -Encoding UTF8
}

function Capture-After {
    param([string]$TestDir, [string]$BaseDir)
    $mdPath = Join-Path $BaseDir '.output\GitHub更新监测列表.md'
    $resultPath = Join-Path $BaseDir '.monitor\result.json'
    $tmpPath = Join-Path $BaseDir '.output\GitHub更新监测列表.md.tmp'
    $lockPath = Join-Path $BaseDir '.monitor\run.lock'
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
    $sa += ("md.tmp: {0}" -f (Get-Sha256 $tmpPath))
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
    param([string]$ScriptPath, [string]$StdoutFile, [string]$StderrFile)
    # PowerShell scripts emit output via Write-Output (stream 1) and Write-Error (stream 2).
    # -RedirectStandardOutput/-RedirectStandardError only capture native stdout/stderr, not PS streams.
    # Use *> to capture ALL streams to stdout.txt, and create empty stderr.txt for evidence completeness.
    & $pwshPath -NoProfile -NonInteractive -File $ScriptPath *> $StdoutFile
    if (-not (Test-Path $StderrFile)) { New-Item -ItemType File -Path $StderrFile -Force | Out-Null }
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

Write-Log "Phase 3 T22/T23 Execution Started"
Write-Log "ProjectRoot: $ProjectRoot"
Write-Log "PVDir: $pvDir"

# ============================================================
# T22: md tmp 写入失败 (ACL deny CreateFiles on .output)
# 方法：Step 1-4 正常执行后，对 .output 目录施加 ACL deny CreateFiles
#       阻止 Set-Content 创建 GitHub更新监测列表.md.tmp
# 前置断言：md.tmp 不存在（否则 ACL 不阻止覆盖）
# ============================================================
Write-Log "=== T22: md tmp 写入失败 (ACL deny CreateFiles) ==="
$testDir = Join-Path $pvDir 'T22'
$baseDir = $testDir
if (Test-Path $baseDir) { Remove-Item $baseDir -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Force -Path $baseDir | Out-Null

Write-Log "T22: Generating fixture"
& $pwshPath -NoProfile -NonInteractive -File (Join-Path $libDir 'create-fixture.ps1') -BaseDir $baseDir -Scenario 'normal' *> (Join-Path $testDir 'fixture-stdout.txt')

Capture-BeforeAfter -TestDir $testDir -BaseDir $baseDir

# Wrapper: step1-4, then apply ACL deny on .output, then step5, then restore ACL
$wrapperT22 = Join-Path $testDir 'step5-wrapper.ps1'
$linesT22 = @(
    "`$ErrorActionPreference = 'Continue'"
    "`$env:GITHUB_VERSION_MONITOR_BASE = '$baseDir'"
    ". '$libDir\step1.ps1'"
    ". '$libDir\step2.ps1'"
    ". '$libDir\step3.ps1'"
    ". '$libDir\step4.ps1'"
    "`$outputDir = Join-Path `$env:GITHUB_VERSION_MONITOR_BASE '.output'"
    "`$tmpPath = Join-Path `$outputDir 'GitHub更新监测列表.md.tmp'"
    "if (Test-Path `$tmpPath) { Remove-Item `$tmpPath -Force -ErrorAction SilentlyContinue; Write-Output 'T22_PRECHECK|removed existing md.tmp' }"
    "`$aclBeforeFile = '$(Join-Path $testDir 'acl-before.xml')'"
    "Get-Acl `$outputDir | Export-Clixml `$aclBeforeFile"
    "`$user = `$env:USERNAME"
    "`$identity = New-Object System.Security.Principal.NTAccount(`$user)"
    "`$rule = New-Object System.Security.AccessControl.FileSystemAccessRule(`$identity, [System.Security.AccessControl.FileSystemRights]::CreateFiles, [System.Security.AccessControl.AccessControlType]::Deny)"
    "`$acl = Get-Acl `$outputDir"
    "`$acl.SetAccessRule(`$rule)"
    "Set-Acl `$outputDir `$acl"
    ". '$libDir\step5-full.ps1'"
    "`$acl = Import-Clixml `$aclBeforeFile"
    "Set-Acl `$outputDir `$acl"
)
Write-Wrapper -Path $wrapperT22 -Lines $linesT22
$exitCode = Run-Script -ScriptPath $wrapperT22 -StdoutFile (Join-Path $testDir 'stdout.txt') -StderrFile (Join-Path $testDir 'stderr.txt')

# Verify ACL restored
$outputDirT22 = Join-Path $baseDir '.output'
$verifyAcl = Get-Acl $outputDirT22
$denyRemoved = -not ($verifyAcl.Access | Where-Object { $_.AccessControlType -eq 'Deny' -and $_.FileSystemRights -match 'CreateFiles' })
Write-Log "T22: ACL deny removed = $denyRemoved"

Capture-After -TestDir $testDir -BaseDir $baseDir

# Check if md.tmp was created (should NOT be created with ACL deny)
$tmpCreated = Test-Path (Join-Path $baseDir '.output\GitHub更新监测列表.md.tmp')
Write-Log "T22: md.tmp created = $tmpCreated (expected: False)"

# Save tmp existence check
"md.tmp_exists: $tmpCreated" | Set-Content (Join-Path $testDir 'tmp-existence.txt') -Encoding UTF8
"acl_restore_ok: $denyRemoved" | Add-Content (Join-Path $testDir 'tmp-existence.txt') -Encoding UTF8

$pass = Judge-Test -TestName 'T22' -TestDir $testDir `
    -ExpectedPatterns @('RUNTIME_ERROR|主 md 临时文件写入/读取失败', 'RUN_STATUS|failed|主 md 未提交') `
    -ForbiddenPatterns @('COMMIT_OK|', 'RUN_STATUS|success|')
Write-Log "T22: $($pass ? 'PASS' : 'FAIL')"

# ============================================================
# T23: md 原子替换失败 (FileShare::Read lock on main md)
# 方法：Step 1-4 正常执行后，启动 lock holder 以 FileShare::Read 打开
#       主 md 文件（允许读，阻止写/替换），再执行 Step 5。
#       Move-Item 替换主 md 时因目标文件被独占而失败。
# ============================================================
Write-Log "=== T23: md 原子替换失败 (FileShare::Read on main md) ==="
$testDir = Join-Path $pvDir 'T23'
$baseDir = $testDir
if (Test-Path $baseDir) { Remove-Item $baseDir -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Force -Path $baseDir | Out-Null

Write-Log "T23: Generating fixture"
& $pwshPath -NoProfile -NonInteractive -File (Join-Path $libDir 'create-fixture.ps1') -BaseDir $baseDir -Scenario 'normal' *> (Join-Path $testDir 'fixture-stdout.txt')

Capture-BeforeAfter -TestDir $testDir -BaseDir $baseDir

# Wrapper: step1-4, then start lock holder on main md (ReadShare), then step5, then stop lock holder
$wrapperT23 = Join-Path $testDir 'step5-wrapper.ps1'
$linesT23 = @(
    "`$ErrorActionPreference = 'Continue'"
    "`$env:GITHUB_VERSION_MONITOR_BASE = '$baseDir'"
    ". '$libDir\step1.ps1'"
    ". '$libDir\step2.ps1'"
    ". '$libDir\step3.ps1'"
    ". '$libDir\step4.ps1'"
    "`$mdPath = Join-Path `$env:GITHUB_VERSION_MONITOR_BASE '.output\GitHub更新监测列表.md'"
    "`$pwshPath = (Get-Command pwsh).Source"
    "`$holderScript = '$libDir\lock-holder.ps1'"
    "`$holderStdout = '$(Join-Path $testDir 'lock-holder-stdout.txt')'"
    "`$holderStderr = '$(Join-Path $testDir 'lock-holder-stderr.txt')'"
    "`$holderProc = Start-Process -FilePath `$pwshPath -ArgumentList @('-NoProfile','-NonInteractive','-File',`$holderScript,'-FilePath',`$mdPath,'-ShareMode','Read') -WindowStyle Hidden -PassThru -RedirectStandardOutput `$holderStdout -RedirectStandardError `$holderStderr"
    "Start-Sleep -Seconds 3"
    "Write-Output ('T23_LOCKHOLDER_STARTED|pid=' + `$holderProc.Id)"
    ". '$libDir\step5-full.ps1'"
    "try { Stop-Process -Id `$holderProc.Id -Force -ErrorAction SilentlyContinue; Write-Output 'T23_LOCKHOLDER_STOPPED' } catch { Write-Output ('T23_LOCKHOLDER_STOP_FAIL|' + `$_) }"
)
Write-Wrapper -Path $wrapperT23 -Lines $linesT23
$exitCode = Run-Script -ScriptPath $wrapperT23 -StdoutFile (Join-Path $testDir 'stdout.txt') -StderrFile (Join-Path $testDir 'stderr.txt')

Capture-After -TestDir $testDir -BaseDir $baseDir

# Check if md.tmp was cleaned (should be cleaned by step5 catch block)
$tmpExistsT23 = Test-Path (Join-Path $baseDir '.output\GitHub更新监测列表.md.tmp')
Write-Log "T23: md.tmp exists after = $tmpExistsT23 (expected: False, cleaned by step5 catch)"

"md.tmp_exists_after: $tmpExistsT23" | Set-Content (Join-Path $testDir 'tmp-existence.txt') -Encoding UTF8

$pass = Judge-Test -TestName 'T23' -TestDir $testDir `
    -ExpectedPatterns @('RUNTIME_ERROR|主 md 原子替换失败', 'RUN_STATUS|failed|主 md 未提交') `
    -ForbiddenPatterns @('COMMIT_OK|', 'RUN_STATUS|success|')
Write-Log "T23: $($pass ? 'PASS' : 'FAIL')"

# ============================================================
# Summary
# ============================================================
Write-Log "=== Phase 3 Summary ==="
foreach ($key in @('T22','T23')) {
    if ($global:TestResults.ContainsKey($key)) {
        $r = $global:TestResults[$key]
        Write-Log ("{0}: {1}" -f $key, ($r.Pass ? 'PASS' : 'FAIL'))
    }
}

Write-Log "Phase 3 execution finished at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
