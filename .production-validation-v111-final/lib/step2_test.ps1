# Test script to verify PS5.1 locking mechanism
$ErrorActionPreference = 'Stop'
Write-Output "TEST_START"

$base = if ($env:GITHUB_VERSION_MONITOR_BASE) { $env:GITHUB_VERSION_MONITOR_BASE } else { '.' }
$monitorDir = Join-Path $base '.monitor'
$lockPath = Join-Path $monitorDir 'run.lock'

Write-Output "BASE: $base"
Write-Output "LOCK_PATH: $lockPath"

if (-not (Test-Path $lockPath)) {
    Write-Output "LOCK_PATH does not exist"
    # Create directory and lock file
    New-Item -ItemType Directory -Force -Path $monitorDir | Out-Null
    Set-Content -Path $lockPath -Value ('pid={0};start={1};step=2;beat={2}' -f $PID, [DateTimeOffset]::UtcNow.ToString('o'), [DateTimeOffset]::UtcNow.ToString('o')) -Encoding UTF8
    Write-Output "CREATED_LOCK"
} else {
    Write-Output "LOCK_PATH exists"
    $prev = Get-Content $lockPath -Raw
    Write-Output "PREV: $prev"
    
    try {
        $fs = [System.IO.File]::Open($lockPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
        $fs.SetLength(0)
        $bytes = [System.Text.Encoding]::UTF8.GetBytes(("pid={0};start={1};step=2;beat={2}" -f $PID, $prev.Split(';')[1], [DateTimeOffset]::UtcNow.ToString('o')))
        $fs.Write($bytes, 0, $bytes.Length)
        $fs.Close()
        Write-Output "UPDATED_LOCK"
    } catch [System.IO.IOException] {
        Write-Output "LOCKED"
        return
    } catch {
        Write-Output ("RUNTIME_ERROR|{0}" -f $_.Exception.Message)
        return
    }
}

Write-Output "TEST_END"