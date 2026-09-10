# step5-t39-harness.ps1 — T39: commit 成功 + 锁释放失败 → 无 return → 自然结束（Phase 1 Step 6）
#
# 故障注入维度：同进程注入（内联复制 Step 5 代码，在 L636/L637 之间注入锁 PID 重写）。
# 进程模型：单进程 pwsh 脚本内顺序 & step1..4（同进程同 PID），再 Invoke-Expression 内联注入版 Step 5。
# 注入点：step5-full.ps1 L116/L117 之间（= SKILL-v1.11.md L636/L637 之间）。
# 注入代码（与计划声明逐字一致）：
#   # T39 注入：模拟锁被外来 PID 持有
#   Set-Content $lockPath -Value "pid=999999;ts=$(Get-Date -Format o)" -Force
#
# 前置变量：harness 须预置 $conclusionText / $summaryText / $noteText（SKILL L539-547 占位值），
#           否则 Step 5 md 组装失败。
#
# 依据：注入后锁内 PID=999999 ≠ 当前进程 PID → ownership 校验失败 → $lockReleased=$false
#       → RUN_STATUS|failed|（L649）→ 自然结束（无 return）。
# SENTINEL 期望：出现（无 return，Step 5 自然结束后编排器输出 SENTINEL）。
# 依据：exec-plan §Phase1 Step 6 SENTINEL 期望表 T39 行。

param([string]$BaseDir = '')
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot

if (-not $BaseDir) { $BaseDir = Join-Path (Split-Path $PSScriptRoot -Parent) 'test-t39' }
if (Test-Path $BaseDir) { Remove-Item $BaseDir -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Force -Path $BaseDir | Out-Null

$env:GITHUB_VERSION_MONITOR_BASE = $BaseDir
Write-Output ('ORCH|t39|base={0}|pid={1}' -f $BaseDir, $PID)

# 前置：fixture + Step 1-4（同进程，锁 PID 一致）
& (Join-Path $here 'create-fixture.ps1') -BaseDir $BaseDir -Scenario 't38'
& (Join-Path $here 'step1.ps1')
& (Join-Path $here 'step2.ps1')
& (Join-Path $here 'step3.ps1')
& (Join-Path $here 'step4.ps1')

# 注入版 Step 5（splice-inline 工具：读取已验证零差异的提取文件，按行号拼接 + 精确注入）
. (Join-Path $here 'splice-inline.ps1')
$code = Get-InlinedStepCode -SourceFile (Join-Path $here 'step5-full.ps1') -AfterLine 116 -Injection @(
    '# T39 注入：模拟锁被外来 PID 持有',
    'Set-Content $lockPath -Value "pid=999999;ts=$(Get-Date -Format o)" -Force'
)
Write-Output ('INJECT|inline_step5|afterLine=116|injectionLines=2|codeLen={0}' -f $code.Length)

# 被测：执行内联注入版 Step 5（commit 成功 + 锁释放失败 → RUN_STATUS|failed| → 自然结束）
Invoke-Expression $code

# SENTINEL（T39 期望出现）
Write-Output 'SENTINEL|AFTER_STEP5'
