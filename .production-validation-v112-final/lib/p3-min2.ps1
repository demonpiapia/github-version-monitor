#Requires -Version 7.0
param([Parameter(Mandatory=$true)][ValidateSet('T1-PS7','T2-success')][string]$TestId)
Write-Host "GOT_TESTID=$TestId"
