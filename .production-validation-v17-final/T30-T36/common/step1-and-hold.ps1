$ErrorActionPreference = 'Stop'
$base = if ($env:GITHUB_VERSION_MONITOR_BASE) { $env:GITHUB_VERSION_MONITOR_BASE }
        elseif ($PSScriptRoot) { $PSScriptRoot }
        else { 'D:\AI\Workspace\automatic\github-version-monitor' }
$md = Join-Path $base 'GitHub更新监测列表.md'
$monitorDir = Join-Path $base '.monitor'

if (-not (Test-Path $md)) {
    Write-Output 'STATE_MISSING|'
    return
}
New-Item -ItemType Directory -Force -Path $monitorDir | Out-Null

$lockPath = Join-Path $monitorDir 'run.lock'
function New-LockOnce {
    $fs = [System.IO.File]::Open($lockPath, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
    $fs.Close()
    $nowUtc = [DateTimeOffset]::UtcNow.ToString('o')
    Set-Content -Path $lockPath -Value ("pid={0};start={1};step=1;beat={2}" -f $PID, $nowUtc, $nowUtc)
}
$lockAcquired = $false
try {
    New-LockOnce
    $lockAcquired = $true
} catch [System.IO.IOException] {
    $takeover = $false
    try {
        $raw = Get-Content $lockPath -Raw -ErrorAction Stop
        $ageMin = ((Get-Date) - (Get-Item $lockPath).LastWriteTime).TotalMinutes
        $lockPid = if ($raw -match 'pid=(\d+)') { [int]$Matches[1] } else { -1 }
        if ($ageMin -gt 30 -and $lockPid -gt 0 -and $null -eq (Get-Process -Id $lockPid -ErrorAction SilentlyContinue)) {
            $takeover = $true
        }
    } catch { $takeover = $false }
    if ($takeover) {
        Remove-Item $lockPath -Force -ErrorAction SilentlyContinue
        try { New-LockOnce; $lockAcquired = $true } catch [System.IO.IOException] { $lockAcquired = $false }
    }
}
if (-not $lockAcquired) {
    Write-Output 'LOCKED|'
    return
}

$backupDir = Join-Path $monitorDir 'backups'
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
$ts = [DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromHours(8)).ToString('yyyyMMdd-HHmmssfff')
Copy-Item $md (Join-Path $backupDir "GitHub更新监测列表.backup.$ts.md")
Write-Output "BACKUP_OK|$ts"
Write-Output "PID=$PID"
Write-Output "STEP1_DONE|Lock created, now holding (sleeping to simulate Step 2 work)..."
Start-Sleep -Seconds 60
Write-Output "DONE|Process completed normally."
