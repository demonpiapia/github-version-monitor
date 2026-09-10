#Requires -Version 7.0
$ErrorActionPreference = 'Stop'
$PSDefaultParameterValues['*:Encoding'] = 'UTF8'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$root = 'D:\AI\Workspace\automatic\github-version-monitor'
$p1dir = Join-Path $root '.production-validation-v112-final'

$t1Stdout = Get-Content (Join-Path $p1dir 'T1-PS7\stdout.txt') -Raw
$t2Stdout = Get-Content (Join-Path $p1dir 'T2-success\stdout.txt') -Raw
$t1Stderr = Get-Content (Join-Path $p1dir 'T1-PS7\stderr.txt') -Raw
$t2Stderr = Get-Content (Join-Path $p1dir 'T2-success\stderr.txt') -Raw

$sep = "`r`n===== [END OF TEST] =====`r`n"
$out = "===== TEST T1-PS7 stdout BEGIN =====`r`n" + $t1Stdout + $sep + "===== TEST T2-success stdout BEGIN =====`r`n" + $t2Stdout
$err = "===== TEST T1-PS7 stderr BEGIN =====`r`n" + $t1Stderr + $sep + "===== TEST T2-success stderr BEGIN =====`r`n" + $t2Stderr

Set-Content -Path (Join-Path $p1dir 'phase3-stdout.txt') -Value $out -Encoding UTF8
Set-Content -Path (Join-Path $p1dir 'phase3-stderr.txt') -Value $err -Encoding UTF8

Write-Output ("STDOUT_BYTES=" + (Get-Item (Join-Path $p1dir 'phase3-stdout.txt')).Length)
Write-Output ("STDERR_BYTES=" + (Get-Item (Join-Path $p1dir 'phase3-stderr.txt')).Length)
