# run-full-pipeline.ps1 — T37/T43 单进程完整管线（Phase 1 Step 6）
#
# 用途：单进程 pwsh 脚本内顺序 & step1..5（同进程同 PID，锁 ownership 天然一致）。
# 用于 T37（完整流程验证）与 T43（多场景验证）。
#
# stdout 透传验证：Phase 1 Step 8 独立运行本管线一次，验证 stdout 透传行为。
# 如透传正常 → T37/T43 单次执行捕获 stdout；如透传异常 → 逐 step 执行 + 拼接 stdout。
#
# 用法：
#   pwsh -NoProfile -NonInteractive -File run-full-pipeline.ps1 -BaseDir <dir> [-Scenario t43]

param([string]$BaseDir = '', [string]$Scenario = 't43')
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot

if (-not $BaseDir) { $BaseDir = Join-Path (Split-Path $PSScriptRoot -Parent) 'test-full-pipeline' }
if (Test-Path $BaseDir) { Remove-Item $BaseDir -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Force -Path $BaseDir | Out-Null

$env:GITHUB_VERSION_MONITOR_BASE = $BaseDir
Write-Output ('PIPELINE|full|base={0}|scenario={1}|pid={2}' -f $BaseDir, $Scenario, $PID)

# 前置：fixture
& (Join-Path $here 'create-fixture.ps1') -BaseDir $BaseDir -Scenario $Scenario

# Step 1-5 顺序执行（同进程同 PID）
& (Join-Path $here 'step1.ps1')
& (Join-Path $here 'step2.ps1')
& (Join-Path $here 'step3.ps1')
& (Join-Path $here 'step4.ps1')
& (Join-Path $here 'step5-full.ps1')

Write-Output 'PIPELINE_DONE'
