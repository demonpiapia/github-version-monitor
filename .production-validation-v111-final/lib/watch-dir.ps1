# watch-dir.ps1 — .monitor 目录监视进程（Phase 1 Step 6，Phase 7 使用）
#
# 用途：以 50ms 间隔轮询目标目录，记录"出现的文件名清单"（含首次出现时间戳）。
# 用于 Phase 7 捕获 result.review.tmp 的瞬时存在窗口（D5 主证据）。
#
# 启动方式：
#   $p = Start-Process pwsh -ArgumentList '-NoProfile','-NonInteractive','-File',$watcher,$dir,$log,$signal -WindowStyle Hidden -PassThru
# 终止方式：
#   Set-Content $signal -Value 'done' -Force
#
# 参数：
#   $args[0] = 监视目录
#   $args[1] = 日志输出文件
#   $args[2] = 信号文件（出现即退出）
#   $args[3] = 可选：轮询间隔毫秒（默认 50）

param([Parameter(Mandatory)][string]$Dir, [Parameter(Mandatory)][string]$Log, [Parameter(Mandatory)][string]$Signal, [int]$PollMs = 50)

$ErrorActionPreference = 'Stop'
$seen = @{}
$events = 0
$firstSeen = [DateTimeOffset]::UtcNow
Write-Output ('WATCH_DIR|started|dir={0}|pid={1}|poll_ms={2}' -f $Dir, $PID, $PollMs)

while (-not (Test-Path $Signal)) {
    if (Test-Path $Dir) {
        $names = @()
        try { $names = @(Get-ChildItem $Dir -File -ErrorAction SilentlyContinue | ForEach-Object { $_.Name }) } catch {}
        foreach ($n in $names) {
            if (-not $seen.ContainsKey($n)) {
                $seen[$n] = [DateTimeOffset]::UtcNow
                $events++
                Write-Output ('WATCH_EVENT|first_seen|name={0}|ts={1}|seq={2}' -f $n, $seen[$n].ToString('o'), $events)
            }
        }
    }
    Start-Sleep -Milliseconds $PollMs
}

$lastSeen = [DateTimeOffset]::UtcNow
Write-Output ('WATCH_DIR|stopped|pid={0}|duration_ms={1}|unique_files={2}' -f $PID, (($lastSeen - $firstSeen).TotalMilliseconds), $seen.Count)
Write-Output 'WATCH_SUMMARY|' + (($seen.Keys | Sort-Object) -join ';')
