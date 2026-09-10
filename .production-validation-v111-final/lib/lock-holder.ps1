# lock-holder.ps1 — 外部文件锁持有进程（Phase 1 Step 6）
#
# 用途：以 FileShare::None 独占打开目标文件并保持句柄，直到信号文件出现。
# 用于 T38-A / T38-C / T38-heartbeat / T23 的故障注入维度（§0.5 进程模型维度区分：
# 同一进程无法对同一文件持锁后再次打开，故必须独立后台进程）。
#
# 启动方式（编排器侧）：
#   $p = Start-Process pwsh -ArgumentList '-NoProfile','-NonInteractive','-File',$holder,$target,$signal -WindowStyle Hidden -PassThru
# 终止方式：
#   Set-Content $signal -Value 'done' -Force   # 优雅退出（进程自行关闭句柄）
#   Stop-Process -Id $p.Id -Force              # 兜底
#
# 参数：
#   $args[0] = 目标文件路径（必须先存在）
#   $args[1] = 信号文件路径（出现即退出）
#   $args[2] = 可选：轮询间隔毫秒（默认 50）

param([Parameter(Mandatory)][string]$Target, [Parameter(Mandatory)][string]$Signal, [int]$PollMs = 50)

$ErrorActionPreference = 'Stop'
$fs = $null
try {
    $fs = [System.IO.File]::Open($Target, [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
    Write-Output ('LOCK_HOLDER|acquired|path={0}|pid={1}|handle={2}' -f $Target, $PID, $fs.GetHashCode())
    while (-not (Test-Path $Signal)) { Start-Sleep -Milliseconds $PollMs }
    Write-Output ('LOCK_HOLDER|release_requested|signal={0}|pid={1}' -f $Signal, $PID)
} catch {
    Write-Output ('LOCK_HOLDER|ERROR|{0}' -f $_.Exception.Message)
    exit 2
} finally {
    if ($null -ne $fs) { try { $fs.Close() } catch {} }
    Write-Output ('LOCK_HOLDER|closed|pid={0}' -f $PID)
}
