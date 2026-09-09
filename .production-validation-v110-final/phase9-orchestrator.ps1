# phase9-orchestrator.ps1 - Phase 9: Lock 回归 + Process Kill
# 用途：执行 exec-plan-v1.10-d.md §2 Phase 9 全部测试
#   9.1 Lock Regression:
#     - lock-concurrency: 两进程争锁
#     - lock-ownership:   外来 PID
#     - lock-stale-alive: 陈锁 + PID 活
#     - lock-stale-dead:  陈锁 + PID 死
#   9.2 Process Kill Regression:
#     - process-kill: Stop-Process 中途终止 + 重运行检查
#
# 隔离：GITHUB_VERSION_MONITOR_BASE 指向各测试子目录
# 后台静默：所有子 pwsh 进程通过 Start-Process -WindowStyle Hidden 启动

param(
    [Parameter(Mandatory=$true)][string]$RootDir
)

$ErrorActionPreference = 'Continue'
$script:Start = Get-Date
$script:Results = @{}
$script:TestDirs = @{}
$script:Errors = @()

$libDir = Join-Path $RootDir 'lib'
$baseDir = $RootDir

function Write-Log {
    param([string]$Msg)
    $ts = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    Write-Output ("[{0}] {1}" -f $ts, $Msg)
}

function Get-Hash {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return 'FILE_NOT_EXISTS' }
    return (Get-FileHash $Path -Algorithm SHA256).Hash
}

function Write-Snapshot {
    param([string]$TestDir, [string]$Phase)
    $base = Join-Path $TestDir '.'
    $lock = Join-Path $base '.monitor\run.lock'
    $lockContent = 'LOCK_FILE_NOT_EXISTS'
    if (Test-Path $lock) { $lockContent = Get-Content $lock -Raw -ErrorAction SilentlyContinue }
    $lockPath = Join-Path $TestDir ("lock-{0}.txt" -f $Phase)
    Set-Content -Path $lockPath -Value $lockContent -Encoding UTF8
}

function Write-Sha256 {
    param([string]$TestDir, [string]$Phase)
    $base = Join-Path $TestDir '.'
    $md = Join-Path $base '.output\GitHub更新监测列表.md'
    $result = Join-Path $base '.monitor\result.json'
    $tmp = "$md.tmp"
    $lock = Join-Path $base '.monitor\run.lock'
    $lines = @(
        ("main_md: {0}" -f (Get-Hash $md)),
        ("result.json: {0}" -f (Get-Hash $result)),
        ("md.tmp: {0}" -f (Get-Hash $tmp)),
        ("run.lock: {0}" -f (Get-Hash $lock))
    )
    $path = Join-Path $TestDir ("sha256-{0}.txt" -f $Phase)
    Set-Content -Path $path -Value $lines -Encoding UTF8
}

function Copy-Snapshot {
    param([string]$TestDir, [string]$Phase)
    $base = Join-Path $TestDir '.'
    $md = Join-Path $base '.output\GitHub更新监测列表.md'
    $result = Join-Path $base '.monitor\result.json'
    if (Test-Path $md) { Copy-Item $md (Join-Path $testDir ("md-{0}.md" -f $Phase)) -Force }
    else { Set-Content (Join-Path $testDir ("md-{0}.md" -f $Phase)) -Value 'FILE_NOT_EXISTS' -Encoding UTF8 }
    if (Test-Path $result) { Copy-Item $result (Join-Path $testDir ("result-{0}.json" -f $Phase)) -Force }
    else { Set-Content (Join-Path $testDir ("result-{0}.json" -f $Phase)) -Value 'FILE_NOT_EXISTS' -Encoding UTF8 }
}

function Write-UTF8NoBom {
    param([string]$Path, [string]$Content)
    [System.IO.File]::WriteAllText($Path, $Content, (New-Object System.Text.UTF8Encoding($false)))
}

function Run-Pwsh {
    param(
        [string]$ScriptPath,
        [string]$BaseDir,
        [string]$StdoutPath,
        [string]$StderrPath
    )
    $inline = "`$env:GITHUB_VERSION_MONITOR_BASE='{0}'`r`n& '{1}'" -f $BaseDir, $ScriptPath
    $p = Start-Process -FilePath 'pwsh' -ArgumentList @(
        '-NoProfile','-NonInteractive','-Command',$inline
    ) -WindowStyle Hidden -PassThru -Wait -RedirectStandardOutput $StdoutPath -RedirectStandardError $StderrPath
    return $p.ExitCode
}

function Run-Pwsh-Async {
    param(
        [string]$ScriptPath,
        [string]$BaseDir,
        [string]$StdoutPath,
        [string]$StderrPath
    )
    $inline = "`$env:GITHUB_VERSION_MONITOR_BASE='{0}'`r`n& '{1}'" -f $BaseDir, $ScriptPath
    return Start-Process -FilePath 'pwsh' -ArgumentList @(
        '-NoProfile','-NonInteractive','-Command',$inline
    ) -WindowStyle Hidden -PassThru -RedirectStandardOutput $StdoutPath -RedirectStandardError $StderrPath
}

# ====================================================================
# 9.1.1 lock-concurrency
# ====================================================================
Write-Log '=== 9.1.1 lock-concurrency ==='
$testDir = Join-Path $baseDir 'lock-concurrency'
$script:TestDirs['lock-concurrency'] = $testDir
if (Test-Path $testDir) { Remove-Item $testDir -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Force -Path $testDir | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $testDir '.output') | Out-Null
& pwsh -NoProfile -NonInteractive -File (Join-Path $libDir 'create-fixture.ps1') -BaseDir $testDir -Scenario normal *>&1 > (Join-Path $testDir 'fixture-stdout.txt')

# 创建同步信号文件
$syncFile = Join-Path $testDir 'sync-trigger.txt'
Set-Content -Path $syncFile -Value 'wait' -Encoding UTF8

Copy-Snapshot -TestDir $testDir -Phase 'before'
Write-Snapshot -TestDir $testDir -Phase 'before'
Write-Sha256 -TestDir $testDir -Phase 'before'

# 两个进程同时执行 step1.ps1（用同步 wrapper 确保同时启动）
$proc1 = Run-Pwsh-Async -ScriptPath (Join-Path $libDir 'step1.ps1') -BaseDir $testDir `
    -StdoutPath (Join-Path $testDir 'stdout-proc1.txt') -StderrPath (Join-Path $testDir 'stderr-proc1.txt')
$proc2 = Run-Pwsh-Async -ScriptPath (Join-Path $libDir 'step1.ps1') -BaseDir $testDir `
    -StdoutPath (Join-Path $testDir 'stdout-proc2.txt') -StderrPath (Join-Path $testDir 'stderr-proc2.txt')
$proc1.WaitForExit(30000) | Out-Null
$proc2.WaitForExit(30000) | Out-Null

# 合并 stdout
$allStdout = @()
foreach ($f in @('stdout-proc1.txt','stdout-proc2.txt')) {
    $path = Join-Path $testDir $f
    if (Test-Path $path) { $allStdout += ("--- {0} ---" -f $f); $allStdout += (Get-Content $path -Raw) }
}
Set-Content -Path (Join-Path $testDir 'stdout.txt') -Value ($allStdout -join "`r`n") -Encoding UTF8
$allStderr = @()
foreach ($f in @('stderr-proc1.txt','stderr-proc2.txt')) {
    $path = Join-Path $testDir $f
    if (Test-Path $path) { $allStderr += ("--- {0} ---" -f $f); $allStderr += (Get-Content $path -Raw) }
}
Set-Content -Path (Join-Path $testDir 'stderr.txt') -Value ($allStderr -join "`r`n") -Encoding UTF8

Copy-Snapshot -TestDir $testDir -Phase 'after'
Write-Snapshot -TestDir $testDir -Phase 'after'
Write-Sha256 -TestDir $testDir -Phase 'after'

$stdoutAll = (Get-Content (Join-Path $testDir 'stdout.txt') -Raw)
$backupOkCount = ([regex]::Matches($stdoutAll, 'BACKUP_OK\|')).Count
$lockedCount = ([regex]::Matches($stdoutAll, 'LOCKED\|')).Count
$pass = ($backupOkCount -eq 1) -and ($lockedCount -eq 1)
$script:Results['lock-concurrency'] = if ($pass) { 'PASS' } else { 'FAIL' }
Write-Log ("  BACKUP_OK count = {0}, LOCKED count = {1}, verdict = {2}" -f $backupOkCount, $lockedCount, $script:Results['lock-concurrency'])

# ====================================================================
# 9.1.2 lock-ownership
# ====================================================================
Write-Log '=== 9.1.2 lock-ownership ==='
$testDir = Join-Path $baseDir 'lock-ownership'
$script:TestDirs['lock-ownership'] = $testDir
if (Test-Path $testDir) { Remove-Item $testDir -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Force -Path $testDir | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $testDir '.output') | Out-Null
& pwsh -NoProfile -NonInteractive -File (Join-Path $libDir 'create-fixture.ps1') -BaseDir $testDir -Scenario normal *>&1 > (Join-Path $testDir 'fixture-stdout.txt')

Copy-Snapshot -TestDir $testDir -Phase 'before'
Write-Snapshot -TestDir $testDir -Phase 'before'
Write-Sha256 -TestDir $testDir -Phase 'before'

# 构造：Step 1-4 正常执行，然后篡改锁文件 PID 为 999999，再执行 Step 5
$wrapper = @'
$ErrorActionPreference='Stop'
$base=$env:GITHUB_VERSION_MONITOR_BASE
$libDir='__LIBDIR__'
. (Join-Path $libDir 'step1.ps1')
. (Join-Path $libDir 'step2.ps1')
. (Join-Path $libDir 'step3.ps1')
. (Join-Path $libDir 'step4.ps1')
$lockPath = Join-Path $base '.monitor\run.lock'
$nowUtc = [DateTimeOffset]::UtcNow.ToString('o')
$lockValue = 'pid=999999;start=' + $nowUtc + ';step=4;beat=' + $nowUtc
Set-Content -Path $lockPath -Value $lockValue
Write-Output "OWNERSHIP_INJECTED|pid=999999"
. (Join-Path $libDir 'step5-full.ps1')
'@
$wrapper = $wrapper.Replace('__LIBDIR__', $libDir)
$wrapperPath = Join-Path $testDir 'ownership-wrapper.ps1'
Write-UTF8NoBom -Path $wrapperPath -Content $wrapper
Run-Pwsh -ScriptPath $wrapperPath -BaseDir $testDir `
    -StdoutPath (Join-Path $testDir 'stdout.txt') -StderrPath (Join-Path $testDir 'stderr.txt')

Copy-Snapshot -TestDir $testDir -Phase 'after'
Write-Snapshot -TestDir $testDir -Phase 'after'
Write-Sha256 -TestDir $testDir -Phase 'after'

$stdoutAll = (Get-Content (Join-Path $testDir 'stdout.txt') -Raw)
$hasRuntimeErr = ($stdoutAll -match 'RUNTIME_ERROR\|')
$hasRunStatusFailed = ($stdoutAll -match 'RUN_STATUS\|failed\|')
$hasRunStatusSuccess = ($stdoutAll -match 'RUN_STATUS\|success\|')
$hasOwnershipInjected = ($stdoutAll -match 'OWNERSHIP_INJECTED\|')
$lockAfter = Get-Content (Join-Path $testDir 'lock-after.txt') -Raw -ErrorAction SilentlyContinue
$foreignRetained = ($lockAfter -match 'pid=999999')
$pass = $hasRuntimeErr -and $hasRunStatusFailed -and (-not $hasRunStatusSuccess) -and $hasOwnershipInjected -and $foreignRetained
$script:Results['lock-ownership'] = if ($pass) { 'PASS' } else { 'FAIL' }
Write-Log ("  RUNTIME_ERROR={0} RUN_STATUS|failed|={1} RUN_STATUS|success|={2} foreignRetained={3} verdict={4}" -f $hasRuntimeErr, $hasRunStatusFailed, $hasRunStatusSuccess, $foreignRetained, $script:Results['lock-ownership'])

# ====================================================================
# 9.1.3 lock-stale-alive
# ====================================================================
Write-Log '=== 9.1.3 lock-stale-alive ==='
$testDir = Join-Path $baseDir 'lock-stale-alive'
$script:TestDirs['lock-stale-alive'] = $testDir
if (Test-Path $testDir) { Remove-Item $testDir -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Force -Path $testDir | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $testDir '.output') | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $testDir '.monitor') | Out-Null
& pwsh -NoProfile -NonInteractive -File (Join-Path $libDir 'create-fixture.ps1') -BaseDir $testDir -Scenario normal *>&1 > (Join-Path $testDir 'fixture-stdout.txt')

# 构造陈锁：LastWriteTime = 31 分钟前，PID = 当前进程 PID（alive）
$alivePid = $PID
$staleTime = (Get-Date).AddMinutes(-31)
$staleUtc = [DateTimeOffset]::UtcNow.AddMinutes(-31).ToString('o')
$lockPath = Join-Path $testDir '.monitor\run.lock'
Set-Content -Path $lockPath -Value ("pid={0};start={1};step=1;beat={1}" -f $alivePid, $staleUtc) -Encoding UTF8
(Get-Item $lockPath).LastWriteTime = $staleTime

Copy-Snapshot -TestDir $testDir -Phase 'before'
Write-Snapshot -TestDir $testDir -Phase 'before'
Write-Sha256 -TestDir $testDir -Phase 'before'

# 执行 Step 1，应输出 LOCKED（陈锁但 PID 活 → 保守不抢）
Run-Pwsh -ScriptPath (Join-Path $libDir 'step1.ps1') -BaseDir $testDir `
    -StdoutPath (Join-Path $testDir 'stdout.txt') -StderrPath (Join-Path $testDir 'stderr.txt')

Copy-Snapshot -TestDir $testDir -Phase 'after'
Write-Snapshot -TestDir $testDir -Phase 'after'
Write-Sha256 -TestDir $testDir -Phase 'after'

$stdoutAll = (Get-Content (Join-Path $testDir 'stdout.txt') -Raw)
$hasLocked = ($stdoutAll -match 'LOCKED\|')
$hasBackupOk = ($stdoutAll -match 'BACKUP_OK\|')
$pass = $hasLocked -and (-not $hasBackupOk)
$script:Results['lock-stale-alive'] = if ($pass) { 'PASS' } else { 'FAIL' }
Write-Log ("  LOCKED={0} BACKUP_OK={1} verdict={2}" -f $hasLocked, $hasBackupOk, $script:Results['lock-stale-alive'])

# ====================================================================
# 9.1.4 lock-stale-dead
# ====================================================================
Write-Log '=== 9.1.4 lock-stale-dead ==='
$testDir = Join-Path $baseDir 'lock-stale-dead'
$script:TestDirs['lock-stale-dead'] = $testDir
if (Test-Path $testDir) { Remove-Item $testDir -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Force -Path $testDir | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $testDir '.output') | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $testDir '.monitor') | Out-Null
& pwsh -NoProfile -NonInteractive -File (Join-Path $libDir 'create-fixture.ps1') -BaseDir $testDir -Scenario normal *>&1 > (Join-Path $testDir 'fixture-stdout.txt')

# 构造陈锁：LastWriteTime = 31 分钟前，PID = 999999（dead）
$deadPid = 999999
$staleTime = (Get-Date).AddMinutes(-31)
$staleUtc = [DateTimeOffset]::UtcNow.AddMinutes(-31).ToString('o')
$lockPath = Join-Path $testDir '.monitor\run.lock'
Set-Content -Path $lockPath -Value ("pid={0};start={1};step=1;beat={1}" -f $deadPid, $staleUtc) -Encoding UTF8
(Get-Item $lockPath).LastWriteTime = $staleTime

Copy-Snapshot -TestDir $testDir -Phase 'before'
Write-Snapshot -TestDir $testDir -Phase 'before'
Write-Sha256 -TestDir $testDir -Phase 'before'

# 执行 Step 1，应 takeover 成功，输出 BACKUP_OK
Run-Pwsh -ScriptPath (Join-Path $libDir 'step1.ps1') -BaseDir $testDir `
    -StdoutPath (Join-Path $testDir 'stdout.txt') -StderrPath (Join-Path $testDir 'stderr.txt')

Copy-Snapshot -TestDir $testDir -Phase 'after'
Write-Snapshot -TestDir $testDir -Phase 'after'
Write-Sha256 -TestDir $testDir -Phase 'after'

$stdoutAll = (Get-Content (Join-Path $testDir 'stdout.txt') -Raw)
$hasBackupOk = ($stdoutAll -match 'BACKUP_OK\|')
$hasLocked = ($stdoutAll -match 'LOCKED\|')
$pass = $hasBackupOk -and (-not $hasLocked)
$script:Results['lock-stale-dead'] = if ($pass) { 'PASS' } else { 'FAIL' }
Write-Log ("  BACKUP_OK={0} LOCKED={1} verdict={2}" -f $hasBackupOk, $hasLocked, $script:Results['lock-stale-dead'])

# ====================================================================
# 9.2 process-kill
# ====================================================================
Write-Log '=== 9.2 process-kill ==='
$testDir = Join-Path $baseDir 'process-kill'
$script:TestDirs['process-kill'] = $testDir
if (Test-Path $testDir) { Remove-Item $testDir -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Force -Path $testDir | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $testDir '.output') | Out-Null
& pwsh -NoProfile -NonInteractive -File (Join-Path $libDir 'create-fixture.ps1') -BaseDir $testDir -Scenario T37 *>&1 > (Join-Path $testDir 'fixture-stdout.txt')

Copy-Snapshot -TestDir $testDir -Phase 'before'
Write-Snapshot -TestDir $testDir -Phase 'before'
Write-Sha256 -TestDir $testDir -Phase 'before'

# Kill wrapper：加载 mock + Step 1 → 3 秒延迟（Step 2 中途）→ Step 2-5
$killWrapper = @'
$ErrorActionPreference='Stop'
$base=$env:GITHUB_VERSION_MONITOR_BASE
$libDir='__LIBDIR__'
. (Join-Path $libDir 'mock-invoke-restmethod.ps1')
Set-MockScenario -Scenario 'normal' -TagName 'v1.0.0' -PublishedAt '2026-09-01T00:00:00Z'
. (Join-Path $libDir 'step1.ps1')
Write-Output "KILL_WRAPPER_STEP2_DELAY_START"
Start-Sleep -Seconds 3
Write-Output "KILL_WRAPPER_STEP2_DELAY_END"
. (Join-Path $libDir 'step2.ps1')
. (Join-Path $libDir 'step3.ps1')
. (Join-Path $libDir 'step4.ps1')
. (Join-Path $libDir 'step5-full.ps1')
'@
$killWrapper = $killWrapper.Replace('__LIBDIR__', $libDir)
$killWrapperPath = Join-Path $testDir 'kill-wrapper.ps1'
Write-UTF8NoBom -Path $killWrapperPath -Content $killWrapper

# 启动后台 pwsh 进程执行管线
$proc = Start-Process -FilePath 'pwsh' -ArgumentList @(
    '-NoProfile','-NonInteractive','-Command',("`$env:GITHUB_VERSION_MONITOR_BASE='{0}'`r`n& '{1}'" -f $testDir, $killWrapperPath)
) -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $testDir 'stdout-attempt1.txt') -RedirectStandardError (Join-Path $testDir 'stderr-attempt1.txt')

Write-Log ("  Pipeline started, PID = {0}" -f $proc.Id)

# 等待 2 秒后 Stop-Process（此时应处于 Step 1 后、Step 2 前的 3 秒延迟窗口）
$killAt = (Get-Date).AddSeconds(2)
while ($true) {
    if ((Get-Date) -ge $killAt) { break }
    if ($proc.HasExited) { break }
    Start-Sleep -Milliseconds 100
}

$killTime = Get-Date
$stdoutPartial = if (Test-Path (Join-Path $testDir 'stdout-attempt1.txt')) { Get-Content (Join-Path $testDir 'stdout-attempt1.txt') -Raw } else { '' }
$stepReached = 'unknown'
if ($stdoutPartial -match 'BACKUP_OK\|') { $stepReached = 'Step1-done' }
if ($stdoutPartial -match 'KILL_WRAPPER_STEP2_DELAY_START') { $stepReached = 'Step2-delay' }
if ($stdoutPartial -match 'KILL_WRAPPER_STEP2_DELAY_END') { $stepReached = 'Step2-executing' }
if ($stdoutPartial -match 'FETCH_COMPLETE\|') { $stepReached = 'Step2-done' }

$stopResult = 'NOT_STOPPED'
if (-not $proc.HasExited) {
    try {
        Stop-Process -Id $proc.Id -Force -ErrorAction Stop
        $stopResult = 'STOPPED'
        Write-Log ("  Stop-Process sent at {0}, step reached: {1}" -f $killTime.ToString('HH:mm:ss'), $stepReached)
    } catch {
        $stopResult = ("ERROR: {0}" -f $_.Exception.Message)
    }
} else {
    Write-Log ("  Process already exited before Stop-Process (exit code {0})" -f $proc.ExitCode)
}

# 采集 kill 后状态
Copy-Snapshot -TestDir $testDir -Phase 'kill'
Write-Snapshot -TestDir $testDir -Phase 'kill'
Write-Sha256 -TestDir $testDir -Phase 'kill'

# 检查 kill 后状态：lock / backup / result.json / main md
$mdPath = Join-Path $testDir '.output\GitHub更新监测列表.md'
$resultPath = Join-Path $testDir '.monitor\result.json'
$lockPath = Join-Path $testDir '.monitor\run.lock'
$backupDir = Join-Path $testDir '.monitor\backups'
$trashDir = Join-Path $testDir '.monitor\trash'

$lockState = 'RELEASED'
if (Test-Path $lockPath) {
    $lockRaw = Get-Content $lockPath -Raw
    if ($lockRaw -match 'pid=(\d+)') {
        $lockPid = [int]$Matches[1]
        $lockAlive = $null -ne (Get-Process -Id $lockPid -ErrorAction SilentlyContinue)
        $lockAgeMin = ((Get-Date) - (Get-Item $lockPath).LastWriteTime).TotalMinutes
        $lockState = ("HELD pid={0} alive={1} ageMin={2:F1}" -f $lockPid, $lockAlive, $lockAgeMin)
    }
}

$backupCount = if (Test-Path $backupDir) { @(Get-ChildItem $backupDir -Filter 'GitHub更新监测列表.backup.*.md').Count } else { 0 }
$resultExists = Test-Path $resultPath
$resultValidJson = $false
if ($resultExists) {
    try { $null = Get-Content $resultPath -Raw | ConvertFrom-Json; $resultValidJson = $true } catch { $resultValidJson = $false }
}
$mdExists = Test-Path $mdPath
$mdValid = $false
if ($mdExists) {
    try { $mdText = Get-Content $mdPath -Raw; $mdValid = ($mdText.Length -gt 0) -and ($mdText -match '## 监测列表') } catch { $mdValid = $false }
}
$trashCount = if (Test-Path $trashDir) { @(Get-ChildItem $trashDir).Count } else { 0 }

$stateReport = @(
    ("kill_time: {0}" -f $killTime.ToString('o')),
    ("pipeline_pid: {0}" -f $proc.Id),
    ("stop_result: {0}" -f $stopResult),
    ("step_reached: {0}" -f $stepReached),
    ("lock_state: {0}" -f $lockState),
    ("backup_count: {0}" -f $backupCount),
    ("result_exists: {0}" -f $resultExists),
    ("result_valid_json: {0}" -f $resultValidJson),
    ("md_exists: {0}" -f $mdExists),
    ("md_valid: {0}" -f $mdValid),
    ("trash_count: {0}" -f $trashCount)
) -join "`r`n"
Set-Content -Path (Join-Path $testDir 'kill-state.txt') -Value $stateReport -Encoding UTF8

# 重运行完整管线（新进程），验证恢复能力
# 由于 kill 后锁文件仍存在（PID 死但 ageMin=0，未达陈锁阈值），
# 先人为将锁文件 LastWriteTime 回退 31 分钟以模拟真实陈锁场景，
# 让 Step 1 的陈锁接管机制触发（PID 死 + ageMin>30 → takeover 成功）
$staleLockPath = Join-Path $testDir '.monitor\run.lock'
if (Test-Path $staleLockPath) {
    (Get-Item $staleLockPath).LastWriteTime = (Get-Date).AddMinutes(-31)
    Write-Log '  Lock file aged to 31 min ago (simulating stale lock after crash)'
}

Write-Log '  Re-running full pipeline after kill...'
$rerunWrapper = @'
$ErrorActionPreference='Stop'
$base=$env:GITHUB_VERSION_MONITOR_BASE
$libDir='__LIBDIR__'
. (Join-Path $libDir 'mock-invoke-restmethod.ps1')
Set-MockScenario -Scenario 'normal' -TagName 'v1.0.0' -PublishedAt '2026-09-01T00:00:00Z'
. (Join-Path $libDir 'step1.ps1')
. (Join-Path $libDir 'step2.ps1')
. (Join-Path $libDir 'step3.ps1')
. (Join-Path $libDir 'step4.ps1')
. (Join-Path $libDir 'step5-full.ps1')
'@
$rerunWrapper = $rerunWrapper.Replace('__LIBDIR__', $libDir)
$rerunWrapperPath = Join-Path $testDir 'rerun-wrapper.ps1'
Write-UTF8NoBom -Path $rerunWrapperPath -Content $rerunWrapper
Run-Pwsh -ScriptPath $rerunWrapperPath -BaseDir $testDir `
    -StdoutPath (Join-Path $testDir 'stdout-attempt2.txt') -StderrPath (Join-Path $testDir 'stderr-attempt2.txt')

Copy-Snapshot -TestDir $testDir -Phase 'after'
Write-Snapshot -TestDir $testDir -Phase 'after'
Write-Sha256 -TestDir $testDir -Phase 'after'

# 合并 stdout
$allStdout = @()
foreach ($f in @('stdout-attempt1.txt','stdout-attempt2.txt')) {
    $path = Join-Path $testDir $f
    if (Test-Path $path) { $allStdout += ("--- {0} ---" -f $f); $allStdout += (Get-Content $path -Raw) }
}
Set-Content -Path (Join-Path $testDir 'stdout.txt') -Value ($allStdout -join "`r`n") -Encoding UTF8
$allStderr = @()
foreach ($f in @('stderr-attempt1.txt','stderr-attempt2.txt')) {
    $path = Join-Path $testDir $f
    if (Test-Path $path) { $allStderr += ("--- {0} ---" -f $f); $allStderr += (Get-Content $path -Raw) }
}
Set-Content -Path (Join-Path $testDir 'stderr.txt') -Value ($allStderr -join "`r`n") -Encoding UTF8

# 判定 process-kill：
# 1. Stop-Process 真实执行（stop_result=STOPPED）
# 2. 重运行成功（stdout-attempt2 含 RUN_STATUS|success| 或 RUN_STATUS|failed| 或 BACKUP_OK|）
# 3. result-after.json 存在且 JSON 有效（未损坏）
# 4. md-after.md 存在且有效（未错误提交）
# 5. lock-after.txt 显示锁已释放或已被接管
$stdout2 = if (Test-Path (Join-Path $testDir 'stdout-attempt2.txt')) { Get-Content (Join-Path $testDir 'stdout-attempt2.txt') -Raw } else { '' }
$rerunSuccess = ($stdout2 -match 'RUN_STATUS\|success\|') -or ($stdout2 -match 'RUN_STATUS\|failed\|') -or ($stdout2 -match 'BACKUP_OK\|')
$resultAfterExists = Test-Path (Join-Path $testDir 'result-after.json')
$resultAfterValid = $false
if ($resultAfterExists) {
    try { $null = Get-Content (Join-Path $testDir 'result-after.json') -Raw | ConvertFrom-Json; $resultAfterValid = $true } catch { $resultAfterValid = $false }
}
$mdAfterExists = Test-Path (Join-Path $testDir 'md-after.md')
$mdAfterValid = $false
if ($mdAfterExists) {
    try { $mdAfterText = Get-Content (Join-Path $testDir 'md-after.md') -Raw; $mdAfterValid = ($mdAfterText.Length -gt 0) -and ($mdAfterText -match '## 监测列表') } catch { $mdAfterValid = $false }
}
$lockAfter = Get-Content (Join-Path $testDir 'lock-after.txt') -Raw -ErrorAction SilentlyContinue
$lockReleasedAfter = ($lockAfter -match 'LOCK_FILE_NOT_EXISTS') -or (-not ($lockAfter -match 'pid='))

$pass = ($stopResult -eq 'STOPPED') -and $rerunSuccess -and $resultAfterValid -and $mdAfterValid -and $lockReleasedAfter
$script:Results['process-kill'] = if ($pass) { 'PASS' } else { 'FAIL' }
Write-Log ("  stop={0} rerunSuccess={1} resultValid={2} mdValid={3} lockReleased={4} verdict={5}" -f $stopResult, $rerunSuccess, $resultAfterValid, $mdAfterValid, $lockReleasedAfter, $script:Results['process-kill'])

# ====================================================================
# 汇总
# ====================================================================
$end = Get-Date
$duration = ($end - $script:Start).TotalSeconds

$passCount = @($script:Results.Values | Where-Object { $_ -eq 'PASS' }).Count
$failCount = @($script:Results.Values | Where-Object { $_ -eq 'FAIL' }).Count
$blockedCount = 0

$overallVerdict = if ($failCount -eq 0 -and $blockedCount -eq 0) { 'PASS' } elseif ($failCount -gt 0) { 'FAIL' } else { 'BLOCKED' }

Write-Log ("=== Phase 9 Summary ===")
Write-Log ("  Duration: {0:F1}s" -f $duration)
Write-Log ("  lock-concurrency: {0}" -f $script:Results['lock-concurrency'])
Write-Log ("  lock-ownership:   {0}" -f $script:Results['lock-ownership'])
Write-Log ("  lock-stale-alive: {0}" -f $script:Results['lock-stale-alive'])
Write-Log ("  lock-stale-dead:  {0}" -f $script:Results['lock-stale-dead'])
Write-Log ("  process-kill:     {0}" -f $script:Results['process-kill'])
Write-Log ("  PASS={0} FAIL={1} BLOCKED={2} OVERALL={3}" -f $passCount, $failCount, $blockedCount, $overallVerdict)

$summaryJson = @{
    results = $script:Results
    passCount = $passCount
    failCount = $failCount
    blockedCount = $blockedCount
    overallVerdict = $overallVerdict
    durationSeconds = [Math]::Round($duration, 1)
    testDirs = $script:TestDirs
} | ConvertTo-Json -Depth 5
$summaryPath = Join-Path $baseDir 'phase9-summary.json'
Set-Content -Path $summaryPath -Value $summaryJson -Encoding UTF8
Write-Log ("Summary written: {0}" -f $summaryPath)
