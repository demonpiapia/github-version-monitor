$base = if ($env:GITHUB_VERSION_MONITOR_BASE) { $env:GITHUB_VERSION_MONITOR_BASE }
        elseif ($PSScriptRoot) { $PSScriptRoot }
        else { 'D:\AI\Workspace\automatic\github-version-monitor' }
$monitorDir = Join-Path $base '.monitor'
# 锁 heartbeat（保活，且必须确认 ownership）
$lockPath = Join-Path $monitorDir 'run.lock'
try {
    $raw = Get-Content $lockPath -Raw -ErrorAction Stop
    if ($raw -notmatch ('pid=' + [regex]::Escape([string]$PID) + ';')) { throw '运行锁 ownership 不属于当前进程' }
    $startTok = if ($raw -match 'start=([^;\r\n]+)') { $Matches[1] } else { [DateTimeOffset]::UtcNow.ToString('o') }
    $fs = [System.IO.File]::Open($lockPath,[System.IO.FileMode]::Open,[System.IO.FileAccess]::ReadWrite,[System.IO.FileShare]::None)
    try { $fs.SetLength(0);$b=[Text.Encoding]::UTF8.GetBytes(('pid={0};start={1};step=3;beat={2}'-f $PID,$startTok,[DateTimeOffset]::UtcNow.ToString('o')));$fs.Write($b,0,$b.Length) } finally { $fs.Close() }
} catch [System.IO.IOException] { Write-Output 'LOCKED|运行锁无法独占刷新 heartbeat，本轮退出。'; return } catch { Write-Output ('RUNTIME_ERROR|步骤3 heartbeat 失败：{0}'-f $_.Exception.Message); return }
$backupDir = Join-Path $base '.monitor\backups'
$trashDir  = Join-Path $base '.monitor\trash'
New-Item -ItemType Directory -Force -Path $trashDir | Out-Null
Get-ChildItem $backupDir -Filter 'GitHub更新监测列表.backup.*.md' |
  Sort-Object Name -Descending | Select-Object -Skip 1 |
  Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-3) } |
  ForEach-Object { Move-Item $_.FullName (Join-Path $trashDir $_.Name) -Force }
