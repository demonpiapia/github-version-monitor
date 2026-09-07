# T18-v18: 状态机合流逻辑（step2.ps1 L141-142）
# 逐字提取 ConvertTo-NormVer / Compare-Ver / 状态机合流 foreach 循环
# 构造 7 种 queryStatus 输入，验证 gitVer/gitDate/flag 保留行为
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot

$PSVersion = $PSVersionTable.PSVersion.ToString()
Write-Output "PS_VERSION|$PSVersion"

# 逐字提取 ConvertTo-NormVer (step2.ps1 L36-50)
function ConvertTo-NormVer {
    param([string]$v)
    if ([string]::IsNullOrWhiteSpace($v) -or $v -match '未安装|暂无') { return $null }
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

# 逐字提取 Compare-Ver (step2.ps1 L51-67)
function Compare-Ver {
    # 返回 'lt' | 'eq' | 'gt' | 'incomparable'（语义：$a 相对 $b）
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

# 逐字提取状态机合流逻辑 (step2.ps1 L141-142)
# 注意：整段是一行，逐字复制
function Invoke-StateMachineMerge {
    param([array]$out)
    $final=@();foreach($o in $out){$newGitVer=$o.prevGitVer;$newGitDate=$o.prevGitDate;$newFlag=$o.prevFlag;$isNew=$false;$isFlip=$false;$review=$false;$cmp='';$versionJump=$false;$dateSuspicious=$false;$reasons=@();if($o.queryStatus -eq 'ok' -and $o.latest){$isNew=($o.latest -ne $o.prevGitVer);if($isNew){$newGitVer=$o.latest;$newGitDate=$o.published;$oldV=ConvertTo-NormVer $o.prevGitVer;$newV=ConvertTo-NormVer $o.latest;if($null-ne $oldV -and $null-ne $newV){if(($newV.Major-$oldV.Major)-ge 2 -or (($newV.Major-eq $oldV.Major)-and (($newV.Minor-$oldV.Minor)-ge 10))-or (($newV.Major-eq $oldV.Major)-and ($newV.Minor-eq $oldV.Minor)-and (($newV.Patch-$oldV.Patch)-ge 50))){$versionJump=$true;$reasons+='version_jump'}};if($o.publishedUtc-and $o.prevGitDate-match '^\d{4}-\d{2}-\d{2}$'){$newDate=([DateTimeOffset]::Parse($o.publishedUtc)).ToOffset([TimeSpan]::FromHours(8)).Date;$oldDate=[DateTime]::ParseExact($o.prevGitDate,'yyyy-MM-dd',$null).Date;if($newDate-lt $oldDate){$dateSuspicious=$true;$reasons+='date_suspicious'}}};if($o.localVer-match '未安装'){$newFlag='no'}else{$cmp=Compare-Ver $o.localVer $o.latest;switch($cmp){'lt'{$newFlag='yes'};'eq'{$newFlag='no'};default{$newFlag=$o.prevFlag;$review=$true;$reasons+='incomparable_version'}}};if($o.prevFlag-ceq 'no'-and $newFlag-ceq 'yes'){$isFlip=$true};if($versionJump-or $dateSuspicious){$review=$true}}elseif($o.queryStatus-eq 'not_found'){$newGitVer='';$newGitDate='';$newFlag=$o.prevFlag;$review=$true;$reasons+='not_found'}else{$review=$true;$reasons+='api_failure'};$final += [PSCustomObject]@{repo=$o.repo;name=$o.name;gitVer=$newGitVer;gitDate=$newGitDate;localVer=$o.localVer;flag=$newFlag;prevFlag=$o.prevFlag;latest=$o.latest;publishedUtc=$o.publishedUtc;status=$o.queryStatus;cmp=$cmp;isNew=$isNew;isFlip=$isFlip;versionJump=$versionJump;dateSuspicious=$dateSuspicious;review=$review;reviewReasons=@($reasons);error=$o.error}}
    return $final
}

# 构造 7 种场景
$scenarios = @(
    @{
        Name = 'auth_error'
        ExpectedGitVer = 'v2.0.0'
        ExpectedGitDate = '2026-08-01'
        ExpectedFlag = 'yes'
        Out = [PSCustomObject]@{
            repo='test/repo'; name='Test'
            prevGitVer='v2.0.0'; prevGitDate='2026-08-01'
            localVer='v1.0.0'; prevFlag='yes'
            queryStatus='auth_error'; latest=''; published=''; publishedUtc=''
            rateRemaining=''; error='401 Unauthorized'
        }
    },
    @{
        Name = 'forbidden'
        ExpectedGitVer = 'v2.0.0'
        ExpectedGitDate = '2026-08-01'
        ExpectedFlag = 'yes'
        Out = [PSCustomObject]@{
            repo='test/repo'; name='Test'
            prevGitVer='v2.0.0'; prevGitDate='2026-08-01'
            localVer='v1.0.0'; prevFlag='yes'
            queryStatus='forbidden'; latest=''; published=''; publishedUtc=''
            rateRemaining='50'; error='403 Forbidden'
        }
    },
    @{
        Name = 'rate_limited'
        ExpectedGitVer = 'v2.0.0'
        ExpectedGitDate = '2026-08-01'
        ExpectedFlag = 'yes'
        Out = [PSCustomObject]@{
            repo='test/repo'; name='Test'
            prevGitVer='v2.0.0'; prevGitDate='2026-08-01'
            localVer='v1.0.0'; prevFlag='yes'
            queryStatus='rate_limited'; latest=''; published=''; publishedUtc=''
            rateRemaining='0'; error='403 rate limited'
        }
    },
    @{
        Name = 'server_error'
        ExpectedGitVer = 'v2.0.0'
        ExpectedGitDate = '2026-08-01'
        ExpectedFlag = 'yes'
        Out = [PSCustomObject]@{
            repo='test/repo'; name='Test'
            prevGitVer='v2.0.0'; prevGitDate='2026-08-01'
            localVer='v1.0.0'; prevFlag='yes'
            queryStatus='server_error'; latest=''; published=''; publishedUtc=''
            rateRemaining=''; error='500 Internal Server Error'
        }
    },
    @{
        Name = 'network_error'
        ExpectedGitVer = 'v2.0.0'
        ExpectedGitDate = '2026-08-01'
        ExpectedFlag = 'yes'
        Out = [PSCustomObject]@{
            repo='test/repo'; name='Test'
            prevGitVer='v2.0.0'; prevGitDate='2026-08-01'
            localVer='v1.0.0'; prevFlag='yes'
            queryStatus='network_error'; latest=''; published=''; publishedUtc=''
            rateRemaining=''; error='Connection refused'
        }
    },
    @{
        Name = 'http_error'
        ExpectedGitVer = 'v2.0.0'
        ExpectedGitDate = '2026-08-01'
        ExpectedFlag = 'yes'
        Out = [PSCustomObject]@{
            repo='test/repo'; name='Test'
            prevGitVer='v2.0.0'; prevGitDate='2026-08-01'
            localVer='v1.0.0'; prevFlag='yes'
            queryStatus='http_error'; latest=''; published=''; publishedUtc=''
            rateRemaining=''; error='400 Bad Request'
        }
    },
    @{
        Name = 'not_found'
        ExpectedGitVer = ''
        ExpectedGitDate = ''
        ExpectedFlag = 'yes'
        Out = [PSCustomObject]@{
            repo='test/repo'; name='Test'
            prevGitVer='v2.0.0'; prevGitDate='2026-08-01'
            localVer='v1.0.0'; prevFlag='yes'
            queryStatus='not_found'; latest=''; published=''; publishedUtc=''
            rateRemaining=''; error='404 Not Found'
        }
    }
)

$passCount = 0; $failCount = 0
foreach ($sc in $scenarios) {
    $out = @($sc.Out)
    $final = Invoke-StateMachineMerge $out
    $item = $final[0]
    $ok = ($item.gitVer -ceq $sc.ExpectedGitVer) -and ($item.gitDate -ceq $sc.ExpectedGitDate) -and ($item.flag -ceq $sc.ExpectedFlag)
    if ($ok) { $passCount++; $verdict = 'PASS' } else { $failCount++; $verdict = 'FAIL' }
    Write-Output ("SCENARIO|name={0}|verdict={1}|queryStatus={2}|gitVer=[{3}]|gitDate=[{4}]|flag=[{5}]|prevFlag=[{6}]|review={7}|reasons={8}" -f $sc.Name, $verdict, $item.status, $item.gitVer, $item.gitDate, $item.flag, $item.prevFlag, $item.review, ($item.reviewReasons -join ','))
}
Write-Output "SUMMARY|pass=$passCount|fail=$failCount"
