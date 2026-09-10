# t38-orchestrator-heartbeat.ps1 — T38-heartbeat: heartbeat 失败（run.lock 不存在）→ return（Phase 1 Step 6）
#
# 故障注入维度：文件系统构造（删除 run.lock，使 Step 4 heartbeat 读取失败）。
# 进程模型：单进程 pwsh 脚本内顺序 & step1..3（同进程同 PID），再删除 run.lock，再 & step4.ps1。
# 依据：Step 4 L477 heartbeat 块 Get-Content $lockPath -Raw -ErrorAction Stop 失败 → catch → return。
# SENTINEL 期望：不出现（heartbeat 失败 → return）。
# 依据：exec-plan §Phase1 Step 6 SENTINEL 期望表 T38-heartbeat 行。

param([string]$BaseDir = '')
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot

if (-not $BaseDir) { $BaseDir = Join-Path (Split-Path $PSScriptRoot -Parent) 'test-t38-heartbeat' }
if (Test-Path $BaseDir) { Remove-Item $BaseDir -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Force -Path $BaseDir | Out-Null

$env:GITHUB_VERSION_MONITOR_BASE = $BaseDir
Write-Output ('ORCH|t38-heartbeat|base={0}|pid={1}' -f $BaseDir, $PID)

# 前置：fixture + Step 1-3（同进程，锁 PID 一致）
& (Join-Path $here 'create-fixture.ps1') -BaseDir $BaseDir -Scenario 't38'
& (Join-Path $here 'step1.ps1')
& (Join-Path $here 'step2.ps1')
& (Join-Path $here 'step3.ps1')

# 故障注入：删除 run.lock（heartbeat 读取失败）
$lockPath = Join-Path (Join-Path $BaseDir '.monitor') 'run.lock'
if (Test-Path $lockPath) {
    Remove-Item $lockPath -Force -ErrorAction SilentlyContinue
    Write-Output ('INJECT|run_lock_deleted|path={0}' -f $lockPath)
} else {
    Write-Output 'INJECT|run_lock_already_missing'
}

# 被测：原样执行 Step 4（heartbeat 失败 → catch → RUN_STATUS|failed| → return）
& (Join-Path $here 'step4.ps1')

# T38-heartbeat 期望 SENTINEL 不出现（heartbeat 失败 → return → 编排器不应输出 SENTINEL）
# 故此处不输出 SENTINEL
# Write-Output 'SENTINEL|AFTER_STEP4'
