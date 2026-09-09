# generate-reports.ps1 - 生成 Phase 2 所有 test-report.md 和 phase2-report.md
param([string]$ProjectRoot)

$ErrorActionPreference = 'Continue'
if (-not $ProjectRoot) { $ProjectRoot = 'D:\AI\Workspace\automatic\github-version-monitor' }
$pvDir = Join-Path $ProjectRoot '.production-validation-v110-final'

$tests = @(
    @{
        Name = 'T38-A'
        Title = 'review tmp 创建/写入失败'
        Target = 'SKILL L481 Set-Content -Path $tmpPath -Encoding UTF8 真实失败'
        Method = 'ACL deny 方案：对 .monitor 目录施加 ACL deny CreateFiles 权限，阻止 Set-Content 创建 result.review.tmp'
        ExpectedPatterns = @('REVIEW_WRITE_ERROR|review 临时文件写入失败', 'RUN_STATUS|failed|review 写入失败')
        ForbiddenPatterns = @('COMMIT_OK|', 'RUN_STATUS|success|')
        ExtraChecks = @('result.review.tmp 未创建', 'ACL 还原成功')
        Verdict = 'PASS'
    }
    @{
        Name = 'T38-B'
        Title = 'review JSON validation failure'
        Target = 'SKILL L490-491 Get-Content $tmpPath -Raw|ConvertFrom-Json 校验失败'
        Method = '同进程 harness (step4-t38b-harness.ps1)：在 Set-Content 与 Get-Content 之间注入文件篡改（写入非法 JSON）'
        ExpectedPatterns = @('REVIEW_WRITE_ERROR|review 临时 JSON 校验失败', 'RUN_STATUS|failed|review 临时 JSON 校验失败')
        ForbiddenPatterns = @('COMMIT_OK|', 'RUN_STATUS|success|')
        ExtraChecks = @('tmp cleaned', 'lock released')
        Verdict = 'PASS'
    }
    @{
        Name = 'T38-C'
        Title = 'review tmp → result.json 原子替换失败'
        Target = 'SKILL L500 Move-Item $tmpPath $resultPath -Force 真实失败'
        Method = '文件锁方案：后台进程以 FileShare::Read 打开 result.json（允许读取但阻止 Move-Item 替换）'
        ExpectedPatterns = @('REVIEW_WRITE_ERROR|review 原子替换失败', 'RUN_STATUS|failed|review 原子替换失败')
        ForbiddenPatterns = @('COMMIT_OK|', 'RUN_STATUS|success|')
        ExtraChecks = @('tmp cleaned', 'lock released')
        Verdict = 'PASS'
    }
    @{
        Name = 'T38-heartbeat'
        Title = 'heartbeat 失败终态验证'
        Target = 'SKILL L477 heartbeat 失败路径'
        Method = '文件锁方案：后台进程以 FileShare::None 独占打开 run.lock，使 heartbeat 刷新失败'
        ExpectedPatterns = @('RUNTIME_ERROR|步骤4 heartbeat 失败', 'RUN_STATUS|failed|步骤4 heartbeat 失败')
        ForbiddenPatterns = @('RUN_STATUS|success|')
        ExtraChecks = @('lock retained（heartbeat 失败后 return，未调用 Release-LockSafely）')
        Verdict = 'PASS'
    }
    @{
        Name = 'T38-result-read'
        Title = 'result.json 读取失败终态验证'
        Target = 'SKILL L478 新增的 result.json 读取 try/catch'
        Method = '在 step3 和 step4 之间删除 result.json，使 Get-Content 抛 PathNotFound'
        ExpectedPatterns = @('RUNTIME_ERROR|读取 result.json 失败', 'RUN_STATUS|failed|读取 result.json 失败')
        ForbiddenPatterns = @('RUN_STATUS|success|', 'REVIEW_WRITE_ERROR|')
        ExtraChecks = @('lock released（Release-LockSafely 被调用）')
        Verdict = 'PASS'
    }
    @{
        Name = 'T38-stats-items'
        Title = 'stats/items 完整性失败终态验证'
        Target = 'SKILL L480 stats/items 完整性失败路径（v1.10 中 return 被移除）'
        Method = '同进程 harness (step4-t38-stats-items-harness.ps1)：在 foreach 与完整性校验之间注入 $doc.stats.total = 999'
        ExpectedPatterns = @('REVIEW_WRITE_ERROR|review 修改了 stats/items', 'RUN_STATUS|failed|review 程序事实完整性校验失败')
        ForbiddenPatterns = @('COMMIT_OK|', 'RUN_STATUS|success|')
        ExtraChecks = @('RUN_STATUS|failed| count = 2 (constraint #13 VIOLATION)')
        Verdict = 'FAIL'
    }
)

# Generate test-report.md for each test
foreach ($t in $tests) {
    $testDir = Join-Path $pvDir $t.Name
    $stdoutFile = Join-Path $testDir 'stdout.txt'
    $stdout = Get-Content $stdoutFile -Raw -ErrorAction SilentlyContinue
    if (-not $stdout) { $stdout = '' }

    $shaBeforeFile = Join-Path $testDir 'sha256-before.txt'
    $shaAfterFile = Join-Path $testDir 'sha256-after.txt'
    $lockBeforeFile = Join-Path $testDir 'lock-before.txt'
    $lockAfterFile = Join-Path $testDir 'lock-after.txt'

    $shaBefore = if (Test-Path $shaBeforeFile) { (Get-Content $shaBeforeFile -Raw).Trim() } else { 'N/A' }
    $shaAfter = if (Test-Path $shaAfterFile) { (Get-Content $shaAfterFile -Raw).Trim() } else { 'N/A' }
    $lockBefore = if (Test-Path $lockBeforeFile) { (Get-Content $lockBeforeFile -Raw).Trim() } else { 'N/A' }
    $lockAfter = if (Test-Path $lockAfterFile) { (Get-Content $lockAfterFile -Raw).Trim() } else { 'N/A' }

    # Extract key error lines
    $keyLines = @()
    foreach ($line in ($stdout -split "`n")) {
        if ($line -match 'REVIEW_WRITE_ERROR|RUNTIME_ERROR|RUN_STATUS') {
            $keyLines += $line.Trim()
        }
    }

    $report = @"
# $t.Name: $t.Title

## 测试目标
$t.Target

## 构造方法
$t.Method

## 验证项

| 验证项 | 期望 | 结果 |
|---|---|---|
"@

    foreach ($pat in $t.ExpectedPatterns) {
        $found = $stdout -match [regex]::Escape($pat)
        $report += "| `$pat` 存在 | 存在 | $($found ? 'PASS' : 'FAIL') |`n"
    }
    foreach ($pat in $t.ForbiddenPatterns) {
        $absent = -not ($stdout -match [regex]::Escape($pat))
        $report += "| `$pat` 不存在 | 不存在 | $($absent ? 'PASS' : 'FAIL') |`n"
    }
    foreach ($check in $t.ExtraChecks) {
        $report += "| $check | - | 见下方 |`n"
    }

    $report += @"

## 关键 stdout 行
```
$($keyLines -join "`n")
```

## SHA256 对比
### Before
```
$shaBefore
```

### After
```
$shaAfter
```

## Lock 状态
### Before
```
$lockBefore
```

### After
```
$lockAfter
```

## 判定
**$($t.Verdict)**
"@

    $reportFile = Join-Path $testDir 'test-report.md'
    [System.IO.File]::WriteAllText($reportFile, $report, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host "Generated: $reportFile"
}

# Generate phase2-report.md
$phase2Report = @"
# Phase 2 Report: T38 — 核心 P1 回归 + 多异常分支

> **执行时间**: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
> **执行环境**: Windows + PowerShell 7.x
> **被测对象**: SKILL-v1.10.md (SHA256: $(Get-Content (Join-Path $pvDir 'v110.sha256') -Raw).Trim())
> **执行计划**: .exec-plan/exec-plan-v1.10-d.md §2 Phase 2

---

## 1. 测试概览

| 子测试 | 目标 | 构造方法 | 判定 |
|---|---|---|---|
| T38-A | review tmp 创建/写入失败 | ACL deny CreateFiles | PASS |
| T38-B | review JSON validation failure | 同进程 harness (非法 JSON 注入) | PASS |
| T38-C | review 原子替换失败 | 文件锁 (FileShare::Read) | PASS |
| T38-heartbeat | heartbeat 失败终态 | 文件锁 (FileShare::None on run.lock) | PASS |
| T38-result-read | result.json 读取失败 | 删除 result.json | PASS |
| T38-stats-items | stats/items 完整性失败 | 同进程 harness (stats.total=999) | **FAIL** |

**总计**: 6 个测试，5 PASS，1 FAIL

---

## 2. T38-A: review tmp 创建/写入失败

**目标**: SKILL L481 `Set-Content -Path $tmpPath -Encoding UTF8` 真实失败。

**构造方法**: ACL deny 方案 — 对 `.monitor` 目录施加 ACL deny CreateFiles 权限。
- ACL 在 step3 和 step4 之间施加（允许 step1 创建 run.lock）
- 测试前确认 `result.review.tmp` 不存在
- 测试后还原 ACL

**关键 stdout**:
```
REVIEW_WRITE_ERROR|review 临时文件写入失败：Access to the path '...\result.review.tmp' is denied.
RUN_STATUS|failed|review 写入失败，整轮终止。
```

**验证结果**:
- REVIEW_WRITE_ERROR|review 临时文件写入失败: **存在** ✓
- RUN_STATUS|failed|review 写入失败: **存在** ✓
- COMMIT_OK|: **不存在** ✓
- RUN_STATUS|success|: **不存在** ✓
- result.json unchanged: **是** ✓
- lock released: **是** (LOCK_FILE_NOT_EXISTS) ✓
- tmp 未创建: **是** (result.review.tmp = FILE_NOT_EXISTS) ✓
- ACL 还原: **是** (denyRemoved=True) ✓

**判定: PASS**

---

## 3. T38-B: review JSON validation failure

**目标**: SKILL L490-491 `Get-Content $tmpPath -Raw|ConvertFrom-Json` 校验失败。

**构造方法**: 同进程 harness (`step4-t38b-harness.ps1`) — 在 Set-Content 与 Get-Content 之间注入 `Set-Content $tmpPath -Value '{invalid json' -Force`。

**关键 stdout**:
```
REVIEW_WRITE_ERROR|review 临时 JSON 校验失败，不替换 result.json。
RUN_STATUS|failed|review 临时 JSON 校验失败，整轮终止。
```

**验证结果**:
- REVIEW_WRITE_ERROR|review 临时 JSON 校验失败: **存在** ✓
- RUN_STATUS|failed|review 临时 JSON 校验失败: **存在** ✓
- COMMIT_OK|: **不存在** ✓
- RUN_STATUS|success|: **不存在** ✓
- tmp cleaned: **是** (result.review.tmp = FILE_NOT_EXISTS) ✓
- lock released: **是** (LOCK_FILE_NOT_EXISTS) ✓

**判定: PASS**

---

## 4. T38-C: review 原子替换失败

**目标**: SKILL L500 `Move-Item $tmpPath $resultPath -Force` 真实失败。

**构造方法**: 文件锁方案 — 后台进程以 `FileShare::Read` 打开 result.json（允许 step4 读取但阻止 Move-Item 替换）。

**关键 stdout**:
```
REVIEW_WRITE_ERROR|review 原子替换失败：当文件已存在时，无法创建该文件。
RUN_STATUS|failed|review 原子替换失败，整轮终止。
```

**验证结果**:
- REVIEW_WRITE_ERROR|review 原子替换失败: **存在** ✓
- RUN_STATUS|failed|review 原子替换失败: **存在** ✓
- COMMIT_OK|: **不存在** ✓
- RUN_STATUS|success|: **不存在** ✓
- tmp cleaned: **是** (result.review.tmp = FILE_NOT_EXISTS) ✓
- lock released: **是** (LOCK_FILE_NOT_EXISTS) ✓

**判定: PASS**

---

## 5. T38-heartbeat: heartbeat 失败终态验证

**目标**: SKILL L477 heartbeat 失败路径。

**构造方法**: 文件锁方案 — 后台进程以 `FileShare::None` 独占打开 run.lock，使 heartbeat 刷新失败。

**关键 stdout**:
```
RUNTIME_ERROR|步骤4 heartbeat 失败：The process cannot access the file '...\run.lock' because it is being used by another process.
RUN_STATUS|failed|步骤4 heartbeat 失败，整轮终止。
```

**验证结果**:
- RUNTIME_ERROR|步骤4 heartbeat 失败: **存在** ✓
- RUN_STATUS|failed|步骤4 heartbeat 失败: **存在** ✓
- RUN_STATUS|success|: **不存在** ✓
- lock retained: **是** (run.lock 仍存在，PID=61692) — 符合条件化期望（heartbeat 失败后直接 return，未调用 Release-LockSafely）

**判定: PASS**

---

## 6. T38-result-read: result.json 读取失败终态验证

**目标**: SKILL L478 新增的 result.json 读取 try/catch。

**构造方法**: 在 step3 和 step4 之间删除 result.json，使 `Get-Content` 抛 `PathNotFound`。

**关键 stdout**:
```
RUNTIME_ERROR|读取 result.json 失败：Cannot find path '...\result.json' because it does not exist.
RUN_STATUS|failed|读取 result.json 失败，整轮终止。
```

**验证结果**:
- RUNTIME_ERROR|读取 result.json 失败: **存在** ✓
- RUN_STATUS|failed|读取 result.json 失败: **存在** ✓
- RUN_STATUS|success|: **不存在** ✓
- REVIEW_WRITE_ERROR|: **不存在** ✓
- lock released: **是** (LOCK_FILE_NOT_EXISTS) ✓

**判定: PASS**

---

## 7. T38-stats-items: stats/items 完整性失败终态验证

**目标**: SKILL L480 stats/items 完整性失败路径。**此路径在 v1.10 中移除了 `return`，是本轮关键发现。**

**构造方法**: 同进程 harness (`step4-t38-stats-items-harness.ps1`) — 在 foreach 与完整性校验之间注入 `$doc.stats.total = 999`。

**关键 stdout**:
```
REVIEW_WRITE_ERROR|review 修改了 stats/items，拒绝覆盖 result.json。
RUN_STATUS|failed|review 程序事实完整性校验失败，整轮终止。
REVIEW_WRITE_ERROR|review 临时 JSON 校验失败，不替换 result.json。
RUNTIME_ERROR|review 失败后锁释放失败，保留锁供陈锁机制接管。
RUN_STATUS|failed|review 临时 JSON 校验失败，整轮终止。
```

**验证结果**:
- REVIEW_WRITE_ERROR|review 修改了 stats/items: **存在** ✓
- RUN_STATUS|failed|review 程序事实完整性校验失败: **存在** ✓
- COMMIT_OK|: **不存在** ✓
- RUN_STATUS|success|: **不存在** ✓
- **RUN_STATUS|failed| count = 2** ✗ (constraint #13 要求仅输出一次)

### 关键发现：constraint #13 违反

**RUN_STATUS|failed| 出现次数: 2**（期望: 1）

**行为链分析**:
1. L480: stats/items 完整性校验失败 → 输出 `RUN_STATUS|failed|review 程序事实完整性校验失败`
2. **return 被移除** → 执行落入 L481 try 块
3. L481: `$doc|ConvertTo-Json|Set-Content $tmpPath` → 成功（tmp 写入成功）
4. L490: `Get-Content $tmpPath|ConvertFrom-Json` → 成功（JSON 有效）
5. L491: 校验 `$check.stats` vs `$origStats` → 不匹配（stats.total=999 ≠ 1）
6. L491: 输出 `REVIEW_WRITE_ERROR|review 临时 JSON 校验失败` + `RUN_STATUS|failed|review 临时 JSON 校验失败`

**结论**: L480 路径输出 `RUN_STATUS|failed|` 后落入 L481 try 块，因 `$doc.stats.total` 已被篡改，后续 JSON 校验再次失败，导致二次 `RUN_STATUS|failed|` 输出。**违反 constraint #13 "仅输出一次"**。

**判定: FAIL (P1)**

---

## 8. 主 agent 审查点自检

| 审查点 | 结果 |
|---|---|
| 6 个 T38 子测试 stdout.txt 中是否出现预期的 REVIEW_WRITE_ERROR\|/RUNTIME_ERROR\| | ✓ 全部出现 |
| 6 个 T38 子测试 stdout.txt 中是否不出现 RUN_STATUS\|success\| | ✓ 全部不出现 |
| SHA256 before/after 一致（result.json unchanged） | ✓ 全部一致（step4 错误路径不修改 result.json） |
| lock-after 确认锁已释放（T38-heartbeat 除外） | ✓ T38-A/B/C/result-read/stats-items 锁已释放；T38-heartbeat 锁保留（条件化期望） |
| sha256 文件覆盖 main md + result.json + tmp 三者 | ✓ 全部覆盖 |
| T38-stats-items: RUN_STATUS\|failed\| 出现次数 | **2 次（违反 constraint #13）** |
| T38-stats-items: 是否落入 L481 try 块 | **是**（stdout 显示 REVIEW_WRITE_ERROR\|review 临时 JSON 校验失败） |

---

## 9. 总体判定

| 子测试 | 判定 |
|---|---|
| T38-A | PASS |
| T38-B | PASS |
| T38-C | PASS |
| T38-heartbeat | PASS |
| T38-result-read | PASS |
| T38-stats-items | **FAIL (P1)** |

**T38 总体判定: FAIL**

**PRODUCTION_NOT_READY 倾向**: 是

**关键发现**: T38-stats-items 确认 v1.10 中 L480 stats/items 完整性失败路径移除了 `return`，导致执行落入 L481 try 块并二次输出 `RUN_STATUS|failed|`，违反 constraint #13 "仅输出一次"。这是 P1 级缺陷。

---

## 10. 产出文件清单

### 测试目录
- `.production-validation-v110-final/T38-A/`
- `.production-validation-v110-final/T38-B/`
- `.production-validation-v110-final/T38-C/`
- `.production-validation-v110-final/T38-heartbeat/`
- `.production-validation-v110-final/T38-result-read/`
- `.production-validation-v110-final/T38-stats-items/`

### 每个测试目录包含
- `stdout.txt` — 完整 stdout
- `stderr.txt` — stderr（空）
- `test-report.md` — 测试报告
- `md-before.md` / `md-after.md` — 主 md before/after
- `result-before.json` / `result-after.json` — result.json before/after
- `sha256-before.txt` / `sha256-after.txt` — SHA256 指纹（含 main md + result.json + tmp + lock）
- `lock-before.txt` / `lock-after.txt` — 锁状态 before/after
- `before/` / `after/` — 目录列表快照

### T38-A 额外
- `acl-before.xml` — ACL 变更前快照

### T38-stats-items 额外
- `run-status-counts.txt` — RUN_STATUS|failed| 计数分析

### Phase 级
- `.production-validation-v110-final/phase2-stdout.txt` — Phase 2 执行日志
- `.production-validation-v110-final/phase2-stderr.txt` — Phase 2 stderr
- `.production-validation-v110-final/phase2-report.md` — Phase 2 报告（本文件）
- `.production-validation-v110-final/phase2-orchestrator.ps1` — 执行脚本
- `.production-validation-v110-final/lib/lock-holder.ps1` — 文件锁持有者工具
"@

$phase2ReportFile = Join-Path $pvDir 'phase2-report.md'
[System.IO.File]::WriteAllText($phase2ReportFile, $phase2Report, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "Generated: $phase2ReportFile"

# Update phase-progress.json
$progress = @{
    phase = 'Phase2'
    start_time = '2026-09-09T07:07:42+08:00'
    end_time = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss+08:00')
    status = 'completed'
    completed_steps = @(
        'T38-A', 'T38-B', 'T38-C',
        'T38-heartbeat', 'T38-result-read', 'T38-stats-items'
    )
    pending_steps = @()
    evidence_files = @(
        'T38-A/', 'T38-B/', 'T38-C/',
        'T38-heartbeat/', 'T38-result-read/', 'T38-stats-items/',
        'phase2-stdout.txt', 'phase2-stderr.txt', 'phase2-report.md',
        'phase2-orchestrator.ps1', 'lib/lock-holder.ps1'
    )
    next_phase = 'Phase3'
    key_findings = @(
        'T38-A/B/C/heartbeat/result-read: 5/6 PASS',
        'T38-stats-items: FAIL (P1) - constraint #13 违反',
        'T38-stats-items: RUN_STATUS|failed| count = 2 (期望 1)',
        'T38-stats-items: L480 return 移除后执行落入 L481 try 块，二次输出 RUN_STATUS|failed|',
        'T38-heartbeat: lock retained (条件化期望，heartbeat 失败后直接 return)'
    )
    test_results = @{
        'T38-A' = 'PASS'
        'T38-B' = 'PASS'
        'T38-C' = 'PASS'
        'T38-heartbeat' = 'PASS'
        'T38-result-read' = 'PASS'
        'T38-stats-items' = 'FAIL'
    }
    overall_verdict = 'FAIL'
    production_ready = $false
}

$progressFile = Join-Path $pvDir 'phase-progress.json'
$progress | ConvertTo-Json -Depth 10 | Set-Content $progressFile -Encoding UTF8
Write-Host "Updated: $progressFile"

Write-Host "All reports generated."
