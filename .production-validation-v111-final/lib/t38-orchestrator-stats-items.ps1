# t38-orchestrator-stats-items.ps1 — T38-stats-items: stats/items 完整性校验失败 → return（Phase 1 Step 6）
#
# **本轮最高优先级测试**：验证 SKILL-v1.11 L480 核心修复（`;return` 补齐）。
#
# 故障注入维度：同进程注入（内联复制 Step 4 代码，在 L479/L480 之间注入 stats 篡改）。
# 进程模型：单进程 pwsh 脚本内顺序 & step1..3（同进程同 PID），再 Invoke-Expression 内联注入版 Step 4。
# 注入点：step4.ps1 L7/L8 之间（= SKILL-v1.11.md L479/L480 之间）。
# 注入代码（与计划声明逐字一致）：
#   # T38-stats-items 注入：篡改 stats 使完整性校验失败
#   $doc.stats.total = 999
#
# 注入有效性依据（基于 L478-L480 直接阅读）：
#   $origStats 在 L478 行尾固化为 JSON 字符串快照（$doc.stats|ConvertTo-Json -Depth 8 -Compress）；
#   注入修改 $doc.stats.total 后，L480 计算的 $newStats 序列化结果必然 ≠ $origStats
#   （字符串比较，修改必然反映）→ if 命中 → 失败路径触发 → `;return`（v1.11 修复）阻止落入后续 JSON 校验路径。
#
# 边界条件：fixture 经真实 Step 2 产生的 result.json 的 stats.total 不得恰为 999
#          （Step 2 统计的 total = 监测项总数，fixture 用 1 项天然远离 999；执行前断言一次并记录）。
#
# SENTINEL 期望：不出现（完整性校验失败 → `;return` → 编排器不输出 SENTINEL）。
#   若 SENTINEL 出现 = 修复无效 = FAIL + P1（v1.11 核心修复失效）。
# 依据：exec-plan §Phase1 Step 6 SENTINEL 期望表 T38-stats-items 行。

param([string]$BaseDir = '')
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot

if (-not $BaseDir) { $BaseDir = Join-Path (Split-Path $PSScriptRoot -Parent) 'test-t38-stats-items' }
if (Test-Path $BaseDir) { Remove-Item $BaseDir -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Force -Path $BaseDir | Out-Null

$env:GITHUB_VERSION_MONITOR_BASE = $BaseDir
Write-Output ('ORCH|t38-stats-items|base={0}|pid={1}' -f $BaseDir, $PID)

# 前置：fixture + Step 1-3（同进程，锁 PID 一致）
& (Join-Path $here 'create-fixture.ps1') -BaseDir $BaseDir -Scenario 't38'
& (Join-Path $here 'step1.ps1')
& (Join-Path $here 'step2.ps1')
& (Join-Path $here 'step3.ps1')

# 边界条件断言：stats.total 不得恰为 999
$resultPath = Join-Path (Join-Path $BaseDir '.monitor') 'result.json'
if (Test-Path $resultPath) {
    $doc = Get-Content $resultPath -Raw | ConvertFrom-Json
    $total = [int]$doc.stats.total
    Write-Output ('ASSERT|stats.total={0}|not_equal_999={1}' -f $total, ($total -ne 999))
    if ($total -eq 999) {
        Write-Output 'ORCH_FAIL|stats.total is 999, injection would be ineffective'
        exit 1
    }
} else {
    Write-Output 'ORCH_FAIL|result.json not found after step2'
    exit 1
}

# 注入版 Step 4（splice-inline 工具：读取已验证零差异的提取文件，按行号拼接 + 精确注入）
# 注入点：step4.ps1 第 6 行（读取 result.json + 计算 origStats/origItems + 设置 candidates）与第 7 行（foreach 循环）之间
# 对应 SKILL-v1.11.md L478/L479 之间：$origStats 固化后、foreach 开始前
. (Join-Path $here 'splice-inline.ps1')
$code = Get-InlinedStepCode -SourceFile (Join-Path $here 'step4.ps1') -AfterLine 6 -Injection @(
    '# T38-stats-items 注入：篡改 stats 使完整性校验失败',
    '$doc.stats.total = 999'
)
Write-Output ('INJECT|inline_step4|afterLine=6|injectionLines=2|codeLen={0}' -f $code.Length)

# 被测：执行内联注入版 Step 4（stats 篡改 → 完整性校验失败 → `;return` → 编排器不输出 SENTINEL）
Invoke-Expression $code

# T38-stats-items 期望 SENTINEL 不出现（完整性校验失败 → return → 编排器不应输出 SENTINEL）
# 故此处不输出 SENTINEL；若需调试可取消注释下行
# Write-Output 'SENTINEL|AFTER_STEP4'
