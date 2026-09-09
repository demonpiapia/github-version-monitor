# run-full-pipeline.ps1 - 串行执行 step1 → step5-full
# 用途：完整管线测试（T37 / T43）。stdout 透传验证：本脚本将各 step 的 stdout 原样输出，
#       供 Phase 1 独立验证 stdout 透传行为。
#
# 用法：
#   pwsh -NoProfile -NonInteractive -File run-full-pipeline.ps1 -BaseDir <path>
#
# 隔离：通过 GITHUB_VERSION_MONITOR_BASE 指向测试目录，禁止触碰生产根目录。
#
# 重要设计决策：
#   SKILL 使用 $PID 进行 ownership 校验（L208/L248/L440/L476/L637）。
#   若各 step 作为独立进程执行（pwsh -File），$PID 不同 → ownership 校验失败。
#   因此本脚本使用 dot-source（.）在同进程内执行各 step，确保 $PID 一致。
#
# PS5.1 语法兼容要求：本脚本在 Phase 1（PS7）创建。为便于 Phase 8 复用（若需要），
# 禁用 PS7-only 运算符。

param(
    [Parameter(Mandatory=$true)][string]$BaseDir
)

$ErrorActionPreference = 'Stop'
$env:GITHUB_VERSION_MONITOR_BASE = $BaseDir

$libDir = $PSScriptRoot

Write-Output "=== STEP 1 START ==="
. (Join-Path $libDir 'step1.ps1')
Write-Output "=== STEP 1 END ==="

Write-Output "=== STEP 2 START ==="
. (Join-Path $libDir 'step2.ps1')
Write-Output "=== STEP 2 END ==="

Write-Output "=== STEP 3 START ==="
. (Join-Path $libDir 'step3.ps1')
Write-Output "=== STEP 3 END ==="

Write-Output "=== STEP 4 START ==="
. (Join-Path $libDir 'step4.ps1')
Write-Output "=== STEP 4 END ==="

Write-Output "=== STEP 5 START ==="
. (Join-Path $libDir 'step5-full.ps1')
Write-Output "=== STEP 5 END ==="

Write-Output "=== PIPELINE COMPLETE ==="
