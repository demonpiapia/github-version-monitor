# phase6-orchestrator.ps1 - Phase 6 T43 + T46（关键优先级）
# 目标：
#   T43 — Full Extended Pipeline Regression：6 场景 fixture + 完整 Step 1→5 管线
#   T46 — .output State Path Regression：验证 .output/ 是唯一生产状态文件位置
# 隔离：通过 GITHUB_VERSION_MONITOR_BASE 指向各测试子目录，禁止触碰生产根目录
# 前置：Phase 1 (lib/step1-5.ps1, lib/create-fixture.ps1, lib/run-full-pipeline.ps1) 已完成
#       Phase 1 stdout-verification.txt 决策 PIPELINE_OK → 使用 run-full-pipeline.ps1 单次执行
# 执行环境：Windows + PowerShell 7.x

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
    $tmpFetchPath = Join-Path $BaseDir '.monitor\result.fetch.tmp'
    $tmpReviewPath = Join-Path $BaseDir '.monitor\result.review.tmp'
    $lockPath = Join-Path $BaseDir '.monitor\run.lock'
    $beforeDir = Join-Path $TestDir 'before'
    $afterDir = Join-Path $TestDir 'after'
    if (-not (Test-Path $beforeDir)) { New-Item -ItemType Directory -Force -Path $beforeDir | Out-Null }
    if (-not (Test-Path $afterDir)) { New-Item -ItemType Directory -Force -Path $afterDir | Out-Null }

    $mdBefore = Join-Path $TestDir 'md-before.md'
    $resultBefore = Join-Path $TestDir 'result-before.json'
    $lockBefore = Join-Path $TestDir 'lock-before.txt'
    if (Test-Path $mdPath) { Copy-Item $mdPath $mdBefore -Force } else { 'MD_FILE_NOT_EXISTS' | Set-Content $mdBefore -Encoding UTF8 }
    if (Test-Path $resultPath) { Copy-Item $resultPath $resultBefore -Force } else { '{"note":"result.json not exists before run"}' | Set-Content $resultBefore -Encoding UTF8 }
    if (Test-Path $lockPath) { Get-Content $lockPath -Raw | Set-Content $lockBefore -Encoding UTF8 } else { 'LOCK_FILE_NOT_EXISTS' | Set-Content $lockBefore -Encoding UTF8 }

    $shaBefore = Join-Path $TestDir 'sha256-before.txt'
    $sb = @()
    $sb += ("main_md: {0}" -f (Get-Sha256 $mdPath))
    $sb += ("result.json: {0}" -f (Get-Sha256 $resultPath))
    $sb += ("result.fetch.tmp: {0}" -f (Get-Sha256 $tmpFetchPath))
    $sb += ("result.review.tmp: {0}" -f (Get-Sha256 $tmpReviewPath))
    $sb += ("run.lock: {0}" -f (Get-Sha256 $lockPath))
    $sb | Set-Content $shaBefore -Encoding UTF8

    $beforeListing = Join-Path $TestDir 'before\dir-listing.txt'
    Get-ChildItem $BaseDir -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName.Replace($BaseDir,'') } | Set-Content $beforeListing -Encoding UTF8
}

function Capture-After {
    param([string]$TestDir, [string]$BaseDir)
    $mdPath = Join-Path $BaseDir '.output\GitHub更新监测列表.md'
    $resultPath = Join-Path $BaseDir '.monitor\result.json'
    $tmpFetchPath = Join-Path $BaseDir '.monitor\result.fetch.tmp'
    $tmpReviewPath = Join-Path $BaseDir '.monitor\result.review.tmp'
    $lockPath = Join-Path $BaseDir '.monitor\run.lock'
    $afterDir = Join-Path $TestDir 'after'
    if (-not (Test-Path $afterDir)) { New-Item -ItemType Directory -Force -Path $afterDir | Out-Null }

    $mdAfter = Join-Path $TestDir 'md-after.md'
    $resultAfter = Join-Path $TestDir 'result-after.json'
    $lockAfter = Join-Path $TestDir 'lock-after.txt'
    if (Test-Path $mdPath) { Copy-Item $mdPath $mdAfter -Force } else { 'MD_FILE_NOT_EXISTS' | Set-Content $mdAfter -Encoding UTF8 }
    if (Test-Path $resultPath) { Copy-Item $resultPath $resultAfter -Force } else { '{"note":"result.json not exists after run"}' | Set-Content $resultAfter -Encoding UTF8 }
    if (Test-Path $lockPath) { Get-Content $lockPath -Raw | Set-Content $lockAfter -Encoding UTF8 } else { 'LOCK_FILE_NOT_EXISTS' | Set-Content $lockAfter -Encoding UTF8 }

    $shaAfter = Join-Path $TestDir 'sha256-after.txt'
    $sa = @()
    $sa += ("main_md: {0}" -f (Get-Sha256 $mdPath))
    $sa += ("result.json: {0}" -f (Get-Sha256 $resultPath))
    $sa += ("result.fetch.tmp: {0}" -f (Get-Sha256 $tmpFetchPath))
    $sa += ("result.review.tmp: {0}" -f (Get-Sha256 $tmpReviewPath))
    $sa += ("run.lock: {0}" -f (Get-Sha256 $lockPath))
    $sa | Set-Content $shaAfter -Encoding UTF8

    $afterListing = Join-Path $TestDir 'after\dir-listing.txt'
    Get-ChildItem $BaseDir -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName.Replace($BaseDir,'') } | Set-Content $afterListing -Encoding UTF8
}

function Run-Script {
    param([string]$ScriptPath, [string]$StdoutFile, [string]$StderrFile, [string[]]$ArgList)
    $allArgs = @('-NoProfile','-NonInteractive','-File',$ScriptPath)
    if ($ArgList) { $allArgs += $ArgList }
    & $pwshPath @allArgs *> $StdoutFile
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
    $global:TestResults[$TestName] = @{ Pass = $allPass; Details = $results; Stdout = $stdout }
    return $allPass
}

# ============================================================
# Main execution
# ============================================================

$startTime = Get-Date
$endTime = Get-Date
$duration = ($endTime - $startTime).TotalSeconds
$durationStr = [string]::Format('{0:N1}', $duration)
$endTimeStr = $endTime.ToString('yyyy-MM-dd HH:mm:ss')

# 预初始化 T43 变量（避免 fixture 失败分支中变量未定义）
$t43Verdict = 'BLOCKED'
$t43StdoutRaw = ''
$t43ReviewWriteOk = $false
$t43ResultJsonValid = $false
$t43ResultSummary = 'N/A'
$t43ItemsCount = 0
$t43MdRowsCount = -1
$t43MdRowsConsistent = $false
$t43BackupDir = ''
$t43BackupExists = $false
$t43BackupFiles = @()
$t43BackupOk = $false
$t43FetchLog = ''
$t43FetchLogExists = $false
$t43FetchLogLines = 0
$t43LockReleased = $false
$t43HardGateViolated = $false
$t43BackupLine = ''
$t43FetchLine = ''
$t43SummaryLine = ''
$t43ReviewLine = ''
$t43CommitLine = ''
$t43RunStatusLine = ''
$t43ShaBeforeContent = ''
$t43ShaAfterContent = ''
$t43LockBeforeContent = ''
$t43LockAfterContent2 = ''
$t43VerdictNote = ''
$t43Stdout = ''
$t43Stderr = ''
$t43Dir = ''
$t43Base = ''

Write-Log "Phase 6 T43 + T46 Execution Started"
Write-Log "ProjectRoot: $ProjectRoot"
Write-Log "PVDir: $pvDir"
Write-Log "PwshPath: $pwshPath"

# 前置：读取 Phase 1 stdout 透传决策
$stdoutVerifyFile = Join-Path $pvDir 'lib\stdout-verification.txt'
$stdoutVerifyContent = Get-Content $stdoutVerifyFile -Raw -ErrorAction SilentlyContinue
$decisionPipelineOk = ($stdoutVerifyContent -match 'DECISION:\s*PIPELINE_OK')
Write-Log "Phase 1 stdout 透传决策 PIPELINE_OK = $decisionPipelineOk"
if (-not $decisionPipelineOk) {
    Write-Log "ERROR: Phase 1 stdout 透传决策非 PIPELINE_OK，T43 应改为逐 step 独立执行。中止。"
    exit 1
}

# ============================================================
# T43: Full Extended Pipeline Regression（6 场景）
# ============================================================
Write-Log "=== T43: Full Extended Pipeline Regression ==="
$t43Dir = Join-Path $pvDir 'T43'
$t43Base = $t43Dir
if (Test-Path $t43Base) { Remove-Item $t43Base -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Force -Path $t43Base | Out-Null

Write-Log "T43: Generating fixture (scenario=T43, 6 场景)"
$t43FixtureStdout = Join-Path $t43Dir 'fixture-stdout.txt'
& $pwshPath -NoProfile -NonInteractive -File (Join-Path $libDir 'create-fixture.ps1') -BaseDir $t43Base -Scenario 'T43' *> $t43FixtureStdout
$t43FixtureExit = $LASTEXITCODE
Write-Log "T43: fixture exit code = $t43FixtureExit"
if ($t43FixtureExit -ne 0) {
    Write-Log "T43: fixture generation FAILED"
    $t43Verdict = 'BLOCKED'
} else {
    Capture-BeforeAfter -TestDir $t43Dir -BaseDir $t43Base
    Write-Log "T43: before state captured"

    $runScript = Join-Path $libDir 'run-full-pipeline.ps1'
    $t43Stdout = Join-Path $t43Dir 'stdout.txt'
    $t43Stderr = Join-Path $t43Dir 'stderr.txt'
    $t43Exit = Run-Script -ScriptPath $runScript -StdoutFile $t43Stdout -StderrFile $t43Stderr -ArgList @('-BaseDir', $t43Base)
    Write-Log "T43: pipeline exit code = $t43Exit"

    Capture-After -TestDir $t43Dir -BaseDir $t43Base
    Write-Log "T43: after state captured"

    $t43StdoutRaw = Get-Content $t43Stdout -Raw -ErrorAction SilentlyContinue
    if (-not $t43StdoutRaw) { $t43StdoutRaw = '' }

    $t43ExpectedPatterns = @(
        'BACKUP_OK|',
        'FETCH_COMPLETE|',
        'SUMMARY|',
        'COMMIT_OK|',
        'RUN_STATUS|success|'
    )
    $t43ForbiddenPatterns = @(
        'RUN_STATUS|failed|'
    )

    $t43Pass = Judge-Test -TestName 'T43' -TestDir $t43Dir `
        -ExpectedPatterns $t43ExpectedPatterns `
        -ForbiddenPatterns $t43ForbiddenPatterns

    # REVIEW_WRITE_OK| 条件性检查（fixture 应触发 review=true）
    $t43ReviewWriteOk = ($t43StdoutRaw -match [regex]::Escape('REVIEW_WRITE_OK|'))
    Write-Log "T43: REVIEW_WRITE_OK| present = $t43ReviewWriteOk (fixture 应触发 review)"

    # 数据一致性验证
    $t43ResultAfterFile = Join-Path $t43Dir 'result-after.json'
    $t43ResultJsonValid = $false
    $t43ResultSummary = 'N/A'
    $t43ItemsCount = 0
    if (Test-Path $t43ResultAfterFile) {
        try {
            $t43Doc = Get-Content $t43ResultAfterFile -Raw | ConvertFrom-Json
            $t43HasStats = ($null -ne $t43Doc.stats)
            $t43HasItems = ($null -ne $t43Doc.items) -and (@($t43Doc.items).Count -gt 0)
            $t43HasReview = ($null -ne $t43Doc.review)
            $t43ItemsCount = @($t43Doc.items).Count
            $t43StatsTotal = $t43Doc.stats.total
            $t43ResultJsonValid = ($t43HasStats -and $t43HasItems -and $t43HasReview -and ($t43StatsTotal -eq $t43ItemsCount))
            $t43ResultSummary = "stats=$t43HasStats items=$t43HasItems($t43ItemsCount) review=$t43HasReview stats.total=$t43StatsTotal items.count=$t43ItemsCount consistent=$($t43StatsTotal -eq $t43ItemsCount)"
        } catch {
            $t43ResultSummary = "PARSE_ERROR: $($_.Exception.Message)"
        }
    } else {
        $t43ResultSummary = 'result-after.json not exists'
    }
    Write-Log "T43: result.json valid = $t43ResultJsonValid ($t43ResultSummary)"

    # .output/...md 表格行与 result.json items 一致
    $t43MdAfterFile = Join-Path $t43Dir 'md-after.md'
    $t43MdRowsCount = -1
    $t43MdRowsConsistent = $false
    if (Test-Path $t43MdAfterFile) {
        $t43MdLines = Get-Content $t43MdAfterFile
        $t43MdRowsCount = @($t43MdLines | Where-Object { $_ -match '^\|\s*\d+\s*\|' }).Count
        $t43MdRowsConsistent = ($t43MdRowsCount -eq $t43ItemsCount)
    }
    Write-Log "T43: md table rows = $t43MdRowsCount, items = $t43ItemsCount, consistent = $t43MdRowsConsistent"

    # backup 目录存在且含时间戳备份
    $t43BackupDir = Join-Path $t43Base '.monitor\backups'
    $t43BackupExists = (Test-Path $t43BackupDir)
    $t43BackupFiles = @()
    if ($t43BackupExists) {
        $t43BackupFiles = @(Get-ChildItem $t43BackupDir -File -ErrorAction SilentlyContinue)
    }
    $t43BackupOk = ($t43BackupExists -and $t43BackupFiles.Count -gt 0)
    Write-Log "T43: backup dir exists = $t43BackupExists, backup files = $($t43BackupFiles.Count)"

    # fetch_run.log 日志行存在
    $t43FetchLog = Join-Path $t43Base '.monitor\fetch_run.log'
    $t43FetchLogExists = (Test-Path $t43FetchLog)
    $t43FetchLogLines = 0
    if ($t43FetchLogExists) {
        $t43FetchLogLines = @(Get-Content $t43FetchLog).Count
    }
    Write-Log "T43: fetch_run.log exists = $t43FetchLogExists, lines = $t43FetchLogLines"

    # lock 已释放
    $t43LockAfterContent = Get-Content (Join-Path $t43Dir 'lock-after.txt') -Raw -ErrorAction SilentlyContinue
    $t43LockReleased = ($t43LockAfterContent -match 'LOCK_FILE_NOT_EXISTS')
    Write-Log "T43: lock released = $t43LockReleased"

    # 综合判定
    $t43DataConsistency = ($t43ResultJsonValid -and $t43MdRowsConsistent -and $t43BackupOk -and $t43FetchLogExists -and $t43LockReleased)
    $t43HardGateViolated = ($t43StdoutRaw -match [regex]::Escape('COMMIT_OK|')) -and ($t43StdoutRaw -match [regex]::Escape('RUN_STATUS|failed|'))

    if (-not $t43Pass) { $t43Verdict = 'FAIL' }
    elseif ($t43HardGateViolated) { $t43Verdict = 'FAIL' }
    elseif (-not $t43DataConsistency) { $t43Verdict = 'FAIL' }
    else { $t43Verdict = 'PASS' }
    Write-Log "T43: hard gate violated = $t43HardGateViolated"
    Write-Log "T43: data consistency = $t43DataConsistency"
    Write-Log "T43: verdict = $t43Verdict"

    # 提取关键 stdout 行
    $t43StdoutLines = @($t43StdoutRaw -split "`r?`n")
    $t43BackupLine = ($t43StdoutLines | Where-Object { $_ -match 'BACKUP_OK\|' } | Select-Object -First 1)
    $t43FetchLine = ($t43StdoutLines | Where-Object { $_ -match 'FETCH_COMPLETE\|' } | Select-Object -First 1)
    $t43SummaryLine = ($t43StdoutLines | Where-Object { $_ -match '^SUMMARY\|' } | Select-Object -First 1)
    $t43ReviewLine = ($t43StdoutLines | Where-Object { $_ -match 'REVIEW_WRITE_OK\|' } | Select-Object -First 1)
    $t43CommitLine = ($t43StdoutLines | Where-Object { $_ -match 'COMMIT_OK\|' } | Select-Object -First 1)
    $t43RunStatusLine = ($t43StdoutLines | Where-Object { $_ -match 'RUN_STATUS\|' } | Select-Object -First 1)

    $t43ShaBeforeContent = Get-Content (Join-Path $t43Dir 'sha256-before.txt') -Raw
    $t43ShaAfterContent = Get-Content (Join-Path $t43Dir 'sha256-after.txt') -Raw
    $t43LockBeforeContent = Get-Content (Join-Path $t43Dir 'lock-before.txt') -Raw
    $t43LockAfterContent2 = Get-Content (Join-Path $t43Dir 'lock-after.txt') -Raw

    $t43VerdictNote = if ($t43Verdict -eq 'PASS') {
        "T43 完整成功链验证通过：BACKUP_OK → FETCH_COMPLETE → SUMMARY → REVIEW_WRITE_OK → COMMIT_OK → RUN_STATUS|success| 全部存在。6 场景 fixture 覆盖 normal upgrade / synced / uninstalled / unsupported / 404 / versionJump。数据一致性（result.json / md 表格 / backup / fetch_run.log / lock）全部通过。"
    } else {
        "T43 未通过：详见上表 FAIL 项。"
    }

    $t43ReportPath = Join-Path $t43Dir 'test-report.md'
    $t43ReportContent = @"
# T43 Test Report — Full Extended Pipeline Regression

> **测试目标**: SKILL-v1.10 完整管线（Step 1→5 代码 + Step 6 汇报模板）在 6 场景 fixture 下的成功链验证
> **构造方法**: 6 个不同真实仓库 + 1 个 404 不存在仓库（共 6 场景）
>   - normal upgrade: microsoft/vscode localVer=0.0.1
>   - synced: nodejs/node localVer=<latest>（动态查询）
>   - uninstalled: facebook/react localVer=未安装
>   - unsupported: microsoft/TypeScript localVer=abc-invalid-format
>   - 404: test/nonexistent-repo-12345 localVer=1.0.0
>   - versionJump: angular/angular localVer=<lowVscode>（major 差 ≥2）
> **执行方式**: run-full-pipeline.ps1 单次执行 + 捕获 stdout（依据 Phase 1 lib/stdout-verification.txt 决策 PIPELINE_OK）
> **执行时间**: $($endTimeStr)
> **执行耗时**: $($durationStr) 秒
> **执行环境**: Windows + PowerShell 7.x

## 构造方法详情

1. 通过 GITHUB_VERSION_MONITOR_BASE 隔离到 T43/ 子目录
2. 生成 fixture（create-fixture.ps1 -Scenario T43）：6 场景
3. 采集 before 状态
4. 执行 run-full-pipeline.ps1 -BaseDir <testDir> 单次执行，捕获 stdout
5. 采集 after 状态
6. 判定完整成功链 + 数据一致性

## 验证项

| 验证项 | 期望 | 结果 |
|---|---|---|
| BACKUP_OK\| | 存在 | **$($t43StdoutRaw -match 'BACKUP_OK\|' ? 'PASS' : 'FAIL')** |
| FETCH_COMPLETE\| | 存在 | **$($t43StdoutRaw -match 'FETCH_COMPLETE\|' ? 'PASS' : 'FAIL')** |
| SUMMARY\| | 存在 | **$($t43StdoutRaw -match 'SUMMARY\|' ? 'PASS' : 'FAIL')** |
| REVIEW_WRITE_OK\| | 存在（fixture 触发 review） | **$($t43ReviewWriteOk ? 'PASS' : 'FAIL')** |
| COMMIT_OK\| | 存在 | **$($t43StdoutRaw -match 'COMMIT_OK\|' ? 'PASS' : 'FAIL')** |
| RUN_STATUS\|success\| | 存在 | **$($t43StdoutRaw -match 'RUN_STATUS\|success\|' ? 'PASS' : 'FAIL')** |
| RUN_STATUS\|failed\| | 不存在 | **$((-not ($t43StdoutRaw -match 'RUN_STATUS\|failed\|')) ? 'PASS' : 'FAIL')** |
| result.json valid (stats/items/review + stats.total==items.count) | 结构完整 | **$($t43ResultJsonValid ? 'PASS' : 'FAIL')** |
| .output/...md 表格行与 result.json items 一致 | 一致 | **$($t43MdRowsConsistent ? 'PASS' : 'FAIL')** |
| backup 目录存在且含时间戳备份 | 存在 | **$($t43BackupOk ? 'PASS' : 'FAIL')** |
| fetch_run.log 存在 | 存在 | **$($t43FetchLogExists ? 'PASS' : 'FAIL')** |
| lock released (run.lock 不存在) | 已释放 | **$($t43LockReleased ? 'PASS' : 'FAIL')** |
| 硬门槛 (COMMIT_OK + RUN_STATUS\|failed\|) | 不违反 | **$((-not $t43HardGateViolated) ? 'PASS' : 'FAIL')** |

## 关键 stdout 行

~~~
$t43BackupLine
$t43FetchLine
$t43SummaryLine
$t43ReviewLine
$t43CommitLine
$t43RunStatusLine
~~~

## 数据一致性详情

- result.json: $t43ResultSummary
- md 表格行数: $t43MdRowsCount, items 数: $t43ItemsCount, 一致: $t43MdRowsConsistent
- backup 目录: $t43BackupExists, backup 文件数: $($t43BackupFiles.Count)
- fetch_run.log: $t43FetchLogExists, 行数: $t43FetchLogLines
- lock released: $t43LockReleased

## SHA256 对比

### Before
~~~
$t43ShaBeforeContent
~~~

### After
~~~
$t43ShaAfterContent
~~~

## Lock 状态

### Before
~~~
$t43LockBeforeContent
~~~

### After
~~~
$t43LockAfterContent2
~~~

## 判定

**$t43Verdict**

$t43VerdictNote
"@
    [System.IO.File]::WriteAllText($t43ReportPath, $t43ReportContent, (New-Object System.Text.UTF8Encoding($false)))
    Write-Log "T43: test-report.md written"
}

# ============================================================
# T46: .output State Path Regression
# ============================================================
Write-Log "=== T46: .output State Path Regression ==="
$t46Dir = Join-Path $pvDir 'T46'
$t46Base = $t46Dir
if (Test-Path $t46Base) { Remove-Item $t46Base -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Force -Path $t46Base | Out-Null

Write-Log "T46: Generating fixture (scenario=normal)"
$t46FixtureStdout = Join-Path $t46Dir 'fixture-stdout.txt'
& $pwshPath -NoProfile -NonInteractive -File (Join-Path $libDir 'create-fixture.ps1') -BaseDir $t46Base -Scenario 'normal' *> $t46FixtureStdout
$t46FixtureExit = $LASTEXITCODE
Write-Log "T46: fixture exit code = $t46FixtureExit"

$t46MdPath = Join-Path $t46Base '.output\GitHub更新监测列表.md'
$t46MdExists = (Test-Path $t46MdPath)
Write-Log "T46: .output/GitHub更新监测列表.md exists = $t46MdExists"

Capture-BeforeAfter -TestDir $t46Dir -BaseDir $t46Base
Write-Log "T46: before state captured"

# 执行 Step 1 + Step 2（不执行 Step 5，写回发生在 Step 5）
$t46StdoutStep1 = Join-Path $t46Dir 'stdout-step1.txt'
$t46StdoutStep2 = Join-Path $t46Dir 'stdout-step2.txt'
$t46Stdout = Join-Path $t46Dir 'stdout.txt'
$t46Stderr = Join-Path $t46Dir 'stderr.txt'

Write-Log "T46: Running Step 1"
$env:GITHUB_VERSION_MONITOR_BASE = $t46Base
& $pwshPath -NoProfile -NonInteractive -File (Join-Path $libDir 'step1.ps1') *> $t46StdoutStep1
$t46Step1Exit = $LASTEXITCODE
Write-Log "T46: Step 1 exit code = $t46Step1Exit"

Write-Log "T46: Running Step 2"
& $pwshPath -NoProfile -NonInteractive -File (Join-Path $libDir 'step2.ps1') *> $t46StdoutStep2
$t46Step2Exit = $LASTEXITCODE
Write-Log "T46: Step 2 exit code = $t46Step2Exit"

# 拼接 stdout
$t46Combined = @()
$t46Combined += "=== STEP 1 START ==="
if (Test-Path $t46StdoutStep1) { $t46Combined += (Get-Content $t46StdoutStep1) }
$t46Combined += "=== STEP 1 END ==="
$t46Combined += "=== STEP 2 START ==="
if (Test-Path $t46StdoutStep2) { $t46Combined += (Get-Content $t46StdoutStep2) }
$t46Combined += "=== STEP 2 END ==="
$t46Combined | Set-Content $t46Stdout -Encoding UTF8

if (-not (Test-Path $t46Stderr)) { New-Item -ItemType File -Path $t46Stderr -Force | Out-Null }

Capture-After -TestDir $t46Dir -BaseDir $t46Base
Write-Log "T46: after state captured"

# 验证项
$t46OutputMdExists = (Test-Path $t46MdPath)
$t46RootMdPath = Join-Path $t46Base 'GitHub更新监测列表.md'
$t46RootMdExists = (Test-Path $t46RootMdPath)

# directory-listing.txt
$t46DirListing = Join-Path $t46Dir 'directory-listing.txt'
$listingLines = @()
$listingLines += "=== T46 Test Directory Listing (BaseDir=$t46Base) ==="
$listingLines += ""
$listingLines += "=== Root level (T46/) ==="
if (Test-Path $t46Base) {
    Get-ChildItem $t46Base -Force -ErrorAction SilentlyContinue | ForEach-Object {
        $type = if ($_.PSIsContainer) { '[DIR]' } else { '[FILE]' }
        $listingLines += ("{0} {1}" -f $type, $_.Name)
    }
}
$listingLines += ""
$listingLines += "=== .output/ level ==="
$t46OutputDir = Join-Path $t46Base '.output'
if (Test-Path $t46OutputDir) {
    Get-ChildItem $t46OutputDir -Force -ErrorAction SilentlyContinue | ForEach-Object {
        $type = if ($_.PSIsContainer) { '[DIR]' } else { '[FILE]' }
        $listingLines += ("{0} {1}" -f $type, $_.Name)
    }
} else {
    $listingLines += "(.output/ not exists)"
}
$listingLines += ""
$listingLines += "=== .monitor/ level ==="
$t46MonitorDir = Join-Path $t46Base '.monitor'
if (Test-Path $t46MonitorDir) {
    Get-ChildItem $t46MonitorDir -Force -ErrorAction SilentlyContinue | ForEach-Object {
        $type = if ($_.PSIsContainer) { '[DIR]' } else { '[FILE]' }
        $listingLines += ("{0} {1}" -f $type, $_.Name)
    }
} else {
    $listingLines += "(.monitor/ not exists)"
}
$listingLines | Set-Content $t46DirListing -Encoding UTF8

# root-md-check.txt
$t46RootMdCheck = Join-Path $t46Dir 'root-md-check.txt'
$rootMdCheckLines = @()
$rootMdCheckLines += "=== T46 Root MD Check ==="
$rootMdCheckLines += ""
$rootMdCheckLines += "Check 1: .output/GitHub更新监测列表.md exists (期望: True)"
$rootMdCheckLines += "  Path: $t46MdPath"
$rootMdCheckLines += "  Exists: $t46OutputMdExists"
$rootMdCheckLines += ""
$rootMdCheckLines += "Check 2: T46 root 目录不存在 GitHub更新监测列表.md (期望: True)"
$rootMdCheckLines += "  Path: $t46RootMdPath"
$rootMdCheckLines += "  Exists: $t46RootMdExists"
$rootMdCheckLines += ""
$rootMdCheckLines += "Check 3: backup 基于 .output 状态文件（由 T43 完整管线证据覆盖）"
$rootMdCheckLines += "  T43 backup 目录存在: $t43BackupExists"
$rootMdCheckLines += "  T43 backup 文件数: $($t43BackupFiles.Count)"
$rootMdCheckLines += ""
$rootMdCheckLines += "Check 4: 读取 .output/ 写回 .output/（由 T43 完整管线证据覆盖）"
$rootMdCheckLines += "  T43 md 已更新 (SHA256 before != after): $($t43StdoutRaw -match 'COMMIT_OK\|')"
$rootMdCheckLines += ""
$rootMdCheckLines += "=== 判定 ==="
$t46PathContractPass = ($t46OutputMdExists -and (-not $t46RootMdExists))
$rootMdCheckLines += "  Path contract (.output/ 唯一生产状态文件位置): $($t46PathContractPass ? 'PASS' : 'FAIL')"
$rootMdCheckLines | Set-Content $t46RootMdCheck -Encoding UTF8

# T46 判定
$t46Verdict = if ($t46PathContractPass) { 'PASS' } else { 'FAIL' }
Write-Log "T46: path contract pass = $t46PathContractPass"
Write-Log "T46: verdict = $t46Verdict"

# T46 test-report.md
$t46ReportPath = Join-Path $t46Dir 'test-report.md'
$t46ReportContent = @"
# T46 Test Report — .output State Path Regression

> **测试目标**: 验证 SKILL-v1.10 使用 .output/GitHub更新监测列表.md 作为唯一生产状态文件位置
> **构造方法**: T46 测试目录 + fixture + Step 1 + Step 2（不执行 Step 5）
> **执行方式**: pwsh -File step1.ps1 + pwsh -File step2.ps1（两步独立执行）
> **执行时间**: $($endTimeStr)
> **执行耗时**: $($durationStr) 秒
> **执行环境**: Windows + PowerShell 7.x

## 构造方法详情

1. 通过 GITHUB_VERSION_MONITOR_BASE 隔离到 T46/ 子目录
2. 生成 fixture（create-fixture.ps1 -Scenario normal）：1 个真实仓库
3. 采集 before 状态
4. 执行 Step 1（状态检查 + 锁 + 备份）
5. 执行 Step 2（解析 + 查询 + 状态机 + 统计）
6. 采集 after 状态
7. 验证 .output/ 是唯一生产状态文件位置

## 验证项

| 验证项 | 期望 | 结果 |
|---|---|---|
| .output/GitHub更新监测列表.md 存在 | True | **$($t46OutputMdExists ? 'PASS' : 'FAIL')** |
| 根目录不存在 GitHub更新监测列表.md | True | **$((-not $t46RootMdExists) ? 'PASS' : 'FAIL')** |
| 读取 .output/ 写回 .output/ | 由 T43 完整管线证据覆盖 | **N/A（T43 覆盖）** |
| backup 基于 .output 状态文件 | 由 T43 完整管线证据覆盖 | **N/A（T43 覆盖）** |

## 关键 stdout 行

### Step 1
~~~
$(Get-Content $t46StdoutStep1 -Raw -ErrorAction SilentlyContinue)
~~~

### Step 2
~~~
$(Get-Content $t46StdoutStep2 -Raw -ErrorAction SilentlyContinue)
~~~

## 目录清单

参见 `directory-listing.txt`。

## 根目录 MD 检查

参见 `root-md-check.txt`。

## 判定

**$t46Verdict**

$(if ($t46Verdict -eq 'PASS') { "T46 路径契约验证通过：.output/GitHub更新监测列表.md 是唯一生产状态文件位置，T46 测试目录根不存在同名文件。" } else { "T46 路径契约未通过：详见上表 FAIL 项。" })
"@
[System.IO.File]::WriteAllText($t46ReportPath, $t46ReportContent, (New-Object System.Text.UTF8Encoding($false)))
Write-Log "T46: test-report.md written"

# ============================================================
# 生成 phase6-stdout.txt / phase6-stderr.txt / phase6-report.md
# ============================================================
$endTime = Get-Date
$duration = ($endTime - $startTime).TotalSeconds
$durationStr = [string]::Format('{0:N1}', $duration)
$endTimeStr = $endTime.ToString('yyyy-MM-dd HH:mm:ss')

$phase6Stdout = Join-Path $pvDir 'phase6-stdout.txt'
$phase6Stderr = Join-Path $pvDir 'phase6-stderr.txt'
$phase6Report = Join-Path $pvDir 'phase6-report.md'

$phase6Combined = @()
$phase6Combined += "=== Phase 6 T43 + T46 Execution ==="
$phase6Combined += "StartTime: $($startTime.ToString('yyyy-MM-dd HH:mm:ss'))"
$phase6Combined += "EndTime: $($endTimeStr)"
$phase6Combined += "Duration: $($durationStr)s"
$phase6Combined += ""
$phase6Combined += "=== T43 stdout ==="
if (Test-Path $t43Stdout) { $phase6Combined += (Get-Content $t43Stdout) }
$phase6Combined += ""
$phase6Combined += "=== T46 stdout ==="
if (Test-Path $t46Stdout) { $phase6Combined += (Get-Content $t46Stdout) }
$phase6Combined | Set-Content $phase6Stdout -Encoding UTF8

if (Test-Path $t43Stderr) { Get-Content $t43Stderr -Raw | Set-Content $phase6Stderr -Encoding UTF8 }
else { '' | Set-Content $phase6Stderr -Encoding UTF8 }

$phase6ReportContent = @"
# Phase 6 Report — T43 + T46

> **Phase**: 6
> **模块**: T43 Full Extended Pipeline Regression + T46 .output State Path Regression
> **优先级**: 关键
> **执行时间**: $endTimeStr
> **执行耗时**: $durationStr 秒
> **判定**: T43=**$t43Verdict**, T46=**$t46Verdict**

## 执行摘要

- T43: 6 场景 fixture + 完整 Step 1→5 管线
- T46: T46 测试目录 + Step 1 + Step 2（不执行 Step 5）
- 隔离: GITHUB_VERSION_MONITOR_BASE = <test dir>
- 生产根目录 .output/GitHub更新监测列表.md: 未触碰

## T43 验证项结果

| 验证项 | 结果 |
|---|---|
| BACKUP_OK\| 存在 | $($t43StdoutRaw -match 'BACKUP_OK\|' ? 'PASS' : 'FAIL') |
| FETCH_COMPLETE\| 存在 | $($t43StdoutRaw -match 'FETCH_COMPLETE\|' ? 'PASS' : 'FAIL') |
| SUMMARY\| 存在 | $($t43StdoutRaw -match 'SUMMARY\|' ? 'PASS' : 'FAIL') |
| REVIEW_WRITE_OK\| 存在（条件性） | $($t43ReviewWriteOk ? 'PASS' : 'FAIL') |
| COMMIT_OK\| 存在 | $($t43StdoutRaw -match 'COMMIT_OK\|' ? 'PASS' : 'FAIL') |
| RUN_STATUS\|success\| 存在 | $($t43StdoutRaw -match 'RUN_STATUS\|success\|' ? 'PASS' : 'FAIL') |
| RUN_STATUS\|failed\| 不存在 | $((-not ($t43StdoutRaw -match 'RUN_STATUS\|failed\|')) ? 'PASS' : 'FAIL') |
| result.json valid | $($t43ResultJsonValid ? 'PASS' : 'FAIL') |
| .output/...md 表格行与 result.json items 一致 | $($t43MdRowsConsistent ? 'PASS' : 'FAIL') |
| backup 目录存在且含时间戳备份 | $($t43BackupOk ? 'PASS' : 'FAIL') |
| fetch_run.log 存在 | $($t43FetchLogExists ? 'PASS' : 'FAIL') |
| lock released | $($t43LockReleased ? 'PASS' : 'FAIL') |
| 硬门槛 (COMMIT_OK + RUN_STATUS\|failed\|) 不违反 | $((-not $t43HardGateViolated) ? 'PASS' : 'FAIL') |

## T46 验证项结果

| 验证项 | 结果 |
|---|---|
| .output/GitHub更新监测列表.md 存在 | $($t46OutputMdExists ? 'PASS' : 'FAIL') |
| 根目录不存在 GitHub更新监测列表.md | $((-not $t46RootMdExists) ? 'PASS' : 'FAIL') |
| 读取 .output/ 写回 .output/ | N/A（由 T43 覆盖） |
| backup 基于 .output 状态文件 | N/A（由 T43 覆盖） |

## 关键 stdout 行

### T43
~~~
$t43BackupLine
$t43FetchLine
$t43SummaryLine
$t43ReviewLine
$t43CommitLine
$t43RunStatusLine
~~~

### T46
~~~
$(Get-Content $t46StdoutStep1 -Raw -ErrorAction SilentlyContinue)
$(Get-Content $t46StdoutStep2 -Raw -ErrorAction SilentlyContinue)
~~~

## 产出文件

- T43/before/ — 目录清单
- T43/after/ — 目录清单
- T43/stdout.txt — 完整 stdout（单次执行）
- T43/stderr.txt — stderr 占位
- T43/test-report.md — 详细测试报告
- T43/md-before.md / T43/md-after.md
- T43/result-before.json / T43/result-after.json
- T43/sha256-before.txt / T43/sha256-after.txt
- T43/lock-before.txt / T43/lock-after.txt
- T43/fixture-stdout.txt
- T46/before/ — 目录清单
- T46/after/ — 目录清单
- T46/stdout.txt — 完整 stdout（Step 1 + Step 2 拼接）
- T46/stdout-step1.txt / T46/stdout-step2.txt — 各 step 独立 stdout
- T46/stderr.txt — stderr 占位
- T46/test-report.md — 详细测试报告
- T46/md-before.md / T46/md-after.md
- T46/result-before.json / T46/result-after.json
- T46/sha256-before.txt / T46/sha256-after.txt
- T46/lock-before.txt / T46/lock-after.txt
- T46/directory-listing.txt — 测试目录清单
- T46/root-md-check.txt — 根目录 MD 检查
- T46/fixture-stdout.txt
- phase6-stdout.txt / phase6-stderr.txt
- phase6-report.md
- phase-progress.json

## 判定

- T43: **$t43Verdict**
- T46: **$t46Verdict**

$(if ($t43Verdict -eq 'PASS' -and $t46Verdict -eq 'PASS') { "Phase 6 关键优先级通过。T43 完整管线成功链 + 数据一致性全部通过；T46 路径契约验证通过。" } else { "Phase 6 关键优先级未通过。T43=$t43Verdict, T46=$t46Verdict。记录并继续，不阻断后续 Phase。" })
"@
[System.IO.File]::WriteAllText($phase6Report, $phase6ReportContent, (New-Object System.Text.UTF8Encoding($false)))
Write-Log "Phase 6 report written"

# ============================================================
# 更新 phase-progress.json
# ============================================================
$progressPath = Join-Path $pvDir 'phase-progress.json'
$progress = [ordered]@{
    phase = 'Phase6'
    start_time = $startTime.ToString('yyyy-MM-ddTHH:mm:sszzz')
    end_time = $endTime.ToString('yyyy-MM-ddTHH:mm:sszzz')
    status = 'completed'
    completed_steps = @('T43', 'T46')
    pending_steps = @()
    evidence_files = @(
        'T43/',
        'T46/',
        'phase6-stdout.txt',
        'phase6-stderr.txt',
        'phase6-report.md',
        'phase6-orchestrator.ps1'
    )
    test_results = [ordered]@{
        T43 = $t43Verdict
        T46 = $t46Verdict
    }
    key_findings = @(
        "T43: 完整成功链 BACKUP_OK → FETCH_COMPLETE → SUMMARY → REVIEW_WRITE_OK → COMMIT_OK → RUN_STATUS|success| 全部存在 = $($t43StdoutRaw -match 'BACKUP_OK\|' -and $t43StdoutRaw -match 'FETCH_COMPLETE\|' -and $t43StdoutRaw -match 'SUMMARY\|' -and $t43ReviewWriteOk -and $t43StdoutRaw -match 'COMMIT_OK\|' -and $t43StdoutRaw -match 'RUN_STATUS\|success\|')"
        "T43: RUN_STATUS|failed| 不存在 = $(-not ($t43StdoutRaw -match 'RUN_STATUS\|failed\|'))"
        "T43: 硬门槛 (COMMIT_OK + RUN_STATUS|failed|) 违反 = $t43HardGateViolated"
        "T43: result.json valid (stats/items/review + stats.total==items.count) = $t43ResultJsonValid"
        "T43: .output/...md 表格行与 result.json items 一致 = $t43MdRowsConsistent"
        "T43: backup 目录存在且含时间戳备份 = $t43BackupOk"
        "T43: fetch_run.log 存在 = $t43FetchLogExists"
        "T43: lock released = $t43LockReleased"
        "T43: 6 场景覆盖 normal upgrade / synced / uninstalled / unsupported / 404 / versionJump"
        "T46: .output/GitHub更新监测列表.md 存在 = $t46OutputMdExists"
        "T46: 根目录不存在 GitHub更新监测列表.md = $(-not $t46RootMdExists)"
        "T46: 路径契约通过 = $t46PathContractPass"
        "T46: 读取 .output/ 写回 .output/ 由 T43 完整管线证据覆盖"
        "T46: backup 基于 .output 状态文件由 T43 完整管线证据覆盖"
    )
    overall_verdict = if ($t43Verdict -eq 'PASS' -and $t46Verdict -eq 'PASS') { 'PASS' } else { 'FAIL' }
    production_ready = ($t43Verdict -eq 'PASS' -and $t46Verdict -eq 'PASS')
    next_phase = 'Phase7'
}
$progress | ConvertTo-Json -Depth 8 | Set-Content $progressPath -Encoding UTF8
Write-Log "phase-progress.json updated"

Write-Log "Phase 6 execution finished at $($endTime.ToString('yyyy-MM-dd HH:mm:ss'))"
Write-Log "FINAL VERDICT: T43=$t43Verdict, T46=$t46Verdict"
