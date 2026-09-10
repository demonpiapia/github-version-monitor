#Requires -Version 7.0
param(
    [Parameter(Mandatory=$true)][string]$Target,
    [Parameter(Mandatory=$true)][string]$MarkerPath
)

$PSDefaultParameterValues['*:Encoding'] = 'UTF8'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = 'Stop'

# =====================================================================
# lock-holder.ps1
# Purpose: external file lock holder for T4 write-failure injection.
# Contract (B1 revision, verified on hardware):
#   - Hold an exclusive FileShare::Read handle on $Target
#     (NOT FileShare::None - 3-arg call binds to wrong overload).
#   - Must use the 4-parameter overload of [System.IO.File]::Open:
#         Open($target, FileMode.Open, FileAccess.Read, FileShare.Read)
#   - Immediately after Open succeeds, write "OPENED_OK" to $MarkerPath
#     for the harness to poll.
#   - On any failure, write "OPEN_FAILED: <msg>" to $MarkerPath and exit
#     immediately so the harness can abort rather than hanging.
#   - After OPENED_OK, loop forever keeping the stream handle open.
# =====================================================================

$fs = $null
try {
    # Explicit 4-parameter overload - critical for correct binding.
    # 3-arg overload (path, FileMode, FileAccess) binds to (path, FileMode,
    # FileAccess, FileShare::ReadWrite) which is UNSAFE here because we want
    # to prevent other processes from WriteAccess. FileShare::Read permits
    # concurrent readers but blocks writers.
    $fs = [System.IO.File]::Open(
        $Target,
        [System.IO.FileMode]::Open,
        [System.IO.FileAccess]::Read,
        [System.IO.FileShare]::Read
    )

    # Signal harness that lock acquisition succeeded.
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($MarkerPath, "OPENED_OK pid=$PID target=$Target ts=$([DateTimeOffset]::UtcNow.ToString('o'))", $utf8)

    # Keep alive - stream stays open until this process is killed.
    while ($true) { Start-Sleep -Seconds 1 }
} catch {
    $msg = $_.Exception.Message -replace "`r"," " -replace "`n"," "
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($MarkerPath, "OPEN_FAILED: $msg", $utf8)
    if ($null -ne $fs) { try { $fs.Close() } catch {} }
    exit 1
}
