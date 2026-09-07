$ErrorActionPreference = 'Stop'
# $base 解析顺序：环境变量 → 脚本所在目录 → 本机默认
$base = if ($env:GITHUB_VERSION_MONITOR_BASE) { $env:GITHUB_VERSION_MONITOR_BASE }
        elseif ($PSScriptRoot) { $PSScriptRoot }
        else { 'D:\AI\Workspace\automatic\github-version-monitor' }
$md = Join-Path (Join-Path $base '.output') 'GitHub更新监测列表.md'
$monitorDir = Join-Path $base '.monitor'

# 状态文件存在性检查先于 lock：STATE_MISSING 不得留下锁副作用
if (-not (Test-Path $md)) {
    Write-Output 'STATE_MISSING|状态文件 .output\GitHub更新监测列表.md 不存在；不创建空清单。需提供初始清单（releases 链接 + 本地版本）后重跑。'
    return
}
New-Item -ItemType Directory -Force -Path $monitorDir | Out-Null

# 加载 GITHUB_TOKEN：系统环境变量 > 本目录 .env（不进 git、不进 skill 代码）
if (-not $env:GITHUB_TOKEN) {
    $envFile = Join-Path $base '.env'
    if (Test-Path $envFile) {
        foreach ($line in (Get-Content $envFile)) {
            if ($line -match '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.+?)\s*$') {
                if (-not (Test-Path "env:$($Matches[1])") -or -not (Get-Content "env:$($Matches[1])")) {
                    Set-Content -Path "env:$($Matches[1])" -Value $Matches[2]
                }
            }
        }
    }
}

# 运行锁：原子创建互斥（FileMode.CreateNew = 并发下只有一个进程能成功创建）
# 互斥模型：①CreateNew 争锁，失败者退出；②"锁文件存在 + heartbeat 新鲜"= 本轮持有；
# ③陈锁（heartbeat 超 30 分钟）必须同时满足锁内 PID 已死亡才允许接管；任何不确定 → 保守 LOCKED。
# 本模型不是持续持有的 OS 文件句柄锁。
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
    Write-Output 'LOCKED|另一轮监测持有运行锁（或陈锁判定不确定，保守不抢），本轮直接退出。'
    return
}

# 提前备份（时间戳内部 UTC，展示 UTC+08:00）
$backupDir = Join-Path $monitorDir 'backups'
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
$ts = [DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromHours(8)).ToString('yyyyMMdd-HHmmssfff')
Copy-Item $md (Join-Path $backupDir "GitHub更新监测列表.backup.$ts.md")
Write-Output "BACKUP_OK|$ts"