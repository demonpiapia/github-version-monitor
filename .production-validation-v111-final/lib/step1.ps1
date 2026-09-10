$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
Write-Output ("DEBUG Env at start: {0}" -f $env:GITHUB_VERSION_MONITOR_BASE)
# $base 瑙ｆ瀽椤哄簭锛氱幆澧冨彉閲?鈫?鑴氭湰鎵€鍦ㄧ洰褰?鈫?鏈満榛樿
$base = if ($env:GITHUB_VERSION_MONITOR_BASE) { $env:GITHUB_VERSION_MONITOR_BASE }
        elseif ($PSScriptRoot) { Split-Path $PSScriptRoot -Parent }
        else { 'D:\AI\Workspace\automatic\github-version-monitor' }
$md = Join-Path (Join-Path $base '.output') 'GitHub鏇存柊鐩戞祴鍒楄〃.md'
$monitorDir = Join-Path $base '.monitor'

# 鐘舵€佹枃浠跺瓨鍦ㄦ€ф鏌ュ厛浜?lock锛歋TATE_MISSING 涓嶅緱鐣欎笅閿佸壇浣滅敤
if (-not (Test-Path $md)) {
    Write-Output ("DEBUG Base: {0}" -f $base)
    Write-Output ("DEBUG Md path: {0}" -f $md)
    Write-Output 'STATE_MISSING|鐘舵€佹枃浠?.output\GitHub鏇存柊鐩戞祴鍒楄〃.md 涓嶅瓨鍦紱涓嶅垱寤虹┖娓呭崟銆傞渶鎻愪緵鍒濆娓呭崟锛坮eleases 閾炬帴 + 鏈湴鐗堟湰锛夊悗閲嶈窇銆?
    return
}
New-Item -ItemType Directory -Force -Path $monitorDir | Out-Null

# 鍔犺浇 GITHUB_TOKEN锛氱郴缁熺幆澧冨彉閲?> 鏈洰褰?.env锛堜笉杩?git銆佷笉杩?skill 浠ｇ爜锛?
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

# 杩愯閿侊細鍘熷瓙鍒涘缓浜掓枼锛團ileMode.CreateNew = 骞跺彂涓嬪彧鏈変竴涓繘绋嬭兘鎴愬姛鍒涘缓锛?
# 浜掓枼妯″瀷锛氣憼CreateNew 浜夐攣锛屽け璐ヨ€呴€€鍑猴紱鈶?閿佹枃浠跺瓨鍦?+ heartbeat 鏂伴矞"= 鏈疆鎸佹湁锛?
# 鈶㈤檲閿侊紙heartbeat 瓒?30 鍒嗛挓锛夊繀椤诲悓鏃舵弧瓒抽攣鍐?PID 宸叉浜℃墠鍏佽鎺ョ锛涗换浣曚笉纭畾 鈫?淇濆畧 LOCKED銆?
# 鏈ā鍨嬩笉鏄寔缁寔鏈夌殑 OS 鏂囦欢鍙ユ焺閿併€?
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
    Write-Output 'LOCKED|鍙︿竴杞洃娴嬫寔鏈夎繍琛岄攣锛堟垨闄堥攣鍒ゅ畾涓嶇‘瀹氾紝淇濆畧涓嶆姠锛夛紝鏈疆鐩存帴閫€鍑恒€?
    return
}

# 鎻愬墠澶囦唤锛堟椂闂存埑鍐呴儴 UTC锛屽睍绀?UTC+08:00锛?
$backupDir = Join-Path $monitorDir 'backups'
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
$ts = [DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromHours(8)).ToString('yyyyMMdd-HHmmssfff')
Copy-Item $md (Join-Path $backupDir "GitHub鏇存柊鐩戞祴鍒楄〃.backup.$ts.md")
Write-Output "BACKUP_OK|$ts"

