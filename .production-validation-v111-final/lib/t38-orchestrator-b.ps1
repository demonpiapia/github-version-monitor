# t38-orchestrator-b.ps1 — T38-B: tmp 写入成功但内容为非法 JSON → JSON 校验失败 → return（Phase 1 Step 6）
#
# 故障注入维度：同进程注入（内联复制 Step 4 代码，在 L489/L490 之间注入 tmp 篡改）。
# 进程模型：单进程 pwsh 脚本内顺序 & step1..3（同进程同 PID），再 Invoke-Expression 内联注入版 Step 4。
# 注入点：step4.ps1 L17/L18 之间（= SKILL-v1.11.md L489/L490 之间）。
# 注入代码（与计划声明逐字一致）：
#   # T38-B 注入：篡改 tmp 文件内容为非法 JSON
#   Set-Content $tmpPath -Value '{invalid json' -Force
# SENTINEL 期望：不出现（JSON 校验失败 → return）。
# 依据：exec-plan §Phase1 Step 6 SENTINEL 期望表 T38-B 行。

param([string]$BaseDir = '')
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot

if (-not $BaseDir) { $BaseDir = Join-Path (Split-Path $PSScriptRoot -Parent) 'test-t38-b' }
if (Test-Path $BaseDir) { Remove-Item $BaseDir -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Force -Path $BaseDir | Out-Null

$env:GITHUB_VERSION_MONITOR_BASE = $BaseDir
Write-Output ('ORCH|t38-b|base={0}|pid={1}' -f $BaseDir, $PID)

# 前置：fixture + Step 1-3（同进程，锁 PID 一致）
& (Join-Path $here 'create-fixture.ps1') -BaseDir $BaseDir -Scenario 't38'
& (Join-Path $here 'step1.ps1')
& (Join-Path $here 'step2.ps1')
& (Join-Path $here 'step3.ps1')

# 注入版 Step 4（splice-inline 工具：读取已验证零差异的提取文件，按行号拼接 + 精确注入）
. (Join-Path $here 'splice-inline.ps1')
$code = Get-InlinedStepCode -SourceFile (Join-Path $here 'step4.ps1') -AfterLine 17 -Injection @(
    '# T38-B 注入：篡改 tmp 文件内容为非法 JSON',
    'Set-Content $tmpPath -Value ''{invalid json'' -Force'
)
Write-Output ('INJECT|inline_step4|afterLine=17|injectionLines=2|codeLen={0}' -f $code.Length)

# 被测：执行内联注入版 Step 4（tmp 写入成功但内容为非法 JSON → JSON 校验失败 → return）
Invoke-Expression $code

# T38-B 期望 SENTINEL 不出现（JSON 校验失败 → return → 编排器不应输出 SENTINEL）
# 故此处不输出 SENTINEL
# Write-Output 'SENTINEL|AFTER_STEP4'
