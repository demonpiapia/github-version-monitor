# phase5-orchestrator.ps1 - Phase 5 T39 Commit 成功 + 锁释放失败回归（硬门槛）
# 目标：验证 SKILL-v1.10 在 commitSucceeded=true + lockReleased=false 时
#       输出 RUN_STATUS|failed|，绝不输出 RUN_STATUS|success|
# 隔离：通过 GITHUB_VERSION_MONITOR_BASE 指向 T39 测试子目录，禁止触碰生产根目录
# 前置：Phase 1 (lib/step1-4.ps1, lib/step5-t39-harness.ps1, lib/create-fixture.ps1) 已完成
#       Phase 1 stdout-verification.txt 决策 PIPELINE_OK → Step 1-4 使用 dot-source 同进程执行
#
# 关键约束：
#   - 所有测试必须在 T39 测试子目录中运行，通过 GITHUB_VERSION_MONITOR_BASE 隔离
#   - 禁止触碰生产根目录 .output/GitHub更新监测列表.md
#   - 硬门槛：如出现 COMMIT_OK| + RUN_STATUS|success| 组合 → FAIL + P1 + PRODUCTION_NOT_READY
#
# 执行架构（同进程 dot-source）：
#   Step 1-4 由 t39-wrapper.ps1 在同进程内 dot-source 执行（确保 $PID 一致，锁 ownership 校验通过）
#   Step 5 由 step5-t39-harness.ps1 在同进程内 dot-source 执行（harness 内部注入 pid=999999）
#   两个 pwsh 子进程共享 $PID 语义，因为锁文件在 Step 1 创建后写入当前 PID，
#   Step 4 结束时锁仍存在，Step 5 harness 在同进程内读取到相同 PID → ownership 校验通过

param([string]$ProjectRoot)

$ErrorActionPreference = 'Continue'

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

# ============================================================
# Main execution
# ============================================================

$startTime = Get-Date
Write-Log "Phase 5 T39 Execution Started"
Write-Log "ProjectRoot: $ProjectRoot"
Write-Log "PVDir: $pvDir"
Write-Log "PwshPath: $pwshPath"

# 前置：读取 Phase 1 stdout 透传决策
$stdoutVerifyFile = Join-Path $pvDir 'lib\stdout-verification.txt'
$stdoutVerifyContent = Get-Content $stdoutVerifyFile -Raw -ErrorAction SilentlyContinue
$decisionPipelineOk = ($stdoutVerifyContent -match 'DECISION:\s*PIPELINE_OK')
Write-Log "Phase 1 stdout 透传决策 PIPELINE_OK = $decisionPipelineOk"
if (-not $decisionPipelineOk) {
    Write-Log "ERROR: Phase 1 stdout 透传决策非 PIPELINE_OK，T39 应改为逐 step 独立执行。当前策略与计划不符，中止。"
    exit 1
}

# ============================================================
# T39: commitSucceeded=true + lockReleased=false → RUN_STATUS|failed|
# Fixture: 复用 T37 场景（2 个真实仓库，触发 review）
#   - microsoft/vscode localVer=1.0.0 → 触发 versionJump → review=true
#   - torvalds/linux localVer=6.5.0 → 404 → review=true
#   → 完整 Step 1-4 后 result.json 就绪，Step 5 harness 触发 commit + 锁释放失败
# ============================================================
Write-Log "=== T39: commitSucceeded=true + lockReleased=false → RUN_STATUS|failed| ==="
$testDir = Join-Path $pvDir 'T39'
$baseDir = $testDir

# Clean previous test dir
if (Test-Path $baseDir) { Remove-Item $baseDir -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Force -Path $baseDir | Out-Null

# Generate fixture
Write-Log "T39: Generating fixture (scenario=T37)"
$fixtureStdout = Join-Path $testDir 'fixture-stdout.txt'
& $pwshPath -NoProfile -NonInteractive -File (Join-Path $libDir 'create-fixture.ps1') -BaseDir $baseDir -Scenario 'T37' *> $fixtureStdout
$fixtureExit = $LASTEXITCODE
Write-Log "T39: fixture exit code = $fixtureExit"
if ($fixtureExit -ne 0) {
    Write-Log "T39: fixture generation FAILED"
    exit 1
}

# Capture before state (md / result.json / lock / sha256 / dir listing)
$mdPath = Join-Path $baseDir '.output\GitHub更新监测列表.md'
$resultPath = Join-Path $baseDir '.monitor\result.json'
$lockPath = Join-Path $baseDir '.monitor\run.lock'
$beforeDir = Join-Path $testDir 'before'
$afterDir = Join-Path $testDir 'after'
if (-not (Test-Path $beforeDir)) { New-Item -ItemType Directory -Force -Path $beforeDir | Out-Null }
if (-not (Test-Path $afterDir)) { New-Item -ItemType Directory -Force -Path $afterDir | Out-Null }

$mdBefore = Join-Path $testDir 'md-before.md'
$resultBefore = Join-Path $testDir 'result-before.json'
$lockBefore = Join-Path $testDir 'lock-before.txt'
if (Test-Path $mdPath) { Copy-Item $mdPath $mdBefore -Force } else { 'MD_FILE_NOT_EXISTS' | Set-Content $mdBefore -Encoding UTF8 }
if (Test-Path $resultPath) { Copy-Item $resultPath $resultBefore -Force } else { '{"note":"result.json not exists before run"}' | Set-Content $resultBefore -Encoding UTF8 }
if (Test-Path $lockPath) { Get-Content $lockPath -Raw | Set-Content $lockBefore -Encoding UTF8 } else { 'LOCK_FILE_NOT_EXISTS' | Set-Content $lockBefore -Encoding UTF8 }

$shaBefore = Join-Path $testDir 'sha256-before.txt'
$sb = @()
$sb += ("main_md: {0}" -f (Get-Sha256 $mdPath))
$sb += ("result.json: {0}" -f (Get-Sha256 $resultPath))
$sb += ("run.lock: {0}" -f (Get-Sha256 $lockPath))
$sb | Set-Content $shaBefore -Encoding UTF8

$beforeListing = Join-Path $testDir 'before\dir-listing.txt'
Get-ChildItem $baseDir -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName.Replace($baseDir,'') } | Set-Content $beforeListing -Encoding UTF8
Write-Log "T39: before state captured"

# ============================================================
# Create wrapper script: dot-source Step 1-4 + Step 5 harness in same process
# Use single-quoted here-string to avoid PowerShell variable expansion
# KEY: wrapper + harness must run in SAME process so $PID is consistent
#      (Step 1 creates lock with current PID; Step 5 harness checks ownership)
# ============================================================
$wrapperPath = Join-Path $testDir 't39-wrapper.ps1'
$libDirEscaped = $libDir -replace "'", "''"
$wrapperContent = @'
# t39-wrapper.ps1 - T39 同进程 wrapper（Step 1-4 + Step 5 harness 同进程）
# 在同进程内 dot-source Step 1-4 + Step 5 harness，确保 $PID 一致
# Step 5 harness 内部在 L636/L637 之间注入 pid=999999
param([string]$BaseDir)
$ErrorActionPreference = 'Stop'
$env:GITHUB_VERSION_MONITOR_BASE = $BaseDir
$libDir = '__LIBDIR__'
$lockPath = Join-Path (Join-Path $BaseDir '.monitor') 'run.lock'

Write-Output "=== STEP 1 START ==="
. (Join-Path $libDir 'step1.ps1')
Write-Output "=== STEP 1 END ==="

# Capture lock state after Step 1 (before harness injection)
if (Test-Path $lockPath) {
    Get-Content $lockPath -Raw | Set-Content (Join-Path $BaseDir 'lock-after-step1.txt') -Encoding UTF8
} else {
    'LOCK_FILE_NOT_EXISTS' | Set-Content (Join-Path $BaseDir 'lock-after-step1.txt') -Encoding UTF8
}

Write-Output "=== STEP 2 START ==="
. (Join-Path $libDir 'step2.ps1')
Write-Output "=== STEP 2 END ==="

Write-Output "=== STEP 3 START ==="
. (Join-Path $libDir 'step3.ps1')
Write-Output "=== STEP 3 END ==="

Write-Output "=== STEP 4 START ==="
. (Join-Path $libDir 'step4.ps1')
Write-Output "=== STEP 4 END ==="

Write-Output "=== STEP 5 START (T39 harness) ==="
. (Join-Path $libDir 'step5-t39-harness.ps1')
Write-Output "=== STEP 5 END ==="
'@
$wrapperContent = $wrapperContent -replace '__LIBDIR__', $libDirEscaped
[System.IO.File]::WriteAllText($wrapperPath, $wrapperContent, (New-Object System.Text.UTF8Encoding($false)))
Write-Log "T39: wrapper script created at $wrapperPath"

# ============================================================
# Execute Step 1-4 + Step 5 harness (single process, dot-source)
# ============================================================
$stdoutStep14 = Join-Path $testDir 'stdout-step1-4.txt'
$stderrStep14 = Join-Path $testDir 'stderr-step1-4.txt'
& $pwshPath -NoProfile -NonInteractive -File $wrapperPath -BaseDir $baseDir *> $stdoutStep14
$exitStep14 = $LASTEXITCODE
Write-Log "T39: Step 1-4 + Step 5 harness exit code = $exitStep14"

# Capture lock state after wrapper (this is lock-after-modify: PID=999999, ownership check failed)
# The harness already modified the lock file to pid=999999 and attempted release (which failed)
$lockAfterModify = Join-Path $testDir 'lock-after-modify.txt'
if (Test-Path $lockPath) {
    Get-Content $lockPath -Raw | Set-Content $lockAfterModify -Encoding UTF8
} else {
    'LOCK_FILE_NOT_EXISTS' | Set-Content $lockAfterModify -Encoding UTF8
}
Write-Log "T39: lock-after-modify.txt captured (PID=999999, ownership check failed)"

# Also capture stdout-step5.txt by extracting Step 5 portion from combined stdout
$stdoutStep5 = Join-Path $testDir 'stdout-step5.txt'
$stderrStep5 = Join-Path $testDir 'stderr-step5.txt'
$allLines = @()
if (Test-Path $stdoutStep14) { $allLines = @(Get-Content $stdoutStep14 -ErrorAction SilentlyContinue) }
$step5StartIdx = -1
for ($i = 0; $i -lt $allLines.Count; $i++) {
    if ($allLines[$i] -match '=== STEP 5 START') { $step5StartIdx = $i; break }
}
if ($step5StartIdx -ge 0) {
    $step5Lines = @($allLines[$step5StartIdx..($allLines.Count-1)])
    $step5Lines | Set-Content $stdoutStep5 -Encoding UTF8
} else {
    '' | Set-Content $stdoutStep5 -Encoding UTF8
}
'' | Set-Content $stderrStep5 -Encoding UTF8
Write-Log "T39: stdout-step5.txt extracted"

# For backward-compat: also keep stdout-step1-4.txt as the full combined output
$stdoutStep14Full = Join-Path $testDir 'stdout-step1-4-full.txt'
if (Test-Path $stdoutStep14) { Copy-Item $stdoutStep14 $stdoutStep14Full -Force }

# Capture after state
$mdAfter = Join-Path $testDir 'md-after.md'
$resultAfter = Join-Path $testDir 'result-after.json'
$lockAfter = Join-Path $testDir 'lock-after.txt'
if (Test-Path $mdPath) { Copy-Item $mdPath $mdAfter -Force } else { 'MD_FILE_NOT_EXISTS' | Set-Content $mdAfter -Encoding UTF8 }
if (Test-Path $resultPath) { Copy-Item $resultPath $resultAfter -Force } else { '{"note":"result.json not exists after run"}' | Set-Content $resultAfter -Encoding UTF8 }
if (Test-Path $lockPath) { Get-Content $lockPath -Raw | Set-Content $lockAfter -Encoding UTF8 } else { 'LOCK_FILE_NOT_EXISTS' | Set-Content $lockAfter -Encoding UTF8 }

# Overwrite lock-before.txt with the post-Step 1 state (the actual lock state before harness injection)
$lockAfterStep1 = Join-Path $baseDir 'lock-after-step1.txt'
if (Test-Path $lockAfterStep1) {
    Copy-Item $lockAfterStep1 $lockBefore -Force
}

$shaAfter = Join-Path $testDir 'sha256-after.txt'
$sa = @()
$sa += ("main_md: {0}" -f (Get-Sha256 $mdPath))
$sa += ("result.json: {0}" -f (Get-Sha256 $resultPath))
$sa += ("run.lock: {0}" -f (Get-Sha256 $lockPath))
$sa | Set-Content $shaAfter -Encoding UTF8

$afterListing = Join-Path $testDir 'after\dir-listing.txt'
Get-ChildItem $baseDir -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName.Replace($baseDir,'') } | Set-Content $afterListing -Encoding UTF8
Write-Log "T39: after state captured"

# ============================================================
# Combine stdout: stdout-step1-4.txt IS the full combined output
# (wrapper runs Step 1-4 + Step 5 harness in single process)
# stdout-step5.txt is the extracted Step 5 portion only
# ============================================================
$stdoutCombined = Join-Path $testDir 'stdout.txt'
$stderrCombined = Join-Path $testDir 'stderr.txt'
if (Test-Path $stdoutStep14) { Copy-Item $stdoutStep14 $stdoutCombined -Force }
if (Test-Path $stderrStep14) { Copy-Item $stderrStep14 $stderrCombined -Force } else { '' | Set-Content $stderrCombined -Encoding UTF8 }
Write-Log "T39: stdout.txt / stderr.txt combined"

# ============================================================
# Judge
# ============================================================
$stdout = Get-Content $stdoutCombined -Raw -ErrorAction SilentlyContinue
if (-not $stdout) { $stdout = '' }

$commitOkPresent = ($stdout -match [regex]::Escape('COMMIT_OK|'))
$runtimeErrorPresent = ($stdout -match [regex]::Escape('RUNTIME_ERROR|'))
$runStatusFailedPresent = ($stdout -match [regex]::Escape('RUN_STATUS|failed|'))
$runStatusSuccessPresent = ($stdout -match [regex]::Escape('RUN_STATUS|success|'))
$runStatusSuccessAbsent = -not $runStatusSuccessPresent

Write-Log "T39: COMMIT_OK| present = $commitOkPresent"
Write-Log "T39: RUNTIME_ERROR| present = $runtimeErrorPresent"
Write-Log "T39: RUN_STATUS|failed| present = $runStatusFailedPresent"
Write-Log "T39: RUN_STATUS|success| absent = $runStatusSuccessAbsent"

# Verify lock states
$lockBeforeContent = Get-Content $lockBefore -Raw -ErrorAction SilentlyContinue
$lockAfterModifyContent = Get-Content $lockAfterModify -Raw -ErrorAction SilentlyContinue
$lockAfterContent = Get-Content $lockAfter -Raw -ErrorAction SilentlyContinue

$lockBeforeHasPid = ($lockBeforeContent -match 'pid=\d+')
$lockAfterModifyHasPid999999 = ($lockAfterModifyContent -match 'pid=999999')
$lockAfterExists = -not ($lockAfterContent -match 'LOCK_FILE_NOT_EXISTS')
$lockAfterHasPid999999 = ($lockAfterContent -match 'pid=999999')

Write-Log "T39: lock-before has pid = $lockBeforeHasPid"
Write-Log "T39: lock-after-modify has pid=999999 = $lockAfterModifyHasPid999999"
Write-Log "T39: lock-after exists (not released) = $lockAfterExists"
Write-Log "T39: lock-after has pid=999999 = $lockAfterHasPid999999"

# ============================================================
# Core invariant verification
# commitSucceeded=true + lockReleased=false → RUN_STATUS|failed|
# ============================================================
$commitSucceeded = $commitOkPresent
$lockReleased = -not $lockAfterExists
$invariantHolds = $commitSucceeded -and (-not $lockReleased) -and $runStatusFailedPresent -and $runStatusSuccessAbsent

Write-Log "T39: commitSucceeded = $commitSucceeded"
Write-Log "T39: lockReleased = $lockReleased"
Write-Log "T39: invariant (commitSucceeded=true + lockReleased=false → RUN_STATUS|failed|) = $invariantHolds"

# ============================================================
# Overall verdict
# ============================================================
$allPass = ($commitOkPresent -and $runtimeErrorPresent -and $runStatusFailedPresent -and $runStatusSuccessAbsent -and $lockAfterModifyHasPid999999 -and $lockAfterExists -and $invariantHolds)
if ($allPass) { $t39Verdict = 'PASS' } else { $t39Verdict = 'FAIL' }

Write-Log "T39: verdict = $t39Verdict"

# ============================================================
# Generate test-report.md
# ============================================================
$endTime = Get-Date
$duration = ($endTime - $startTime).TotalSeconds
$durationStr = [string]::Format('{0:N1}', $duration)
$endTimeStr = $endTime.ToString('yyyy-MM-dd HH:mm:ss')

$stdoutLines = @($stdout -split "`r?`n")
$commitLine = ($stdoutLines | Where-Object { $_ -match 'COMMIT_OK\|' } | Select-Object -First 1)
$runtimeErrorLine = ($stdoutLines | Where-Object { $_ -match 'RUNTIME_ERROR\|' } | Select-Object -First 1)
$runStatusFailedLine = ($stdoutLines | Where-Object { $_ -match 'RUN_STATUS\|failed\|' } | Select-Object -First 1)
$runStatusSuccessLine = ($stdoutLines | Where-Object { $_ -match 'RUN_STATUS\|success\|' } | Select-Object -First 1)

$shaBeforeContent = Get-Content (Join-Path $testDir 'sha256-before.txt') -Raw
$shaAfterContent = Get-Content (Join-Path $testDir 'sha256-after.txt') -Raw

$verdictNote = if ($t39Verdict -eq 'PASS') {
    "T39 核心 invariant 验证通过：commitSucceeded=true + lockReleased=false → RUN_STATUS|failed|。COMMIT_OK| 存在（提交本身成功），RUNTIME_ERROR| 存在（锁释放失败），RUN_STATUS|failed| 存在，RUN_STATUS|success| 不存在。lock-after-modify.txt 中 PID=999999，lock-after.txt 确认锁仍存在（未释放）。符合 SKILL-v1.10 contract，未破坏上一版本已经正确的 invariant。"
} else {
    "T39 未通过：详见上表 FAIL 项。核心 invariant (commitSucceeded=true + lockReleased=false → RUN_STATUS|failed|) 违反 = $(-not $invariantHolds)。"
}

$reportPath = Join-Path $testDir 'test-report.md'
$reportContent = @"
# T39 Test Report — Commit 成功 + 锁释放失败 → RUN_STATUS|failed|

> **测试目标**: 验证 SKILL-v1.10 在 commitSucceeded=true + lockReleased=false 时输出 RUN_STATUS|failed|，绝不输出 RUN_STATUS|success|
> **构造方法**: 同进程 dot-source Step 1-4 → Step 5 harness（内部注入 pid=999999）
> **执行时间**: $endTimeStr
> **执行耗时**: $durationStr 秒
> **执行环境**: Windows + PowerShell 7.x

## 构造方法详情

1. 通过 GITHUB_VERSION_MONITOR_BASE 隔离到 T39/ 子目录
2. 生成 fixture（create-fixture.ps1 -Scenario T37）：2 个真实仓库
   - microsoft/vscode localVer=1.0.0（触发 versionJump → review=true）
   - torvalds/linux localVer=6.5.0（404 → review=true）
3. 采集 before 状态（md / result.json / run.lock / SHA256 / 目录清单）
4. 执行 t39-wrapper.ps1（dot-source Step 1-4 同进程），确保 result.json 就绪、锁存在且 PID=当前进程
5. 执行 step5-t39-harness.ps1（dot-source Step 5 同进程，harness 内部在 L636/L637 之间注入 pid=999999）
6. 采集 after 状态 + lock-after-modify.txt（harness 注入后、锁释放尝试前的锁状态）
7. 判定核心 invariant：commitSucceeded=true + lockReleased=false → RUN_STATUS|failed|

## 验证项

| 验证项 | 期望 | 结果 |
|---|---|---|
| COMMIT_OK\| | 存在（提交本身成功） | **$($commitOkPresent ? 'PASS' : 'FAIL')** |
| RUNTIME_ERROR\| | 存在（锁释放失败） | **$($runtimeErrorPresent ? 'PASS' : 'FAIL')** |
| RUN_STATUS\|failed\| | 存在 | **$($runStatusFailedPresent ? 'PASS' : 'FAIL')** |
| RUN_STATUS\|success\| | 不存在 | **$($runStatusSuccessAbsent ? 'PASS' : 'FAIL')** |
| lock-after-modify.txt PID=999999 | 存在 | **$($lockAfterModifyHasPid999999 ? 'PASS' : 'FAIL')** |
| lock-after.txt 锁仍存在（未释放） | 存在 | **$($lockAfterExists ? 'PASS' : 'FAIL')** |
| 核心 invariant (commitSucceeded=true + lockReleased=false → RUN_STATUS\|failed\|) | 成立 | **$($invariantHolds ? 'PASS' : 'FAIL')** |

## 核心 invariant 验证

```
commitSucceeded = $commitSucceeded
lockReleased = $lockReleased
        ↓
RUN_STATUS|failed| = $runStatusFailedPresent
RUN_STATUS|success| = $runStatusSuccessPresent
```

**invariant 成立 = $invariantHolds**

即：commit 成功但锁未释放时，绝不输出 RUN_STATUS|success|。

## 关键 stdout 行

~~~
$commitLine
$runtimeErrorLine
$runStatusFailedLine
$runStatusSuccessLine
~~~

## SHA256 对比

### Before
~~~
$shaBeforeContent
~~~

### After
~~~
$shaAfterContent
~~~

## Lock 状态

### Before (Step 1 创建后，PID=当前进程)
~~~
$lockBeforeContent
~~~

### After Step 1-4 (锁仍存在，PID=当前进程)
~~~
$lockAfterModifyContent
~~~

### After Harness (PID=999999，ownership 校验失败，锁未释放)
~~~
$lockAfterContent
~~~

## 判定

**$t39Verdict**

$verdictNote
"@
[System.IO.File]::WriteAllText($reportPath, $reportContent, (New-Object System.Text.UTF8Encoding($false)))
Write-Log "T39: test-report.md written"

# ============================================================
# Generate phase5-stdout.txt / phase5-stderr.txt / phase5-report.md
# ============================================================
$phase5Stdout = Join-Path $pvDir 'phase5-stdout.txt'
$phase5Stderr = Join-Path $pvDir 'phase5-stderr.txt'
$phase5Report = Join-Path $pvDir 'phase5-report.md'

Get-Content $stdoutCombined -Raw | Set-Content $phase5Stdout -Encoding UTF8
if (Test-Path $stderrCombined) {
    Get-Content $stderrCombined -Raw | Set-Content $phase5Stderr -Encoding UTF8
} else {
    '' | Set-Content $phase5Stderr -Encoding UTF8
}

$phase5ReportContent = @"
# Phase 5 Report — T39 Commit 成功 + 锁释放失败回归

> **Phase**: 5
> **模块**: T39 — commitSucceeded=true + lockReleased=false → RUN_STATUS|failed|
> **优先级**: 硬门槛
> **执行时间**: $endTimeStr
> **执行耗时**: $durationStr 秒
> **判定**: **$t39Verdict**

## 执行摘要

- 测试目标: 验证 v1.10 没有破坏上一版本已经正确的 invariant
- Fixture: 2 个真实仓库（microsoft/vscode localVer=1.0.0 + torvalds/linux localVer=6.5.0）
- 执行方式: t39-wrapper.ps1 (dot-source Step 1-4) + step5-t39-harness.ps1 (dot-source Step 5，内部注入 pid=999999)
- 隔离: GITHUB_VERSION_MONITOR_BASE = <T39 test dir>
- 生产根目录 .output/GitHub更新监测列表.md: 未触碰

## 验证项结果

| 验证项 | 结果 |
|---|---|
| COMMIT_OK\| 存在 | $($commitOkPresent ? 'PASS' : 'FAIL') |
| RUNTIME_ERROR\| 存在 | $($runtimeErrorPresent ? 'PASS' : 'FAIL') |
| RUN_STATUS\|failed\| 存在 | $($runStatusFailedPresent ? 'PASS' : 'FAIL') |
| RUN_STATUS\|success\| 不存在 | $($runStatusSuccessAbsent ? 'PASS' : 'FAIL') |
| lock-after-modify.txt PID=999999 | $($lockAfterModifyHasPid999999 ? 'PASS' : 'FAIL') |
| lock-after.txt 锁仍存在（未释放） | $($lockAfterExists ? 'PASS' : 'FAIL') |
| 核心 invariant 成立 | $($invariantHolds ? 'PASS' : 'FAIL') |

## 关键 stdout 行

~~~
$commitLine
$runtimeErrorLine
$runStatusFailedLine
$runStatusSuccessLine
~~~

## Lock 状态

### Before (Step 1 创建后)
~~~
$lockBeforeContent
~~~

### After Harness (PID=999999，锁未释放)
~~~
$lockAfterContent
~~~

## 核心 invariant 验证

```
commitSucceeded = $commitSucceeded
lockReleased = $lockReleased
        ↓
RUN_STATUS|failed| = $runStatusFailedPresent
RUN_STATUS|success| = $runStatusSuccessPresent
```

**invariant 成立 = $invariantHolds**

## 产出文件

- T39/before/ — 目录清单
- T39/after/ — 目录清单
- T39/stdout.txt — 完整 stdout（Step 1-4 + Step 5 harness）
- T39/stderr.txt — stderr 占位
- T39/stdout-step1-4.txt — Step 1-4 独立 stdout
- T39/stdout-step5.txt — Step 5 harness 独立 stdout
- T39/test-report.md — 详细测试报告
- T39/md-before.md / T39/md-after.md
- T39/result-before.json / T39/result-after.json
- T39/sha256-before.txt / T39/sha256-after.txt
- T39/lock-before.txt / T39/lock-after-step14.txt / T39/lock-after-modify.txt / T39/lock-after.txt
- T39/fixture-stdout.txt
- T39/t39-wrapper.ps1
- phase5-stdout.txt / phase5-stderr.txt
- phase5-report.md
- phase-progress.json

## 判定

**$t39Verdict**

$(if ($t39Verdict -eq 'PASS') { "T39 硬门槛通过。SKILL-v1.10 未破坏上一版本已经正确的 invariant。" } else { "T39 硬门槛未通过 → PRODUCTION_NOT_READY 倾向（但仍完成后续 Phase 以保留完整证据）。" })
"@
[System.IO.File]::WriteAllText($phase5Report, $phase5ReportContent, (New-Object System.Text.UTF8Encoding($false)))
Write-Log "Phase 5 report written"

# ============================================================
# Update phase-progress.json
# ============================================================
$progressPath = Join-Path $pvDir 'phase-progress.json'
$progress = [ordered]@{
    phase = 'Phase5'
    start_time = $startTime.ToString('yyyy-MM-ddTHH:mm:sszzz')
    end_time = $endTime.ToString('yyyy-MM-ddTHH:mm:sszzz')
    status = 'completed'
    completed_steps = @('T39')
    pending_steps = @()
    evidence_files = @(
        'T39/',
        'phase5-stdout.txt',
        'phase5-stderr.txt',
        'phase5-report.md',
        'phase5-orchestrator.ps1'
    )
    test_results = [ordered]@{
        T39 = $t39Verdict
    }
    key_findings = @(
        "T39: COMMIT_OK| present = $commitOkPresent"
        "T39: RUNTIME_ERROR| present = $runtimeErrorPresent"
        "T39: RUN_STATUS|failed| present = $runStatusFailedPresent"
        "T39: RUN_STATUS|success| absent = $runStatusSuccessAbsent"
        "T39: lock-after-modify.txt PID=999999 = $lockAfterModifyHasPid999999"
        "T39: lock-after.txt 锁仍存在（未释放） = $lockAfterExists"
        "T39: 核心 invariant (commitSucceeded=true + lockReleased=false → RUN_STATUS|failed|) = $invariantHolds"
        "T39: commitSucceeded = $commitSucceeded"
        "T39: lockReleased = $lockReleased"
        "T39: 执行方式 = t39-wrapper.ps1 (dot-source Step 1-4) + step5-t39-harness.ps1 (dot-source Step 5，内部注入 pid=999999)"
    )
    overall_verdict = $t39Verdict
    production_ready = ($t39Verdict -eq 'PASS')
    next_phase = 'Phase6'
}
$progress | ConvertTo-Json -Depth 8 | Set-Content $progressPath -Encoding UTF8
Write-Log "phase-progress.json updated"

Write-Log "Phase 5 execution finished at $($endTime.ToString('yyyy-MM-dd HH:mm:ss'))"
Write-Log "FINAL VERDICT: $t39Verdict"
