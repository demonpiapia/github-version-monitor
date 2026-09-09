$ErrorActionPreference = 'Continue'
$env:GITHUB_VERSION_MONITOR_BASE = 'd:\AI\Workspace\automatic\github-version-monitor\.production-validation-v110-final\T38-C'
. 'd:\AI\Workspace\automatic\github-version-monitor\.production-validation-v110-final\lib\step1.ps1'
. 'd:\AI\Workspace\automatic\github-version-monitor\.production-validation-v110-final\lib\step2.ps1'
. 'd:\AI\Workspace\automatic\github-version-monitor\.production-validation-v110-final\lib\step3.ps1'
$resultPath = Join-Path $env:GITHUB_VERSION_MONITOR_BASE '.monitor\result.json'
$pwshPath = (Get-Command pwsh).Source
$holderScript = 'd:\AI\Workspace\automatic\github-version-monitor\.production-validation-v110-final\lib\lock-holder.ps1'
$holderProc = Start-Process -FilePath $pwshPath -ArgumentList @('-NoProfile','-NonInteractive','-File',$holderScript,'-FilePath',$resultPath,'-ShareMode','Read') -WindowStyle Hidden -PassThru
Start-Sleep -Seconds 3
. 'd:\AI\Workspace\automatic\github-version-monitor\.production-validation-v110-final\lib\step4.ps1'
try { Stop-Process -Id $holderProc.Id -Force -ErrorAction SilentlyContinue } catch {}
