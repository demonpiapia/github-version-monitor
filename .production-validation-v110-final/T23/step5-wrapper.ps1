$ErrorActionPreference = 'Continue'
$env:GITHUB_VERSION_MONITOR_BASE = 'D:\AI\Workspace\automatic\github-version-monitor\.production-validation-v110-final\T23'
. 'D:\AI\Workspace\automatic\github-version-monitor\.production-validation-v110-final\lib\step1.ps1'
. 'D:\AI\Workspace\automatic\github-version-monitor\.production-validation-v110-final\lib\step2.ps1'
. 'D:\AI\Workspace\automatic\github-version-monitor\.production-validation-v110-final\lib\step3.ps1'
. 'D:\AI\Workspace\automatic\github-version-monitor\.production-validation-v110-final\lib\step4.ps1'
$mdPath = Join-Path $env:GITHUB_VERSION_MONITOR_BASE '.output\GitHub更新监测列表.md'
$pwshPath = (Get-Command pwsh).Source
$holderScript = 'D:\AI\Workspace\automatic\github-version-monitor\.production-validation-v110-final\lib\lock-holder.ps1'
$holderStdout = 'D:\AI\Workspace\automatic\github-version-monitor\.production-validation-v110-final\T23\lock-holder-stdout.txt'
$holderStderr = 'D:\AI\Workspace\automatic\github-version-monitor\.production-validation-v110-final\T23\lock-holder-stderr.txt'
$holderProc = Start-Process -FilePath $pwshPath -ArgumentList @('-NoProfile','-NonInteractive','-File',$holderScript,'-FilePath',$mdPath,'-ShareMode','Read') -WindowStyle Hidden -PassThru -RedirectStandardOutput $holderStdout -RedirectStandardError $holderStderr
Start-Sleep -Seconds 3
Write-Output ('T23_LOCKHOLDER_STARTED|pid=' + $holderProc.Id)
. 'D:\AI\Workspace\automatic\github-version-monitor\.production-validation-v110-final\lib\step5-full.ps1'
try { Stop-Process -Id $holderProc.Id -Force -ErrorAction SilentlyContinue; Write-Output 'T23_LOCKHOLDER_STOPPED' } catch { Write-Output ('T23_LOCKHOLDER_STOP_FAIL|' + $_) }
