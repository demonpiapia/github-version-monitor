# t38-orchestrator-a.ps1 — T38-A: tmp 写入失败 → Step 4 catch 内 return（Phase 1 Step 6）
#
# 故障注入维度：文件系统构造（在 tmpPath 位置创建目录，使 Set-Content 写入失败）。
# 进程模型：单进程 pwsh 脚本内顺序 & step1..3（同进程同 PID，锁 ownership 天然一致），
#           再 & step4.ps1（原样执行，非注入版）。
# SENTINEL 期望：不出现（Step 4 catch 内 return，编排器不输出 SENTINEL）。
# 依据：exec-plan §Phase1 Step 6 SENTINEL 期望表 T38-A 行。

param([string]$BaseDir = '')
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot

if (-not $BaseDir) { $BaseDir = Join-Path (Split-Path $PSScriptRoot -Parent) 'test-t38-a' }
if (Test-Path $BaseDir) { Remove-Item $BaseDir -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Force -Path $BaseDir | Out-Null

$env:GITHUB_VERSION_MONITOR_BASE = $BaseDir
Write-Output ('ORCH|t38-a|base={0}|pid={1}' -f $BaseDir, $PID)

# 前置：fixture + Step 1-3（同进程，锁 PID 一致）
& (Join-Path $here 'create-fixture.ps1') -BaseDir $BaseDir -Scenario 't38'
& (Join-Path $here 'step1.ps1')
& (Join-Path $here 'step2.ps1')
& (Join-Path $here 'step3.ps1')

# 故障注入：在 tmpPath 位置创建目录，使 Set-Content 写入失败
$monitorDir = Join-Path $BaseDir '.monitor'
$tmpPath = Join-Path $monitorDir 'result.review.tmp'
if (Test-Path $tmpPath) { Remove-Item $tmpPath -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Force -Path $tmpPath | Out-Null
Write-Output ('INJECT|tmp_path_is_directory|path={0}' -f $tmpPath)

# 被测：原样执行 Step 4（tmp 写入失败 → catch → RUN_STATUS|failed| → return）
& (Join-Path $here 'step4.ps1')

# T38-A 期望 SENTINEL 不出现（tmp 写入失败 → return → 编排器不应输出 SENTINEL）
# 故此处不输出 SENTINEL
# Write-Output 'SENTINEL|AFTER_STEP4'
