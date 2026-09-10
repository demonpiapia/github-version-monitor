# t23-orchestrator.ps1 — T23: 主 md 原子替换失败（主 md 被外部进程锁）→ 无 return → 自然结束（Phase 1 Step 6）
#
# 故障注入维度：文件锁持有（外部后台进程以 FileShare::None 独占打开主 md）。
# 进程模型：单进程 pwsh 脚本内顺序 & step1..4（同进程同 PID），再 Invoke-Expression 内联注入版 Step 5。
# 注入点：step5-full.ps1 L104 之后（结构校验通过、if 块内 try 开始前），
#          在 L106 Move-Item 之前启动 lock-holder 锁住主 md。
# SENTINEL 期望：出现（无 return，Step 5 自然结束后编排器输出 SENTINEL）。

param([string]$BaseDir = '')
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot

if (-not $BaseDir) { $BaseDir = Join-Path (Split-Path $PSScriptRoot -Parent) 'test-t23' }
if (Test-Path $BaseDir) { Remove-Item $BaseDir -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Force -Path $BaseDir | Out-Null

$env:GITHUB_VERSION_MONITOR_BASE = $BaseDir
Write-Output ('ORCH|t23|base={0}|pid={1}' -f $BaseDir, $PID)

# 前置：fixture + Step 1-4（同进程，锁 PID 一致）
& (Join-Path $here 'create-fixture.ps1') -BaseDir $BaseDir -Scenario 't38'
& (Join-Path $here 'step1.ps1')
& (Join-Path $here 'step2.ps1')
& (Join-Path $here 'step3.ps1')
& (Join-Path $here 'step4.ps1')

# 准备 lock-holder 参数
$mdPath = Join-Path (Join-Path $BaseDir '.output') 'GitHub更新监测列表.md'
if (-not (Test-Path $mdPath)) { Write-Output 'ORCH_FAIL|main md not found'; exit 1 }
$signal = Join-Path $BaseDir 'signal-lock.txt'
$holder = Join-Path $here 'lock-holder.ps1'

# 注入版 Step 5：在 L104（结构校验通过 if 条件）与 L105（try { Move-Item }）之间注入 lock-holder 启动代码
# lock-holder 锁住主 md → L106 Move-Item 失败 → catch → 清理 tmp → 锁释放 → RUN_STATUS|failed| → 自然结束
. (Join-Path $here 'splice-inline.ps1')
$injLine1 = '$procT23 = Start-Process pwsh -ArgumentList @("-NoProfile","-NonInteractive","-File","' + $holder + '","' + $mdPath + '","' + $signal + '") -WindowStyle Hidden -PassThru; Start-Sleep -Milliseconds 500'
$injLine2 = 'Write-Output ("INJECT|main_md_locked|holder_pid={0}" -f $procT23.Id)'
$code = Get-InlinedStepCode -SourceFile (Join-Path $here 'step5-full.ps1') -AfterLine 104 -Injection @($injLine1, $injLine2)
Write-Output ('INJECT|inline_step5|afterLine=104|injectionLines=2|codeLen={0}' -f $code.Length)

# 被测：执行内联注入版 Step 5（Move-Item 失败 → catch → 清理 → 锁释放 → RUN_STATUS|failed| → 自然结束）
Invoke-Expression $code

# 释放锁
Set-Content $signal -Value 'done' -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 300
if ($procT23 -and -not $procT23.HasExited) { Stop-Process -Id $procT23.Id -Force -ErrorAction SilentlyContinue }

# SENTINEL（T23 期望出现 — 无 return，Step 5 自然结束后编排器输出 SENTINEL）
Write-Output 'SENTINEL|AFTER_STEP5'
