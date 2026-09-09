# step4-t38-stats-items-harness.ps1 - T38-stats-items 同进程 harness
# 目标：SKILL L480 stats/items 完整性失败路径（v1.10 中 return 被移除）。
#
# 注入点：SKILL L479（foreach 循环，循环体全在此行）与 L480（$doc.review 赋值 +
#         $newStats/$newItems 计算 + if 校验混合行）之间。
#
# 注入内容：篡改 $doc.stats.total = 999，使 L480 计算的 $newStats 与 $origStats 不一致。
#
# 注入有效性依据：$origStats 在 L478 行尾已固化为 JSON 字符串快照
# （$doc.stats|ConvertTo-Json -Depth 8 -Compress），注入修改 $doc.stats.total 后，
# L480 计算的 $newStats 序列化结果必然 ≠ $origStats（字符串比较，修改必然反映）→ 校验失败路径触发。
#
# 边界条件：fixture result.json 的 stats.total 不得恰为 999，否则注入可能无效。
#
# 设计原因：pwsh -File 模式下脚本不可暂停；dot-source step4.ps1 会一次性执行完整 Step 4，
# 无法在 foreach 与 if 校验之间注入。因此采用内联复制 + 精确注入方式。

$ErrorActionPreference='Stop'
$base=if($env:GITHUB_VERSION_MONITOR_BASE){$env:GITHUB_VERSION_MONITOR_BASE}elseif($PSScriptRoot){$PSScriptRoot}else{'D:\AI\Workspace\automatic\github-version-monitor'}
$monitorDir=Join-Path $base '.monitor';$resultPath=Join-Path $monitorDir 'result.json';$tmpPath=Join-Path $monitorDir 'result.review.tmp';$lockPath=Join-Path $monitorDir 'run.lock'
function Release-LockSafely { try{$raw=Get-Content $lockPath -Raw -ErrorAction Stop;if($raw-notmatch('pid='+[regex]::Escape([string]$PID)+';')){return $false};Remove-Item $lockPath -Force -ErrorAction Stop;return(-not(Test-Path $lockPath))}catch{return $false} }
try{$raw=Get-Content $lockPath -Raw -ErrorAction Stop;if($raw-notmatch('pid='+[regex]::Escape([string]$PID)+';')){throw 'ownership mismatch'};$startTok=if($raw-match 'start=([^;\r\n]+)'){$Matches[1]}else{[DateTimeOffset]::UtcNow.ToString('o')};$fs=[IO.File]::Open($lockPath,[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None);try{$fs.SetLength(0);$b=[Text.Encoding]::UTF8.GetBytes(('pid={0};start={1};step=4;beat={2}'-f $PID,$startTok,[DateTimeOffset]::UtcNow.ToString('o')));$fs.Write($b,0,$b.Length)}finally{$fs.Close()}}catch{Write-Output ('RUNTIME_ERROR|步骤4 heartbeat 失败：{0}'-f $_.Exception.Message);Write-Output 'RUN_STATUS|failed|步骤4 heartbeat 失败，整轮终止。';return}
try { $doc=Get-Content $resultPath -Raw|ConvertFrom-Json } catch { Write-Output ('RUNTIME_ERROR|读取 result.json 失败：{0}'-f $_.Exception.Message); $released=Release-LockSafely; if (-not $released) { Write-Output 'RUNTIME_ERROR|读取 result.json 失败后锁释放失败，保留锁供陈锁机制接管。' }; Write-Output 'RUN_STATUS|failed|读取 result.json 失败，整轮终止。'; return };$origStats=$doc.stats|ConvertTo-Json -Depth 8 -Compress;$origItems=$doc.items|ConvertTo-Json -Depth 8 -Compress;$candidates=@($doc.items|Where-Object{$_.review-eq $true});$reviewItems=@();$headers=@{'User-Agent'='workbuddy-version-monitor';'Accept'='application/vnd.github+json';'X-GitHub-Api-Version'='2026-03-10'};if($env:GITHUB_TOKEN){$headers['Authorization']='Bearer '+$env:GITHUB_TOKEN}
foreach($it in $candidates){if($it.status-eq 'rate_limited'){$reviewItems+=[PSCustomObject]@{repo=$it.repo;sources=@('releases_latest');finding='主查询已限流；不重试、不追加复核请求。';conclusion='pending';reasons=@($it.reviewReasons);apiListStatus='skipped_rate_limited';apiList=@();htmlStatus='skipped_rate_limited';htmlTitle=''};continue};$apiList=@();$apiListStatus='error';$htmlStatus='error';$htmlTitle='';$parts=@();try{$apiList=@(Invoke-RestMethod -Uri "https://api.github.com/repos/$($it.repo)/releases?per_page=5" -Headers $headers -TimeoutSec 20)|ForEach-Object{$pub='';if($_.published_at){try{$pub=ConvertTo-UtcIso $_.published_at}catch{}};[PSCustomObject]@{tag_name=[string]$_.tag_name;published_at=$pub;prerelease=[bool]$_.prerelease;draft=[bool]$_.draft}};$apiListStatus='ok'}catch{$parts+='列表接口复核请求失败。'};if($apiListStatus-eq 'ok' -and $apiList.Count -gt 0){$parts+=('列表接口前{0}项：{1}'-f $apiList.Count,(($apiList|ForEach-Object{"$($_.tag_name)|pre=$($_.prerelease)|draft=$($_.draft)|published=$($_.published_at)"})-join '; '))}elseif($apiListStatus-eq 'ok'){$parts+='列表接口返回空集合。'};try{$html=Invoke-WebRequest -Uri "https://github.com/$($it.repo)/releases" -Headers @{'User-Agent'='workbuddy-version-monitor'} -TimeoutSec 20 -UseBasicParsing;$htmlStatus=[string]$html.StatusCode;$htmlTitle=[regex]::Match([string]$html.Content,'<title>\s*(?<t>.*?)\s*</title>','IgnoreCase').Groups['t'].Value;$parts+=('HTML 诊断 HTTP {0}；页面标题仅供诊断：{1}'-f $htmlStatus,$htmlTitle)}catch{$parts+='HTML 诊断请求失败。'};$reviewItems+=[PSCustomObject]@{repo=$it.repo;sources=@('releases_api','html');finding=($parts-join ' ');conclusion='pending';reasons=@($it.reviewReasons);apiListStatus=$apiListStatus;apiList=@($apiList);htmlStatus=$htmlStatus;htmlTitle=$htmlTitle}}
# ==== T38-stats-items 注入：篡改 stats 使完整性校验失败 ====
$doc.stats.total = 999
# ==== T38-stats-items 注入结束 ====
$doc.review=[PSCustomObject]@{performed=$true;items=@($reviewItems)};$newStats=$doc.stats|ConvertTo-Json -Depth 8 -Compress;$newItems=$doc.items|ConvertTo-Json -Depth 8 -Compress;if($newStats-ne $origStats-or $newItems-ne $origItems){Remove-Item $tmpPath -Force -ErrorAction SilentlyContinue;Write-Output 'REVIEW_WRITE_ERROR|review 修改了 stats/items，拒绝覆盖 result.json。';$released=Release-LockSafely;if(-not $released){Write-Output 'RUNTIME_ERROR|review stats/items 完整性失败后锁释放失败，保留锁供陈锁机制接管。'};Write-Output 'RUN_STATUS|failed|review 程序事实完整性校验失败，整轮终止。'};try {
    $doc|ConvertTo-Json -Depth 8|Set-Content -Path $tmpPath -Encoding UTF8
} catch {
    Remove-Item $tmpPath -Force -ErrorAction SilentlyContinue
    $released=Release-LockSafely
    Write-Output ('REVIEW_WRITE_ERROR|review 临时文件写入失败：{0}' -f $_.Exception.Message)
    if (-not $released) { Write-Output 'RUNTIME_ERROR|review 写入失败后锁释放失败，保留锁供陈锁机制接管。' }
    Write-Output 'RUN_STATUS|failed|review 写入失败，整轮终止。'
    return
}
try { $check=Get-Content $tmpPath -Raw|ConvertFrom-Json } catch { $check=$null }
if($null-eq $check-or $null-eq $check.review-or ($check.stats|ConvertTo-Json -Depth 8 -Compress)-ne $origStats-or ($check.items|ConvertTo-Json -Depth 8 -Compress)-ne $origItems){
    Remove-Item $tmpPath -Force -ErrorAction SilentlyContinue
    Write-Output 'REVIEW_WRITE_ERROR|review 临时 JSON 校验失败，不替换 result.json。'
    $released=Release-LockSafely
    if (-not $released) { Write-Output 'RUNTIME_ERROR|review 失败后锁释放失败，保留锁供陈锁机制接管。' }
    Write-Output 'RUN_STATUS|failed|review 临时 JSON 校验失败，整轮终止。'
    return
}
try {
    Move-Item $tmpPath $resultPath -Force
} catch {
    Remove-Item $tmpPath -Force -ErrorAction SilentlyContinue
    Write-Output ('REVIEW_WRITE_ERROR|review 原子替换失败：{0}'-f $_.Exception.Message)
    $released=Release-LockSafely
    if (-not $released) { Write-Output 'RUNTIME_ERROR|review 原子替换失败后锁释放失败，保留锁供陈锁机制接管。' }
    Write-Output 'RUN_STATUS|failed|review 原子替换失败，整轮终止。'
    return
}
Write-Output ('REVIEW_WRITE_OK|复核完成：{0} 项；stats/items 保持不变。'-f $reviewItems.Count)
