# Step 6: Lock release + final status output
# Extracted from SKILL-v1.7.md (end of Step 5 code block)
$ErrorActionPreference = 'Stop'
$base = if ($env:GITHUB_VERSION_MONITOR_BASE) { $env:GITHUB_VERSION_MONITOR_BASE }
        elseif ($PSScriptRoot) { $PSScriptRoot }
        else { 'D:\AI\Workspace\automatic\github-version-monitor' }
$monitorDir = Join-Path $base '.monitor'
$lockPath = Join-Path $monitorDir 'run.lock'

# Read commit status (written by step5-commit.ps1)
$commitStatusFile = Join-Path $monitorDir 'commit_status.txt'
$commitSucceeded = $false
if (Test-Path $commitStatusFile) {
    $val = (Get-Content $commitStatusFile -Raw).Trim()
    $commitSucceeded = ($val -eq 'True')
}

# 释放锁前确认 ownership：锁内 PID 必须等于当前进程 PID
$lockReleased = $false
try {
    $lockRaw = Get-Content $lockPath -Raw -ErrorAction Stop
    $lockPid = if ($lockRaw -match 'pid=(\d+)') { [int]$Matches[1] } else { -1 }
    if ($lockPid -eq $PID) {
        Remove-Item $lockPath -Force -ErrorAction SilentlyContinue
        $lockReleased = $true
    }
} catch { $lockReleased = $false }
if (-not $lockReleased) {
    Write-Output 'RUNTIME_ERROR|释放锁前 ownership 校验失败（锁内 PID 与当前进程不一致或锁不可读），未删除锁文件。'
    Write-Output 'RUN_STATUS|failed|主 md 提交状态不可否认，但运行锁未安全释放。'
} elseif ($commitSucceeded) {
    Write-Output 'RUN_STATUS|success|fetch + 必要 review + commit + lock release 完成。'
} else {
    Write-Output 'RUN_STATUS|failed|主 md 未提交。'
}
