# lock-holder.ps1 - 后台文件锁持有者
# 用途：以指定 FileShare 模式打开指定文件，持续持有锁直到进程被终止。
# 用法：Start-Process pwsh -ArgumentList '-NoProfile','-NonInteractive','-File','lock-holder.ps1','-FilePath','<path>','-ShareMode','<mode>' -WindowStyle Hidden
#
# ShareMode 选项：
#   None    - 独占，阻止其他进程读取或写入（用于 T38-heartbeat 锁 run.lock）
#   Read    - 允许其他进程读取，但阻止写入（用于 T38-C 锁 result.json，允许 step4 读取但阻止 Move-Item 替换）
#   Write   - 允许其他进程写入，但阻止读取
#
# 设计说明：
#   - 用于 T38-A (result.review.tmp 独占)、T38-C (result.json Read-share)、T38-heartbeat (run.lock 独占)
#   - 进程保持运行直到被 Stop-Process 终止；无自动超时（避免测试中途锁丢失）
#   - 输出 "LOCK_HELD|<path>|pid=<pid>|share=<mode>" 到 stdout，供父进程确认锁已建立

param(
    [Parameter(Mandatory=$true)][string]$FilePath,
    [string]$ShareMode = 'None'
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $FilePath)) {
    Write-Error "File does not exist: $FilePath"
    exit 1
}

# Map share mode string to enum
$share = switch ($ShareMode) {
    'None'  { [System.IO.FileShare]::None }
    'Read'  { [System.IO.FileShare]::Read }
    'Write' { [System.IO.FileShare]::Write }
    'ReadWrite' { [System.IO.FileShare]::ReadWrite }
    default { [System.IO.FileShare]::None }
}

try {
    $fs = [System.IO.File]::Open($FilePath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, $share)
    Write-Output ("LOCK_HELD|{0}|pid={1}|share={2}" -f $FilePath, $PID, $ShareMode)
    # 保持进程运行，持有文件句柄
    while ($true) {
        Start-Sleep -Seconds 60
    }
} catch {
    Write-Error ("Failed to open file for lock (share={0}): {1}" -f $ShareMode, $_.Exception.Message)
    exit 2
}
