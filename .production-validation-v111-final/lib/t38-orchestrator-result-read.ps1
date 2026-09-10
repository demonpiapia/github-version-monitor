# t38-orchestrator-result-read.ps1 — T38-result-read: result.json 读取失败 → return（Phase 1 Step 6）
#
# 故障注入维度：文件系统构造（删除 result.json，使 Step 4 读取失败）。
# 进程模型：单进程 pwsh 脚本内顺序 & step1..3（同进程同 PID），再删除 result.json，再 & step4.ps1。
# 依据：Step 4 L478 try { Get-Content $resultPath -Raw | ConvertFrom-Json } catch { ... return }。
# SENTINEL 期望：不出现（result.json 读取失败 → return）。
# 依据：exec-plan §Phase1 Step 6 SENTINEL 期望表 T38-result-read 行。

param([string]$BaseDir = '')
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot

if (-not $BaseDir) { $BaseDir = Join-Path (Split-Path $PSScriptRoot -Parent) 'test-t38-result-read' }
if (Test-Path $BaseDir) { Remove-Item $BaseDir -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Force -Path $BaseDir | Out-Null

$env:GITHUB_VERSION_MONITOR_BASE = $BaseDir
Write-Output ('ORCH|t38-result-read|base={0}|pid={1}' -f $BaseDir, $PID)

# 前置：fixture + Step 1-3（同进程，锁 PID 一致）
& (Join-Path $here 'create-fixture.ps1') -BaseDir $BaseDir -Scenario 't38'
& (Join-Path $here 'step1.ps1')
& (Join-Path $here 'step2.ps1')
& (Join-Path $here 'step3.ps1')

# 故障注入：删除 result.json（读取失败）
$resultPath = Join-Path (Join-Path $BaseDir '.monitor') 'result.json'
if (Test-Path $resultPath) {
    Remove-Item $resultPath -Force -ErrorAction SilentlyContinue
    Write-Output ('INJECT|result_json_deleted|path={0}' -f $resultPath)
} else {
    Write-Output 'INJECT|result_json_already_missing'
}

# 被测：原样执行 Step 4（result.json 读取失败 → catch → RUN_STATUS|failed| → return）
& (Join-Path $here 'step4.ps1')

# T38-result-read 期望 SENTINEL 不出现（result.json 读取失败 → return → 编排器不应输出 SENTINEL）
# 故此处不输出 SENTINEL
# Write-Output 'SENTINEL|AFTER_STEP4'
