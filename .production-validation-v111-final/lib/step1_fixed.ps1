锘?ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
Write-Output ("DEBUG Env at start: {0}" -f $env:GITHUB_VERSION_MONITOR_BASE)
# $base 鐟欙絾鐎芥い鍝勭碍閿涙氨骞嗘晶鍐ㄥ綁闁?閳?閼存碍婀伴幍鈧崷銊ф窗瑜?閳?閺堫剚婧€姒涙顓?
$base = if ($env:GITHUB_VERSION_MONITOR_BASE) { $env:GITHUB_VERSION_MONITOR_BASE }
        elseif ($PSScriptRoot) { Split-Path $PSScriptRoot -Parent }
        else { 'D:\AI\Workspace\automatic\github-version-monitor' }
$md = Join-Path (Join-Path $base '.output') 'GitHub閺囧瓨鏌婇惄鎴炵ゴ閸掓銆?md'
$monitorDir = Join-Path $base '.monitor'

# 閻樿埖鈧焦鏋冩禒璺虹摠閸︺劍鈧勵梾閺屻儱鍘涙禍?lock閿涙瓔TATE_MISSING 娑撳秴绶遍悾娆庣瑓闁夸礁澹囨担婊呮暏
if (-not (Test-Path $md)) {
    Write-Output ("DEBUG Base: {0}" -f $base)
    Write-Output ("DEBUG Md path: {0}" -f $md)
    Write-Output 'STATE_MISSING|閻樿埖鈧焦鏋冩禒?.output\GitHub閺囧瓨鏌婇惄鎴炵ゴ閸掓銆?md 娑撳秴鐡ㄩ崷顭掔幢娑撳秴鍨卞铏光敄濞撳懎宕熼妴鍌炴付閹绘劒绶甸崚婵嗩潗濞撳懎宕熼敍鍧甧leases 闁剧偓甯?+ 閺堫剙婀撮悧鍫熸拱閿涘鎮楅柌宥堢獓閵?
    return
}
New-Item -ItemType Directory -Force -Path $monitorDir | Out-Null

# 閸旂姾娴?GITHUB_TOKEN閿涙氨閮寸紒鐔哄箚婢у啫褰夐柌?> 閺堫剛娲拌ぐ?.env閿涘牅绗夋潻?git閵嗕椒绗夋潻?skill 娴狅絿鐖滈敍?
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

# 鏉╂劘顢戦柨渚婄窗閸樼喎鐡欓崚娑樼紦娴滄帗鏋奸敍鍦榠leMode.CreateNew = 楠炶泛褰傛稉瀣涧閺堝绔存稉顏囩箻缁嬪鍏橀幋鎰閸掓稑缂撻敍?
# 娴滄帗鏋煎Ο鈥崇€烽敍姘ｆ喖CreateNew 娴滃鏀ｉ敍灞姐亼鐠愩儴鈧懘鈧偓閸戠尨绱遍埗?闁夸焦鏋冩禒璺虹摠閸?+ heartbeat 閺備即鐭?= 閺堫剝鐤嗛幐浣规箒閿?
# 閳躲垽妾查柨渚婄礄heartbeat 鐡?30 閸掑棝鎸撻敍澶婄箑妞よ鎮撻弮鑸靛姬鐡掓娊鏀ｉ崘?PID 瀹稿弶顒存禍鈩冨閸忎浇顔忛幒銉ь吀閿涙稐鎹㈡担鏇氱瑝绾喖鐣?閳?娣囨繂鐣?LOCKED閵?
# 閺堫剚膩閸ㄥ绗夐弰顖涘瘮缂侇厽瀵旈張澶屾畱 OS 閺傚洣娆㈤崣銉︾労闁夸降鈧?
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
    Write-Output 'LOCKED|閸欙缚绔存潪顔炬磧濞村瀵旈張澶庣箥鐞涘矂鏀ｉ敍鍫熷灗闂勫牓鏀ｉ崚銈呯暰娑撳秶鈥樼€规熬绱濇穱婵嗙暓娑撳秵濮犻敍澶涚礉閺堫剝鐤嗛惄瀛樺复闁偓閸戞亽鈧?
    return
}

# 閹绘劕澧犳径鍥﹀敜閿涘牊妞傞梻瀛樺煈閸愬懘鍎?UTC閿涘苯鐫嶇粈?UTC+08:00閿?
$backupDir = Join-Path $monitorDir 'backups'
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
$ts = [DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromHours(8)).ToString('yyyyMMdd-HHmmssfff')
Copy-Item $md (Join-Path $backupDir "GitHub閺囧瓨鏌婇惄鎴炵ゴ閸掓銆?backup.$ts.md")
Write-Output "BACKUP_OK|$ts"

