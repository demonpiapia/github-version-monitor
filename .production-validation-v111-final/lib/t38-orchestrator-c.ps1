# t38-orchestrator-c.ps1 — T38-C: 原子替换失败（result.json 被外部进程锁）→ return（Phase 1 Step 6）
#
# 故障注入维度：文件锁持有（外部后台进程以 FileShare::None 独占打开 result.json）。
# 进程模型：单进程 pwsh 脚本内顺序 & step1..3（同进程同 PID），再 Invoke-Expression 内联注入版 Step 4。
# 注入点：step4.ps1 L18 之后（JSON 校验读取 tmpPath，不读 result.json），
#          在 L27 Move-Item 之前启动 lock-holder 锁住 result.json。
# SENTINEL 期望：不出现（原子替换失败 → return）。

param([string]$BaseDir = '')
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot

if (-not $BaseDir) { $BaseDir = Join-Path (Split-Path $PSScriptRoot -Parent) 'test-t38-c' }
if (Test-Path $BaseDir) { Remove-Item $BaseDir -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Force -Path $BaseDir | Out-Null

$env:GITHUB_VERSION_MONITOR_BASE = $BaseDir
Write-Output ('ORCH|t38-c|base={0}|pid={1}' -f $BaseDir, $PID)

# 前置：fixture + Step 1-3（同进程，锁 PID 一致）
& (Join-Path $here 'create-fixture.ps1') -BaseDir $BaseDir -Scenario 't38'
& (Join-Path $here 'step1.ps1')
& (Join-Path $here 'step2.ps1')
& (Join-Path $here 'step3.ps1')

# 准备 lock-holder 参数
$resultPath = Join-Path (Join-Path $BaseDir '.monitor') 'result.json'
if (-not (Test-Path $resultPath)) { Write-Output 'ORCH_FAIL|result.json not found after step2'; exit 1 }
$signal = Join-Path $BaseDir 'signal-lock.txt'
$holder = Join-Path $here 'lock-holder.ps1'

# 注入版 Step 4：在 L18（JSON 校验后）与 L19（if 判断）之间注入 lock-holder 启动代码
# lock-holder 锁住 result.json → L27 Move-Item 失败 → catch → RUN_STATUS|failed| → return
. (Join-Path $here 'splice-inline.ps1')
$injLine1 = '$procC = Start-Process pwsh -ArgumentList @("-NoProfile","-NonInteractive","-File","' + $holder + '","' + $resultPath + '","' + $signal + '") -WindowStyle Hidden -PassThru; Start-Sleep -Milliseconds 500'
$injLine2 = 'Write-Output ("INJECT|result_json_locked|holder_pid={0}" -f $procC.Id)'
$code = Get-InlinedStepCode -SourceFile (Join-Path $here 'step4.ps1') -AfterLine 18 -Injection @($injLine1, $injLine2)
Write-Output ('INJECT|inline_step4|afterLine=18|injectionLines=2|codeLen={0}' -f $code.Length)

# 被测：执行内联注入版 Step 4（Move-Item 失败 → catch → RUN_STATUS|failed| → return）
Invoke-Expression $code

# 释放锁
Set-Content $signal -Value 'done' -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 300
if ($procC -and -not $procC.HasExited) { Stop-Process -Id $procC.Id -Force -ErrorAction SilentlyContinue }

# T38-C 期望 SENTINEL 不出现（原子替换失败 → return → 编排器不应输出 SENTINEL）
# 故此处不输出 SENTINEL
# Write-Output 'SENTINEL|AFTER_STEP4'
