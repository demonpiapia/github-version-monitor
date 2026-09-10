# t22-orchestrator.ps1 — T22: 主 md 临时文件写入失败（ACL deny CreateFiles）→ return（Phase 1 Step 6）
#
# 故障注入维度：ACL 拒绝（对 .output 目录设置 CreateFiles 拒绝权限）。
# 进程模型：单进程 pwsh 脚本内顺序 & step1..4（同进程同 PID），再设置 ACL deny，
#           try { & step5-full.ps1 } finally { ACL 还原 }。
# 依据：Step 5 L607 Set-Content $tmp 失败 → catch → RUN_STATUS|failed| → return。
# SENTINEL 期望：不出现（md tmp 写入失败 → return）。
# 依据：exec-plan §Phase1 Step 6 SENTINEL 期望表 T22 行。

param([string]$BaseDir = '')
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot

if (-not $BaseDir) { $BaseDir = Join-Path (Split-Path $PSScriptRoot -Parent) 'test-t22' }
if (Test-Path $BaseDir) { Remove-Item $BaseDir -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Force -Path $BaseDir | Out-Null

$env:GITHUB_VERSION_MONITOR_BASE = $BaseDir
Write-Output ('ORCH|t22|base={0}|pid={1}' -f $BaseDir, $PID)

# 前置：fixture + Step 1-4（同进程，锁 PID 一致）
& (Join-Path $here 'create-fixture.ps1') -BaseDir $BaseDir -Scenario 't38'
& (Join-Path $here 'step1.ps1')
& (Join-Path $here 'step2.ps1')
& (Join-Path $here 'step3.ps1')
& (Join-Path $here 'step4.ps1')

# 故障注入：ACL deny .output CreateFiles
$outputDir = Join-Path $BaseDir '.output'
if (-not (Test-Path $outputDir)) { Write-Output 'ORCH_FAIL|.output not found'; exit 1 }
$identity = New-Object System.Security.Principal.NTAccount($env:USERNAME)
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule($identity, 'CreateFiles', 'Deny')
$acl = Get-Acl $outputDir
$acl.AddAccessRule($rule)
Set-Acl -Path $outputDir -AclObject $acl
Write-Output ('INJECT|acl_deny_createfiles|dir={0}|identity={1}' -f $outputDir, $env:USERNAME)

try {
    # 被测：原样执行 Step 5（md tmp 写入失败 → catch → RUN_STATUS|failed| → return）
    & (Join-Path $here 'step5-full.ps1')
} finally {
    # ACL 还原
    $acl2 = Get-Acl $outputDir
    $acl2.RemoveAccessRule($rule)
    Set-Acl -Path $outputDir -AclObject $acl2
    Write-Output 'ACL_RESTORED'
}

# T22 期望 SENTINEL 不出现（md tmp 写入失败 → return → 编排器不应输出 SENTINEL）
# 故此处不输出 SENTINEL
# Write-Output 'SENTINEL|AFTER_STEP5'
