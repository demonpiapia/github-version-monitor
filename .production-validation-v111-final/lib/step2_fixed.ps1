$ErrorActionPreference = 'Stop'
$base = if ($env:GITHUB_VERSION_MONITOR_BASE) { $env:GITHUB_VERSION_MONITOR_BASE }
        elseif ($PSScriptRoot) { $PSScriptRoot }
        else { 'D:\AI\Workspace\automatic\github-version-monitor' }
if (-not $env:GITHUB_TOKEN) { $envFile = Join-Path $base '.env'; if (Test-Path $envFile) { foreach ($line in (Get-Content $envFile)) { if ($line -match '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.+?)\s*$') { if (-not (Get-Content "env:$($Matches[1])" -ErrorAction SilentlyContinue)) { Set-Content -Path "env:$($Matches[1])" -Value $Matches[2] } } } } }
$md = Join-Path (Join-Path $base '.output') 'GitHub鏇存柊鐩戞祴鍒楄〃.md'
$monitorDir = Join-Path $base '.monitor'

function Release-LockSafely { try { $raw=Get-Content $lockPath -Raw -ErrorAction Stop; if($raw -notmatch ('pid='+[regex]::Escape([string]$PID)+';')){return $false}; Remove-Item $lockPath -Force -ErrorAction Stop; return(-not(Test-Path $lockPath)) } catch { return $false } }

# 閿?heartbeat锛氱嫭鍗犳墦寮€閿佹枃浠跺埛鏂?beat锛堣鐙崰 = 寮傚父骞跺彂 鈫?LOCKED锛涙枃浠舵秷澶?鈫?RUNTIME_ERROR锛?
$lockPath = Join-Path $monitorDir 'run.lock'
if (-not (Test-Path $lockPath)) {
    Write-Output 'RUNTIME_ERROR|杩愯閿佷笉瀛樺湪锛堟楠?鏈墽琛屾垨閿佸凡涓㈠け锛夛紝鏈疆缁堟銆?
    return
}
try {
    $prev = Get-Content $lockPath -Raw
    $startTok = if ($prev -match 'start=([^;\r\n]+)') { $Matches[1] } else { [DateTimeOffset]::UtcNow.ToString('o') }
    $fs = [System.IO.File]::Open($lockPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
    $fs.SetLength(0)
    $bytes = [System.Text.Encoding]::UTF8.GetBytes(("pid={0};start={1};step=2;beat={2}" -f $PID, $startTok, [DateTimeOffset]::UtcNow.ToString('o')))
    $fs.Write($bytes, 0, $bytes.Length)
    $fs.Close()
} catch [System.IO.IOException] {
    Write-Output 'LOCKED|杩愯閿佽鍙︿竴杩涚▼鐙崰鎸佹湁锛堝紓甯稿苟鍙戯級锛屾湰杞€€鍑恒€?
    return
} catch {
    Write-Output ("RUNTIME_ERROR|閿?heartbeat 鍒锋柊澶辫触锛歿0}" -f $_.Exception.Message)
    return
}

$text = Get-Content $md -Raw

# 鐗堟湰姣旇緝鍑芥暟锛堝敮涓€鍚堟硶鐨勭増鏈ぇ灏忓垽瀹氾紝agent 涓嶅緱浠ｆ浛锛?
function ConvertTo-NormVer {
    param([string]$v)
    if ([string]::IsNullOrWhiteSpace($v) -or $v -match '鏈畨瑁厊鏆傛棤') { return $null }
    $s = $v.Trim() -replace '^[vV]', '' -replace '\+.*$', ''
    $m = [regex]::Match($s, '^(\d+)(?:\.(\d+))?(?:\.(\d+))?(?:[-_.](rc|prototype|alpha|beta|nightly|canary|pre|dev|r)[-_.]?(\d+))?$', 'IgnoreCase')
    if (-not $m.Success) { return $null }
    [PSCustomObject]@{
        Major   = [int]$m.Groups[1].Value
        Minor   = if ($m.Groups[2].Success) { [int]$m.Groups[2].Value } else { 0 }
        Patch   = if ($m.Groups[3].Success) { [int]$m.Groups[3].Value } else { 0 }
        Pre     = $m.Groups[4].Success
        PreName = if ($m.Groups[4].Success) { $m.Groups[4].Value.ToLower() } else { '' }
        PreNum  = if ($m.Groups[5].Success) { [int]$m.Groups[5].Value } else { 0 }
    }
}
function Compare-Ver {
    # 杩斿洖 'lt' | 'eq' | 'gt' | 'incomparable'锛堣涔夛細$a 鐩稿 $b锛?
    param([string]$a, [string]$b)
    $na = ConvertTo-NormVer $a; $nb = ConvertTo-NormVer $b
    if ($null -eq $na -or $null -eq $nb) { return 'incomparable' }
    foreach ($f in 'Major','Minor','Patch') {
        if ($na.$f -lt $nb.$f) { return 'lt' }
        if ($na.$f -gt $nb.$f) { return 'gt' }
    }
    if (-not $na.Pre -and -not $nb.Pre) { return 'eq' }
    if ($na.Pre -and -not $nb.Pre) { return 'lt' }
    if (-not $na.Pre -and $nb.Pre)   { return 'gt' }
    if ($na.PreName -ne $nb.PreName) { return 'incomparable' }
    if ($na.PreNum -lt $nb.PreNum) { return 'lt' }
    if ($na.PreNum -gt $nb.PreNum) { return 'gt' }
    return 'eq'
}

function ConvertTo-UtcIso {
    param($Value)
    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) { return '' }
    if ($Value -is [DateTimeOffset]) { return $Value.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ') }
    if ($Value -is [DateTime]) { return ([DateTimeOffset]$Value).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ') }
    return ([DateTimeOffset]::Parse([string]$Value)).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
}

# 瑙ｆ瀽锛坒ail-closed锛氬€欓€夎瑙ｆ瀽澶辫触 鈫?鏁磋疆缁堟锛屼笉闈欓粯璺宠繃锛?
$sections=@($text -split '(?m)^## ');$monitorSections=@($sections|Where-Object{$_ -match '^鐩戞祴鍒楄〃(?:\r?\n|$)'});$parseErrors=@();$repos=@()
if($monitorSections.Count -ne 1){$parseErrors+=('`## 鐩戞祴鍒楄〃` 鑺傛暟閲忓簲涓?1锛屽疄闄?{0}'-f $monitorSections.Count)}
if($monitorSections.Count -eq 1){$sec=$monitorSections[0];$rows=@($sec -split "`n"|Where-Object{$_-match '^\s*\|'});$headerCount=0;$dataRows=@();foreach($r in $rows){$t=$r.Trim();if(($t-replace '[|\s:\-]','')-eq ''){continue};$c=@($t.Trim('|')-split '\|'|ForEach-Object{$_.Trim()});if($c.Count -eq 6 -and (($c-join '|')-ceq '#|椤圭洰鍚嶇О|GIT鏈€鏂扮増鏈瑋GIT鏇存柊鏃ユ湡|鏈湴鐗堟湰|鏄惁鏇存柊')){$headerCount++;continue};$dataRows+=,[PSCustomObject]@{Text=$t;Cells=$c}};if($headerCount-ne 1){$parseErrors+=('鐩戞祴鍒楄〃鍥哄畾琛ㄥご鏁伴噺搴斾负 1锛屽疄闄?{0}'-f $headerCount)};if($text-notmatch '(?m)^>.*鏈€杩戞牳瀵规椂闂?){$parseErrors+='缂哄皯椤堕儴鈥滄渶杩戞牳瀵规椂闂粹€濊'};foreach($anchor in @('缁撹','鏇存柊鎽樿','澶囨敞','鏍稿鏂规硶')){if($text-notmatch ('(?m)^##\s*'+[regex]::Escape($anchor)+'\s*$')){$parseErrors+=('缂哄皯鍐欏洖閿氱偣锛?# {0}'-f $anchor)}};$linkRe=[regex]'\[([^\]]+)\]\(https?://github\.com/([^/]+)/([^/]+)/releases\)';foreach($row in $dataRows){$t=$row.Text;$c=$row.Cells;if($c.Count-ne 6){$parseErrors+=('鍒楁暟 {0}锛堝簲涓?6锛夛細{1}'-f $c.Count,$t);continue};if($c[0]-cnotmatch '^\d+$'){$parseErrors+=('绗?1 鍒楀簭鍙烽潪娉曪細{0}'-f $t);continue};$m=$linkRe.Match($c[1]);if(-not $m.Success){$parseErrors+=('绗?2 鍒楅潪鍚堟硶 releases 閾炬帴锛歿0}'-f $t);continue};if($c[5]-cnotmatch '^(yes|no)$'){$parseErrors+=('绗?6 鍒?flag 闈炴硶锛歿0}'-f $t);continue};$repoKey='{0}/{1}'-f $m.Groups[2].Value,$m.Groups[3].Value;if(@($repos|Where-Object{$_.repo-ceq $repoKey}).Count -gt 0){$parseErrors+=('repo 閲嶅锛歿0}'-f $repoKey);continue};$repos+=[PSCustomObject]@{repo=$repoKey;name=$m.Groups[1].Value;prevGitVer=$c[2];prevGitDate=$c[3];localVer=$c[4];prevFlag=$c[5]}}}
if($parseErrors.Count -gt 0 -or $repos.Count -eq 0){Write-Output 'PARSE_ERROR|鐘舵€佹枃浠?schema 鏍￠獙澶辫触锛屾湰杞粓姝紝涓嶅啓鍥炰富 md銆?;$parseErrors|ForEach-Object{Write-Output "  闂锛?_"};try{$rawLock=Get-Content $lockPath -Raw -ErrorAction Stop;if($rawLock-match('pid='+[regex]::Escape([string]$PID)+';')){Remove-Item $lockPath -Force -ErrorAction Stop}}catch{Write-Output 'RUNTIME_ERROR|PARSE_ERROR 鍚庨噴鏀鹃攣澶辫触銆?};return}

# API 鏌ヨ锛堟瘡浠撳簱 1 娆?latest锛涚姸鎬佹満鍒嗙被锛涙椂闂村唴閮?UTC锛?
$token = $env:GITHUB_TOKEN
function Get-ResponseHeaderValue {
    param($Headers,[string]$Name)
    try { if ($Headers -is [System.Net.WebHeaderCollection]) { $v=$Headers.Get($Name); if ($null -ne $v -and [string]$v -ne '') { return [string]$v } } } catch {}
    try { $v=$Headers[$Name]; if ($null -ne $v -and [string]$v -ne '') { return [string]$v } } catch {}
    try { $values=$null; if ($Headers.TryGetValues($Name,[ref]$values)) { $first=$values|Select-Object -First 1; if ($null -ne $first) { return [string]$first } } } catch {}
    return ''
}

$headers = @{ 'User-Agent' = 'workbuddy-version-monitor'
              'Accept'     = 'application/vnd.github+json'
              'X-GitHub-Api-Version' = '2026-03-10' }
if ($token) { $headers['Authorization'] = "Bearer $token" }

$out = @()
foreach ($it in $repos) {
    $status = 'ok'; $latest = ''; $pubDate = ''; $pubUtc = ''; $err = ''; $rl = ''
    try {
        $j = Invoke-RestMethod -Uri "https://api.github.com/repos/$($it.repo)/releases/latest" -Headers $headers -TimeoutSec 20
        if ($j.tag_name -and $j.published_at) {
            $pubUtc = ConvertTo-UtcIso $j.published_at
            $dtUtc = [DateTimeOffset]::Parse($pubUtc)
            $pubDate = $dtUtc.ToOffset([TimeSpan]::FromHours(8)).ToString('yyyy-MM-dd')
            $latest  = $j.tag_name
        } elseif ($j.tag_name) {
            $status = 'metadata_incomplete'
            $err = 'tag_name present but published_at missing'
        } else {
            $status = 'invalid_response'; $err = '200 but empty tag_name'
        }
    } catch {
        $code = $null
        try { if ($_.Exception.Response -and $_.Exception.Response.StatusCode) { $code = [int]$_.Exception.Response.StatusCode } } catch {}
        try {
            if ($_.Exception.Response -and $_.Exception.Response.Headers) {
                $rl = Get-ResponseHeaderValue $_.Exception.Response.Headers 'X-RateLimit-Remaining'
            }
        } catch { $rl = '' }
        if     ($code -eq 401)                    { $status = 'auth_error' }
        elseif ($code -eq 404)                    { $status = 'not_found' }
        elseif ($code -eq 429)                    { $status = 'rate_limited' }
        elseif ($code -eq 403)                    { $status = if ($rl -eq '0') { 'rate_limited' } else { 'forbidden' } }
        elseif ($code -and $code -ge 500)         { $status = 'server_error' }
        elseif ($code)                            { $status = 'http_error' }
        else                                      { $status = 'network_error' }
        $err = $_.Exception.Message
    }
    $out += [PSCustomObject]@{
        repo = $it.repo; name = $it.name
        prevGitVer = $it.prevGitVer; prevGitDate = $it.prevGitDate
        localVer = $it.localVer; prevFlag = $it.prevFlag
        queryStatus = $status; latest = $latest
        published = $pubDate; publishedUtc = $pubUtc
        rateRemaining = $rl; error = $err
    }
}

# 姣旇緝 + 缈昏浆妫€娴?+ 鐘舵€佹満鍚堟祦锛坬ueryStatus != ok 榛樿淇濈暀锛沶ot_found 涓哄敮涓€鏁版嵁瀛楁鐗逛緥锛?
$final=@();foreach($o in $out){$newGitVer=$o.prevGitVer;$newGitDate=$o.prevGitDate;$newFlag=$o.prevFlag;$isNew=$false;$isFlip=$false;$review=$false;$cmp='';$versionJump=$false;$dateSuspicious=$false;$reasons=@();if($o.queryStatus -eq 'ok' -and $o.latest){$isNew=($o.latest -ne $o.prevGitVer);if($isNew){$newGitVer=$o.latest;$newGitDate=$o.published;$oldV=ConvertTo-NormVer $o.prevGitVer;$newV=ConvertTo-NormVer $o.latest;if($null-ne $oldV -and $null-ne $newV){if(($newV.Major-$oldV.Major)-ge 2 -or (($newV.Major-eq $oldV.Major)-and (($newV.Minor-$oldV.Minor)-ge 10))-or (($newV.Major-eq $oldV.Major)-and ($newV.Minor-eq $oldV.Minor)-and (($newV.Patch-$oldV.Patch)-ge 50))){$versionJump=$true;$reasons+='version_jump'}};if($o.publishedUtc-and $o.prevGitDate-match '^\d{4}-\d{2}-\d{2}$'){$newDate=([DateTimeOffset]::Parse($o.publishedUtc)).ToOffset([TimeSpan]::FromHours(8)).Date;$oldDate=[DateTime]::ParseExact($o.prevGitDate,'yyyy-MM-dd',$null).Date;if($newDate-lt $oldDate){$dateSuspicious=$true;$reasons+='date_suspicious'}}};if($o.localVer-match '鏈畨瑁?){$newFlag='no'}else{$cmp=Compare-Ver $o.localVer $o.latest;switch($cmp){'lt'{$newFlag='yes'};'eq'{$newFlag='no'};default{$newFlag=$o.prevFlag;$review=$true;$reasons+='incomparable_version'}}};if($o.prevFlag-ceq 'no'-and $newFlag-ceq 'yes'){$isFlip=$true};if($versionJump-or $dateSuspicious){$review=$true}}elseif($o.queryStatus-eq 'not_found'){$newGitVer='';$newGitDate='';$newFlag=$o.prevFlag;$review=$true;$reasons+='not_found'}else{$review=$true;$reasons+='api_failure'};$final += [PSCustomObject]@{repo=$o.repo;name=$o.name;gitVer=$newGitVer;gitDate=$newGitDate;localVer=$o.localVer;flag=$newFlag;prevFlag=$o.prevFlag;latest=$o.latest;publishedUtc=$o.publishedUtc;status=$o.queryStatus;cmp=$cmp;isNew=$isNew;isFlip=$isFlip;versionJump=$versionJump;dateSuspicious=$dateSuspicious;review=$review;reviewReasons=@($reasons);error=$o.error}}

# 缁熻 + 钀界洏 + JSON 鏈哄櫒鎺ュ彛杈撳嚭
$stats = [PSCustomObject]@{
    total         = $final.Count
    apiOk         = @($final | Where-Object status -eq 'ok').Count
    apiErr        = @($final | Where-Object status -ne 'ok').Count
    synced        = @($final | Where-Object { $_.status -eq 'ok' -and ($_.localVer -notmatch '鏈畨瑁?) -and $_.cmp -eq 'eq' }).Count
    yes           = @($final | Where-Object { $_.flag -ceq 'yes' }).Count
    uninstalled   = @($final | Where-Object { $_.localVer -match '鏈畨瑁? }).Count
    pendingReview = @($final | Where-Object { $_.review -eq $true }).Count
    newReleases   = @($final | Where-Object { $_.isNew -eq $true }).Count
    flips         = @($final | Where-Object { $_.isFlip -eq $true }).Count
    token         = if ($env:GITHUB_TOKEN) { 'set' } else { 'unset' }
}
$runAtUtc=[DateTimeOffset]::UtcNow.ToString('o')
$resultPath=Join-Path $monitorDir 'result.json'
$tmpResult=Join-Path $monitorDir 'result.fetch.tmp'
$doc=[PSCustomObject]@{runAt=$runAtUtc;stats=$stats;items=$final;review=[PSCustomObject]@{performed=$false;items=@()}}
$doc|ConvertTo-Json -Depth 8|Set-Content -Path $tmpResult -Encoding UTF8
try{$check=Get-Content $tmpResult -Raw|ConvertFrom-Json}catch{$check=$null}
if($null -eq $check -or $null -eq $check.stats -or $null -eq $check.items -or $null -eq $check.review -or @($check.items).Count -ne @($final).Count){
    Remove-Item $tmpResult -Force -ErrorAction SilentlyContinue
    Write-Output 'RUNTIME_ERROR|result.fetch.tmp JSON 缁撴瀯鏍￠獙澶辫触锛屾湭鏇挎崲 result.json銆?
    Release-LockSafely
    return
}
try{Move-Item -Path $tmpResult -Destination $resultPath -Force}catch{
    Remove-Item $tmpResult -Force -ErrorAction SilentlyContinue
    Write-Output ('RUNTIME_ERROR|result.json 鍘熷瓙鏇挎崲澶辫触锛歿0}'-f $_.Exception.Message)
    Release-LockSafely
    return
}
$runAtDisplay = [DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromHours(8)).ToString('yyyy-MM-dd HH:mm:ss')
Add-Content -Path (Join-Path $monitorDir 'fetch_run.log') -Encoding UTF8 -Value (
    '[{0}] items={1} apiOK={2} apiErr={3} yes={4} uninstalled={5} pendingReview={6} newReleases={7} flips={8} token={9}锛涚粨鏋滃啓鍏?result.json锛涙棤 HTML 鍥為€€锛孉PI 澶辫触椤逛繚鐣欎笂杞姸鎬併€? -f
    $runAtDisplay, $stats.total, $stats.apiOk, $stats.apiErr,
    $stats.yes, $stats.uninstalled, $stats.pendingReview, $stats.newReleases, $stats.flips, $stats.token)
Write-Output ("FETCH_COMPLETE|apiOk={0} apiErr={1} total={2}" -f $stats.apiOk, $stats.apiErr, $stats.total)
Write-Output ("SUMMARY|total={0} apiOK={1} apiErr={2} synced={3} yes={4} uninstalled={5} pendingReview={6} newReleases={7} flips={8} token={9}" -f
    $stats.total, $stats.apiOk, $stats.apiErr, $stats.synced, $stats.yes, $stats.uninstalled, $stats.pendingReview, $stats.newReleases, $stats.flips, $stats.token)
[PSCustomObject]@{ stats = $stats; items = $final } | ConvertTo-Json -Depth 6

