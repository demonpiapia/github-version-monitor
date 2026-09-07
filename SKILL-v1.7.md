---
name: github-version-monitor
description: GitHub 项目版本监测（自动化版·纯 PowerShell）——读取 GitHub更新监测列表.md 的监测清单，PowerShell 直连 GitHub REST API（每仓库单次调用），由内联确定性状态机完成查询分类、版本比较、yes/no 判定、翻转检测与统计，事务式原子写回该 md 并生成推送摘要。无 Python、无子 agent 编排；API 失败项保留上轮状态，不伪装成功。
---

# GitHub 项目版本监测（自动化版·纯 PowerShell）

> 版本：v1.7

## 0. 受众与职责

本文件是 **execution agent 的操作规范 + 可直接执行的内联 PowerShell 实现**。

本文件回答：执行前检查什么、按什么顺序执行、什么条件进入什么状态、什么数据可以修改、什么数据禁止修改、失败后如何退出、如何产生机器可消费结果、如何安全提交状态文件。

本文件不承担：设计背景解释、历史事故复述、面向人类的鼓励语。设计理由与故障模式定义见 `readme.md`。

## 1. 术语表（canonical）

| 术语 | 定义 | 禁止的同义混用 |
|---|---|---|
| `GIT 最新正式 Release` | `GET /repos/{owner}/{repo}/releases/latest` 返回的正式 Release（非 prerelease、非 draft，按 `created_at` 排序） | 最新版本、GitHub 最新版、GIT 版本、最新 tag、Git 最新发布、最新正式版 |
| `GitHub REST API` | `api.github.com` 的 REST 端点，本技能使用 `GET /repos/{owner}/{repo}/releases/latest` 与 `GET /repos/{owner}/{repo}/releases?per_page=5` | GitHub 接口、GitHub API 接口、API 通道、latest 接口、官方接口 |
| `API 主事实源` | 版本、日期、yes/no 的唯一写回事实来源 | 第二事实源、备用数据源、fallback、回退源 |
| `HTML 诊断辅助源` | `https://github.com/{owner}/{repo}/releases` 页面，仅用于诊断，结论只进入备注并标 `review=true` | 第二事实源、备用数据源、fallback、回退源 |
| `API 失败` | `queryStatus != ok` | 异常、可疑、可能有问题 |
| `review=true` / `待核` | 需要辅助复核的项 | 待确认、可疑、异常项目、suspicious、warning |
| `未安装` | 本地版本列的取值；统计字段 `K = 未安装项数` | 待安装（仅当描述用户后续操作时可用） |
| `synced` | `queryStatus=ok` 且已安装且 `Compare-Ver` 结果为 `eq` | 没有更新、已同步（口语） |
| `本轮` | 当前执行轮次 | 当前轮 |
| `上轮状态` | 状态文件中上一轮写入的 `gitVer` / `gitDate` / `flag` | 旧数据、历史结果、旧值 |
| `保留上轮状态` | 不修改该监测项的 `gitVer`、`gitDate`、`flag` | 保留旧值 |

## 2. 执行上下文

- 每轮自动化线程新开，不沿用历史上下文。上一轮的全部状态只能从 `GitHub更新监测列表.md` 与 `.monitor/result.json` 恢复。
- 状态文件同时承担输入和输出角色。输入字段包括仓库链接、本地版本基线、上轮 yes/no；成功运行后仅由程序更新允许写回的字段。
- 全部逻辑内联在本文件，不另写脚本文件，不依赖外部 orchestrator。
- 不依赖 Python / Node.js 运行时。
- 不派遣子 agent 编排。
- 每仓库正常路径只调 1 次 `releases/latest`；异常复核每仓库最多追加 1 次 `releases?per_page=5`。
- 凭证只放 `.env` 或系统环境变量，不写入本文件、状态文件或 git。

## 3. 职责边界（invariant）

```text
PowerShell 负责：
  parse / API request / HTTP classification / queryStatus /
  version comparison / flag / isNew / isFlip / review trigger /
  stats / table rewrite / schema validation / atomic commit

Agent 负责：
  读取程序事实 / 执行允许的辅助复核 / 构造 review evidence /
  撰写 conclusion / update summary / notes / report

Agent 禁止计算：
  stats / flag / version ordering / isNew / isFlip / synced /
  API failure count / monitor total

Agent 禁止修改：
  items / stats / flag / gitVer / gitDate / localVer
```

`review` 是辅助证据，不得改变程序已判定的 `flag` / `items` / `stats`。

## 4. 核心约束

1. 版本信息必须来自 GitHub REST API。不得使用搜索引擎快照或二手信息。
2. 版本大小只能由内置 `Compare-Ver` 判定。agent 禁止自行比较版本字符串。`Compare-Ver` 是受限版本比较器（数值段比较 + prerelease < stable + 异通道/非支持格式 → `incomparable` 进 `review=true`），不是完整 SemVer parser。
3. 当 `queryStatus != ok` 时，不修改该监测项的 `gitVer`、`gitDate`、`flag`。不得用 HTML 诊断辅助源或重跑替代 API 事实。
4. `releases/latest` 语义为 GitHub 官方最新正式 Release，不等于版本号最高者。不得自行重排该语义。
5. 本地版本基线只读。程序永不修改本地版本列；疑似错误只标 `review=true`。
6. 不自行增删监测项。解析时还必须校验第 6 列为大小写严格的小写 `yes|no`、`#` 为整数、repo 不重复、`## 监测列表` 唯一存在且表头与固定 6 列 contract 一致；canonical flag/enum 的字符串比较不得依赖 PowerShell 默认大小写不敏感语义。
7. 整轮在运行锁内执行。md 只能经步骤 5 的"临时文件 → 结构校验 → 原子替换"通道写入。
8. `rate_limited` 项不得重试，不得进入步骤 4。

## 5. 数据来源与状态文件

- 状态文件：`GitHub更新监测列表.md`（本目录）。
- 解析由步骤 2 的 PowerShell 完成，逐行读取 `owner/repo`（第 2 列链接）、`gitVer`（第 3 列）、`gitDate`（第 4 列）、`localVer`（第 5 列）、上轮 `flag`（第 6 列，翻转检测的必要输入）。agent 不手动抄表。
- 若状态文件不存在：不创建空清单，输出 `STATE_MISSING|` 并终止。
- 本地版本基线只读。

## 6. 查询状态机

每仓库一次查询，结果进入以下状态之一。`queryStatus` 为 canonical enum，不得自行创造同义名称。

| queryStatus | 触发条件 | 处理 |
|---|---|---|
| `ok` | 200 且 `tag_name` 非空且 `published_at` 非空 | 刷新 `gitVer` / `gitDate`（有新 tag 时）、计算 `flag`、检测翻转 |
| `not_found` | 404（当前请求下资源不可见：可能仓库不存在 / 无可用 release / 当前身份无法访问） | `gitVer = ""`、`gitDate = ""`、`flag` 保留上轮状态、`review=true` |
| `rate_limited` | 429，或 403 且 `X-RateLimit-Remaining = 0` | 保留上轮状态、`review=true`、不重试、不进入步骤 4 |
| `server_error` | 5xx | 保留上轮状态、`review=true` |
| `network_error` | 超时 / DNS / TLS 等（无 HTTP 响应） | 保留上轮状态、`review=true` |
| `invalid_response` | 200 但 `tag_name` 为空 | 保留上轮状态、`review=true` |
| `metadata_incomplete` | 200 且 `tag_name` 有值但 `published_at` 缺失 | 保留上轮状态（`gitVer` / `gitDate` 均不覆盖）、`review=true` |
| `auth_error` | 401 | 保留上轮状态、`review=true` |
| `forbidden` | 403 且 `X-RateLimit-Remaining > 0` | 保留上轮状态、`review=true` |
| `http_error` | 其他明确 HTTP 状态码 | 保留上轮状态、`review=true` |

## 7. 时间规范

- 内部事实统一使用 UTC。
- 展示统一转换为 `UTC+08:00`。
- 禁止依赖运行环境本地时区。
- 日期内部事实为 `publishedUtc`（格式 `yyyy-MM-ddTHH:mm:ssZ`），本设计不变。
- 运行时刻（`runAt`、`lock.start`、`lock.beat`、backup timestamp、`fetch_run.log` timestamp）内部记录 UTC，展示时显式转换为 `UTC+08:00`。
- 统一转换表达式：`[DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromHours(8))`。

## 8. 执行步骤

### 步骤 1 · 状态检查 + 运行锁 + 备份

顺序：状态文件存在性检查（缺失 → `STATE_MISSING|`，不建锁、不留副作用）→ 原子争锁（`FileMode.CreateNew` 独占创建）→ 备份到 `.monitor/backups/`。

锁模型：原子创建 + heartbeat + PID 存活检查。运行期间不持有持续 OS 文件句柄锁。陈锁（heartbeat 超 30 分钟）只有在锁内 PID 确认死亡时才允许接管；任何不确定一律保守 `LOCKED|`。

```powershell
$ErrorActionPreference = 'Stop'
# $base 解析顺序：环境变量 → 脚本所在目录 → 本机默认
$base = if ($env:GITHUB_VERSION_MONITOR_BASE) { $env:GITHUB_VERSION_MONITOR_BASE }
        elseif ($PSScriptRoot) { $PSScriptRoot }
        else { 'D:\AI\Workspace\automatic\github-version-monitor' }
$md = Join-Path $base 'GitHub更新监测列表.md'
$monitorDir = Join-Path $base '.monitor'

# 状态文件存在性检查先于 lock：STATE_MISSING 不得留下锁副作用
if (-not (Test-Path $md)) {
    Write-Output 'STATE_MISSING|状态文件 GitHub更新监测列表.md 不存在；不创建空清单。需提供初始清单（releases 链接 + 本地版本）后重跑。'
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
```

输出含 `LOCKED|` 时，本轮到此为止，不做任何其他动作。

### 步骤 2 · 解析 + 查询 + 状态机 + 比较 + 翻转 + 统计

先刷新锁 heartbeat，然后一段 PowerShell 完成：fail-closed 解析（数据行必须 exactly 6 列且第 2 列为合法 releases 链接，任何 schema 异常 → 整轮 `PARSE_ERROR|`，无静默 `continue` 路径）→ 每仓库 1 次 `releases/latest`（状态机分类；403 仅在 `X-RateLimit-Remaining = 0` 时判 `rate_limited`）→ 程序计算 `flag` / `isNew` / `isFlip` / `review` → 统计落盘 `.monitor/result.json`（含 `review` 占位）+ 追加 `fetch_run.log` → 输出 `FETCH_COMPLETE|` + `SUMMARY|` + JSON 机器接口。

```powershell
$ErrorActionPreference = 'Stop'
$base = if ($env:GITHUB_VERSION_MONITOR_BASE) { $env:GITHUB_VERSION_MONITOR_BASE }
        elseif ($PSScriptRoot) { $PSScriptRoot }
        else { 'D:\AI\Workspace\automatic\github-version-monitor' }
if (-not $env:GITHUB_TOKEN) { $envFile = Join-Path $base '.env'; if (Test-Path $envFile) { foreach ($line in (Get-Content $envFile)) { if ($line -match '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.+?)\s*$') { if (-not (Get-Content "env:$($Matches[1])" -ErrorAction SilentlyContinue)) { Set-Content -Path "env:$($Matches[1])" -Value $Matches[2] } } } } }
$md = Join-Path $base 'GitHub更新监测列表.md'
$monitorDir = Join-Path $base '.monitor'

# 锁 heartbeat：独占打开锁文件刷新 beat（被独占 = 异常并发 → LOCKED；文件消失 → RUNTIME_ERROR）
$lockPath = Join-Path $monitorDir 'run.lock'
if (-not (Test-Path $lockPath)) {
    Write-Output 'RUNTIME_ERROR|运行锁不存在（步骤1未执行或锁已丢失），本轮终止。'
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
    Write-Output 'LOCKED|运行锁被另一进程独占持有（异常并发），本轮退出。'
    return
} catch {
    Write-Output ("RUNTIME_ERROR|锁 heartbeat 刷新失败：{0}" -f $_.Exception.Message)
    return
}

$text = Get-Content $md -Raw

# 版本比较函数（唯一合法的版本大小判定，agent 不得代替）
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

# 解析（fail-closed：候选行解析失败 → 整轮终止，不静默跳过）
$sec = ($text -split '(?m)^## ') | Where-Object { $_ -match '^监测列表' }
$rows = ($sec -split "`n") | Where-Object { $_ -match '^\s*\|' }
$linkRe = [regex]'\[([^\]]+)\]\(https?://github\.com/([^/]+)/([^/]+)/releases\)'

$repos = @(); $parseErrors = @()
foreach ($r in $rows) {
    $t = $r.Trim()
    if (($t -replace '[|\s:\-]', '') -eq '') { continue }
    $c = ($t.Trim('|') -split '\|') | ForEach-Object { $_.Trim() }
    if ($c[1] -match '^项目名称$') { continue }
    if ($c.Count -ne 6) { $parseErrors += ("列数 {0}（应为 6）：{1}" -f $c.Count, $t); continue }
    if ($c[5] -cnotmatch '^(yes|no)$') { $parseErrors += ("第 6 列 flag 非法（仅允许小写 yes/no）：{0}" -f $t); continue }
    $m = $linkRe.Match($c[1])
    if (-not $m.Success) { $parseErrors += ("第 2 列非合法 releases 链接：{0}" -f $t); continue }
    $repos += [PSCustomObject]@{
        repo        = '{0}/{1}' -f $m.Groups[2].Value, $m.Groups[3].Value
        name        = $m.Groups[1].Value
        prevGitVer  = $c[2]
        prevGitDate = $c[3]
        localVer    = $c[4]
        prevFlag    = $c[5]
    }
}
if ($parseErrors.Count -gt 0 -or $repos.Count -eq 0) {
    Write-Output 'PARSE_ERROR|以下监测行无法解析 owner/repo（或清单为空），本轮终止、不写回主 md（备份已保留）：'
    $parseErrors | ForEach-Object { Write-Output "  问题行：$_" }
    Remove-Item (Join-Path $monitorDir 'run.lock') -Force -ErrorAction SilentlyContinue
    return
}

# API 查询（每仓库 1 次 latest；状态机分类；时间内部 UTC）
$token = $env:GITHUB_TOKEN
function Get-ResponseHeaderValue {
    param($Headers, [string]$Name)
    try {
        $v = $Headers[$Name]
        if ($null -ne $v -and [string]$v -ne '') { return [string]$v }
    } catch {}
    try {
        $values = $null
        if ($Headers.TryGetValues($Name, [ref]$values)) {
            $first = $values | Select-Object -First 1
            if ($null -ne $first) { return [string]$first }
        }
    } catch {}
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
            $dtUtc   = $j.published_at.ToUniversalTime()
            $pubUtc  = $dtUtc.ToString('yyyy-MM-ddTHH:mm:ssZ')
            $pubDate = $dtUtc.AddHours(8).ToString('yyyy-MM-dd')
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

# 比较 + 翻转检测 + 状态机合流（queryStatus != ok 一律保留上轮状态）
$final = @()
foreach ($o in $out) {
    $newGitVer = $o.prevGitVer; $newGitDate = $o.prevGitDate; $newFlag = $o.prevFlag
    $isNew = $false; $isFlip = $false; $review = $false; $cmp = ''
    if ($o.queryStatus -eq 'ok' -and $o.latest) {
        if ($o.latest -ne $o.prevGitVer) { $newGitVer = $o.latest; $newGitDate = $o.published; $isNew = $true }
        if ($o.localVer -match '未安装') { $newFlag = 'no' }
        else {
            $cmp = Compare-Ver $o.localVer $o.latest
            switch ($cmp) {
                'lt'      { $newFlag = 'yes' }
                'eq'      { $newFlag = 'no' }
                default   { $newFlag = $o.prevFlag; $review = $true }
            }
        }
        if ($o.prevFlag -eq 'no' -and $newFlag -eq 'yes') { $isFlip = $true }
    }
    elseif ($o.queryStatus -eq 'not_found') {
        # 404 仅表示当前请求下资源不可见；数据字段只保存该字段语义允许的数据
        $newGitVer = ''; $newGitDate = ''; $newFlag = $o.prevFlag
        $review = $true
    }
    else { $review = $true }
    $final += [PSCustomObject]@{
        repo = $o.repo; name = $o.name
        gitVer = $newGitVer; gitDate = $newGitDate
        localVer = $o.localVer; flag = $newFlag; prevFlag = $o.prevFlag
        latest = $o.latest; publishedUtc = $o.publishedUtc
        status = $o.queryStatus; cmp = $cmp
        isNew = $isNew; isFlip = $isFlip; review = $review
        error = $o.error
    }
}

# 统计 + 落盘 + JSON 机器接口输出
$stats = [PSCustomObject]@{
    total         = $final.Count
    apiOk         = @($final | Where-Object status -eq 'ok').Count
    apiErr        = @($final | Where-Object status -ne 'ok').Count
    synced        = @($final | Where-Object { $_.status -eq 'ok' -and ($_.localVer -notmatch '未安装') -and $_.cmp -eq 'eq' }).Count
    yes           = @($final | Where-Object { $_.flag -ceq 'yes' }).Count
    uninstalled   = @($final | Where-Object localVer -match '未安装').Count
    pendingReview = @($final | Where-Object review -eq $true).Count
    newReleases   = @($final | Where-Object isNew -eq $true).Count
    flips         = @($final | Where-Object isFlip -eq $true).Count
    token         = if ($env:GITHUB_TOKEN) { 'set' } else { 'unset' }
}
$runAtUtc = [DateTimeOffset]::UtcNow.ToString('o')
[PSCustomObject]@{
    runAt  = $runAtUtc; stats = $stats; items = $final
    review = [PSCustomObject]@{ performed = $false; items = @() }
} | ConvertTo-Json -Depth 6 | Set-Content -Path (Join-Path $monitorDir 'result.json') -Encoding UTF8
$runAtDisplay = [DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromHours(8)).ToString('yyyy-MM-dd HH:mm:ss')
Add-Content -Path (Join-Path $monitorDir 'fetch_run.log') -Encoding UTF8 -Value (
    '[{0}] items={1} apiOK={2} apiErr={3} yes={4} uninstalled={5} pendingReview={6} newReleases={7} flips={8} token={9}；结果写入 result.json；无 HTML 回退，API 失败项保留上轮状态。' -f
    $runAtDisplay, $stats.total, $stats.apiOk, $stats.apiErr,
    $stats.yes, $stats.uninstalled, $stats.pendingReview, $stats.newReleases, $stats.flips, $stats.token)
Write-Output ("FETCH_COMPLETE|apiOk={0} apiErr={1} total={2}" -f $stats.apiOk, $stats.apiErr, $stats.total)
Write-Output ("SUMMARY|total={0} apiOK={1} apiErr={2} synced={3} yes={4} uninstalled={5} pendingReview={6} newReleases={7} flips={8} token={9}" -f
    $stats.total, $stats.apiOk, $stats.apiErr, $stats.synced, $stats.yes, $stats.uninstalled, $stats.pendingReview, $stats.newReleases, $stats.flips, $stats.token)
[PSCustomObject]@{ stats = $stats; items = $final } | ConvertTo-Json -Depth 6
```

- 输出 `PARSE_ERROR|` → 本轮终止，把问题行原样回报，不写回主 md（锁已释放）。
- 输出 `FETCH_COMPLETE|` + `SUMMARY|…` + JSON → `result.json` 是程序事实 + 结构化辅助复核证据的唯一机器审计载体：`items` / `stats` 为只读程序事实；`review` 字段初始为未执行，由步骤 4 结构化写回（仅附加证据，不得反向修改程序事实）。
- `auth_error` / `forbidden` 同样保留上轮状态并如实回报。`token=unset` 且出现 `rate_limited` 时提示配置 `$env:GITHUB_TOKEN`（60 → 5000/h）。

### 步骤 3 · 事后清理（三天前备份只移不删）

```powershell
$base = if ($env:GITHUB_VERSION_MONITOR_BASE) { $env:GITHUB_VERSION_MONITOR_BASE }
        elseif ($PSScriptRoot) { $PSScriptRoot }
        else { 'D:\AI\Workspace\automatic\github-version-monitor' }
$monitorDir = Join-Path $base '.monitor'
# 锁 heartbeat（保活，防长轮被误判陈锁）
$lockPath = Join-Path $monitorDir 'run.lock'
if (Test-Path $lockPath) {
    try {
        $fs = [System.IO.File]::Open($lockPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
        $fs.Close()
        (Get-Item $lockPath).LastWriteTime = Get-Date
    } catch [System.IO.IOException] { Write-Output 'LOCKED|运行锁被另一进程独占持有（异常并发），本轮退出。'; return }
}
$backupDir = Join-Path $base '.monitor\backups'
$trashDir  = Join-Path $base '.monitor\trash'
New-Item -ItemType Directory -Force -Path $trashDir | Out-Null
Get-ChildItem $backupDir -Filter 'GitHub更新监测列表.backup.*.md' |
  Sort-Object Name -Descending | Select-Object -Skip 1 |
  Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-3) } |
  ForEach-Object { Move-Item $_.FullName (Join-Path $trashDir $_.Name) -Force }
```

### 步骤 4 · 异常复核（辅助证据通道，仅待核项·预算封顶）

复核使用的证据通道共三类：

1. 通道①（API 主事实源）：`releases/latest` 主查询——步骤 2 已完成，产生程序事实；
2. 通道②（列表接口）：`/repos/{owner}/{repo}/releases?per_page=5` 查看 `prerelease` / `draft`——每异常仓库最多追加这 1 次调用；
3. 通道③（HTML 诊断辅助源）：`Invoke-WebRequest "https://github.com/{owner}/{repo}/releases"`——仅作诊断，结论只进入备注并标 `review=true`，永不回写 `gitVer` / `gitDate` / `flag`。

触发条件：步骤 2 JSON 中 `review=true` 的项，或 `isNew=true` 且满足版本跳号 / 日期存疑条件的项。

规则：

- `rate_limited` 项不得进入复核，不得重试。
- 复核不改动程序已判定的 `flag`（`result.json` 的 `items` / `stats` 禁改）。
- 复核证据必须结构化写回 `result.json` 的 `review` 字段。
- 写回必须原子：生成临时 `result.review.tmp` → JSON 结构校验 → `stats` / `items` 完整性校验 → 原子替换 `result.json`。
- 写回失败时输出 `REVIEW_WRITE_ERROR|`，不执行步骤 5，不替换主 md，保留 backup，释放 `run.lock`，整轮判定 `failed`。

```powershell
$monitorDir = Join-Path $base '.monitor'
$resultPath = Join-Path $monitorDir 'result.json'
$tmpPath = Join-Path $monitorDir 'result.review.tmp'
# 程序事实字段只读；agent 不得修改 items/stats/flag/gitVer/gitDate/localVer
$doc = Get-Content $resultPath -Raw | ConvertFrom-Json
$origStatsJson = $doc.stats | ConvertTo-Json -Depth 6 -Compress
$origItemsJson = $doc.items  | ConvertTo-Json -Depth 6 -Compress
$doc.review = [PSCustomObject]@{
    performed = $true
    items     = @(
        # 每个复核项一条；sources 取 'releases_api' / 'html' 的实际组合；conclusion 取 pending/confirmed/cleared
        [PSCustomObject]@{ repo = 'owner/repo'; sources = @('releases_api','html'); finding = '复核发现（一句话事实）'; conclusion = 'pending' }
    )
}
# 校验 1：stats/items 与修改前完全一致
$newStatsJson = $doc.stats | ConvertTo-Json -Depth 6 -Compress
$newItemsJson = $doc.items  | ConvertTo-Json -Depth 6 -Compress
if ($newStatsJson -ne $origStatsJson -or $newItemsJson -ne $origItemsJson) {
    Write-Output 'REVIEW_WRITE_ERROR|review 写回时检测到 stats/items 发生变化，已拒绝覆盖 result.json（程序事实只读）。不执行步骤 5。'
    Remove-Item $tmpPath -Force -ErrorAction SilentlyContinue
    Remove-Item (Join-Path $monitorDir 'run.lock') -Force -ErrorAction SilentlyContinue
    return
}
# 校验 2：写入临时文件 + JSON 结构校验 + 完整性校验
$doc | ConvertTo-Json -Depth 6 | Set-Content -Path $tmpPath -Encoding UTF8
$check = Get-Content $tmpPath -Raw
$recheck = $null
try { $recheck = $check | ConvertFrom-Json } catch {}
if ($null -eq $recheck -or $null -eq $recheck.stats -or $null -eq $recheck.items -or $null -eq $recheck.review) {
    Write-Output 'REVIEW_WRITE_ERROR|result.review.tmp JSON 结构校验未过，不替换 result.json。不执行步骤 5。'
    Remove-Item $tmpPath -Force -ErrorAction SilentlyContinue
    Remove-Item (Join-Path $monitorDir 'run.lock') -Force -ErrorAction SilentlyContinue
    return
}
if (($recheck.stats | ConvertTo-Json -Depth 6 -Compress) -ne $origStatsJson -or
    ($recheck.items | ConvertTo-Json -Depth 6 -Compress) -ne $origItemsJson) {
    Write-Output 'REVIEW_WRITE_ERROR|result.review.tmp 中 stats/items 与原始不一致，不替换 result.json。不执行步骤 5。'
    Remove-Item $tmpPath -Force -ErrorAction SilentlyContinue
    Remove-Item (Join-Path $monitorDir 'run.lock') -Force -ErrorAction SilentlyContinue
    return
}
Move-Item -Path $tmpPath -Destination $resultPath -Force
Write-Output 'REVIEW_WRITE_OK|review 证据已结构化写回 result.json.review；stats/items 保持不变。'
```

复核结论只影响 agent 撰写的「备注」段与汇报第三优先级。

### 步骤 5 · 原地更新 md（程序改写表格行 + 事务式原子提交）

agent 先基于步骤 2 JSON（及步骤 4 复核结论）撰写「结论 / 更新摘要 / 备注」三段自然语言，填入下方脚本的 `$conclusionText` / `$summaryText` / `$noteText` 三个变量。表格行、元信息行、三节正文、原子替换、释放锁全部由脚本完成。agent 不手工编辑表格行。

前置条件：步骤 4 未输出 `REVIEW_WRITE_ERROR|`。若步骤 4 输出 `REVIEW_WRITE_ERROR|`，本步骤不执行。

```powershell
$ErrorActionPreference = 'Stop'
$base = if ($env:GITHUB_VERSION_MONITOR_BASE) { $env:GITHUB_VERSION_MONITOR_BASE }
        elseif ($PSScriptRoot) { $PSScriptRoot }
        else { 'D:\AI\Workspace\automatic\github-version-monitor' }
$md = Join-Path $base 'GitHub更新监测列表.md'
$monitorDir = Join-Path $base '.monitor'
# 锁 heartbeat（保活）+ 锁存在性验证
$lockPath = Join-Path $monitorDir 'run.lock'
if (-not (Test-Path $lockPath)) { Write-Output 'RUNTIME_ERROR|运行锁不存在（步骤1未执行或锁已丢失），本轮终止。'; return }
try {
    $fs = [System.IO.File]::Open($lockPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
    $fs.Close()
    (Get-Item $lockPath).LastWriteTime = Get-Date
} catch [System.IO.IOException] { Write-Output 'LOCKED|运行锁被另一进程独占持有（异常并发），本轮退出。'; return }
$result = Get-Content (Join-Path $monitorDir 'result.json') -Raw | ConvertFrom-Json
$items = @($result.items); $stats = $result.stats

# 以下三段由 agent 按本轮 JSON 实测值撰写后替换（示例为占位）
$conclusionText = @"
（结论段：N 监测 / M 需更新(yes) / K 未安装 / E 项本轮 API 失败保留上轮状态，全部取 stats 实测值）
"@
$summaryText = @"
（更新摘要段：本轮新发布 isNew 项 + no→yes 翻转 isFlip 项，含 UTC 发布时间与北京时间；API 失败项如实列出）
"@
$noteText = @"
（备注段：版本格式特殊项 / review=true 待核项 / 三通道复核结论逐项说明）
"@

# 元信息行（如实标注 API 成败）
# 北京时间 = UTC+08:00，由 UTC 当前时间显式转换，不使用运行机器本地时区
$beijingNow = [DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromHours(8)).ToString('yyyy-MM-dd HH:mm')
$metaLine = ('> 最近核对时间：{0}（北京时间，本轮 {1} 项：latest API 成功 {2} / 失败 {3} / 待核 {4}；失败项保留上轮状态；数据来源 GitHub REST API 直连，无 HTML 回退）' -f
    $beijingNow, $stats.total, $stats.apiOk, $stats.apiErr, $stats.pendingReview)

# 表格行程序改写 + 三节正文替换
$lines = Get-Content $md
$outLines = New-Object System.Collections.Generic.List[string]
$skip = $false; $pending = $null
foreach ($ln in $lines) {
    if ($ln -match '^##\s*(?<t>.+)$') {
        if ($skip) { $outLines.Add(''); $outLines.AddRange(($pending -split "`r?`n")); $outLines.Add(''); $skip = $false; $pending = $null }
        $t = $Matches['t'].Trim()
        $outLines.Add($ln)
        switch ($t) {
            '结论'     { $skip = $true; $pending = $conclusionText }
            '更新摘要' { $skip = $true; $pending = $summaryText }
            '备注'     { $skip = $true; $pending = $noteText }
        }
        continue
    }
    if ($skip) { continue }
    if ($ln -match '^\s*\|' -and $ln -match '\]\(https?://github\.com/([^/]+)/([^/]+)/releases\)') {
        $repoKey = '{0}/{1}' -f $Matches[1], $Matches[2]
        $it = $items | Where-Object { $_.repo -eq $repoKey }
        if ($it) {
            $c = ($ln.Trim().Trim('|') -split '\|') | ForEach-Object { $_.Trim() }
            # 6 列：# | 名称链接 | GIT最新正式Release | GIT更新日期 | 本地版本 | yes/no
            $outLines.Add(('| {0} | {1} | {2} | {3} | {4} | {5} |' -f $c[0], $c[1], $it.gitVer, $it.gitDate, $c[4], $it.flag))
        } else { $outLines.Add($ln) }
        continue
    }
    if ($ln -match '最近核对时间') { $outLines.Add($metaLine); continue }
    $outLines.Add($ln)
}
if ($skip) { $outLines.Add(''); $outLines.AddRange(($pending -split "`r?`n")); $outLines.Add('') }
$newText = ($outLines -join "`r`n") + "`r`n"

# 事务式写入：临时文件 → 结构校验 → 原子替换
$tmp = "$md.tmp"
Set-Content -Path $tmp -Value $newText -Encoding UTF8 -NoNewline
$check = Get-Content $tmp -Raw
$rows2 = @(($check -split "`r?`n") | Where-Object { $_ -match '^\s*\|\s*\d+\s*\|' })
$badFlag = @($rows2 | Where-Object {
    $cells = @($_.Trim().Trim('|') -split '\|' | ForEach-Object { $_.Trim() })
    $cells.Count -ne 6 -or $cells[5] -cnotmatch '^(yes|no)$'
})
# 精确校验：行数相等 + repo 集合完全一致
$mdRepos = @($rows2 | ForEach-Object {
    if ($_ -match '\]\(https?://github\.com/([^/]+)/([^/]+)/releases\)') { '{0}/{1}' -f $Matches[1], $Matches[2] }
}) | Sort-Object
$jsonRepos = @($items | ForEach-Object { $_.repo }) | Sort-Object
$anchor
$header='| # | 项目名称 | GIT最新版本 | GIT更新日期 | 本地版本 | 是否更新 |'
$headerOk=($check -split "`r?`n"|Where-Object{$_.Trim() -ceq $header}).Count -eq 1
if ($rows2.Count -eq $items.Count -and $badFlag.Count -eq 0 -and $repoMatch -and $headerOk -and
    ($check -match '## 监测列表') -and ($check -match '## 结论') -and
    ($check -match '## 更新摘要') -and ($check -match '## 备注')) {
    Move-Item -Path $tmp -Destination $md -Force
    Write-Output "COMMIT_OK|已原子替换主 md（数据行 $($rows2.Count)，yes/no 校验通过，repo 集合一致）。"
} else {
    Remove-Item $tmp -Force -ErrorAction SilentlyContinue
    Write-Output ("VALIDATE_ERROR|临时文件结构校验未过（数据行 {0} vs 应有 {1}，非法 flag 行 {2}，repo 集合一致={3}），不替换主 md；主 md 与备份保持原状。" -f $rows2.Count, $items.Count, $badFlag.Count, $repoMatch)
}
# 释放锁前确认 ownership：锁内 PID 必须等于当前进程 PID
$lockReleased = $false
try {
    $lockRaw = Get-Content $lockPath -Raw -ErrorAction Stop
    $lockPid = if ($lockRaw -match 'pid=(\d+)') { [int]$Matches[1] } else { -1 }
    if ($lockPid -eq $PID) {
        Remove-Item $lockPath -Force -ErrorAction SilentlyContinue
        $lockReleased = $true
    }
} catch { $lockReleased = $false }
if (-not $lockReleased) {
    Write-Output 'RUNTIME_ERROR|释放锁前 ownership 校验失败（锁内 PID 与当前进程不一致或锁不可读），未删除锁文件。'
}
```

输出 `VALIDATE_ERROR|` 时不重试写回，如实回报，人工介入。

### 步骤 6 · 生成汇报与推送摘要

所有数字取步骤 2 JSON 的 `stats`（本轮实测值）。禁止编造、禁止自行统计。

#### (A) 运行结果报告模板（多优先级结构）

1. 开头客观还原：已按程序判定如实还原监测列表（yes/no 全部由 `Compare-Ver` 计算），已落盘复核无误；本地版本基线本轮未被自动修改；本轮 API 失败 E 项已保留上轮状态并如实标注。
2. 第一优先级：已安装且需更新（表格：`项目名 | 本地版本 | GIT 最新正式 Release | 跨越情况 | 发布日期`）。
3. 第二优先级：本轮新发现（`isNew=true` 项，含 UTC 发布时间与北京时间）与 no→yes 翻转（`isFlip=true` 项），均由程序判定。
4. 第三优先级：特别关注与提醒（`review=true` 待核项 + 客观异常信号）。
5. 第四优先级：完整状态汇总（监测总数 / `synced` / 需更新 / 未安装 / 本轮失败 + 各项名称）。
6. 小结：一句客观收尾。

#### (B) 微信推送摘要（框架推送用，精简）

```
GitHub 监测完成：监测 N 项，本轮 M 项需更新、K 项未安装、E 项 API 失败（保留上轮状态）。
需更新：<项目名> <本地版本>→<GIT 最新正式 Release>(<发布日期>)；…
未安装（GIT 已有最新正式 Release）：<项目名> <GIT 最新正式 Release>；…
完整清单见 GitHub更新监测列表.md
```

字段约束：`N` = 监测总数，`M` = `flag=yes` 项数，`K` = 本地版本「未安装」项数，`E` = 本轮 API 失败项数（`E=0` 时省略该句）；均取 `stats` 实测值。「需更新」行仅列 yes 项，格式 `项目名 本地版本→GIT 最新正式 Release(发布日期)`，多个 `；` 分隔，无则写「无」；「未安装」行列未安装且 GIT 已有正式版的项（只给 GIT 最新正式 Release）；发布日期取主 md「GIT更新日期」列简写 `MM-DD`（统一由内部唯一事实 `publishedUtc` 按 `UTC+08:00` 换算；"今日发布"判断同样以 `publishedUtc` 为准）；末尾固定指向 `GitHub更新监测列表.md`；只推变更摘要不刷屏。

## 9. 机器运行状态协议

本表是本轮结果的唯一判定接口。各 harness 据此判定，不依赖自然语言猜测。

| 标记 | 阶段 | 语义 | 本轮判定 |
|---|---|---|---|
| `STATE_MISSING\|` | 步骤 1 | 状态文件不存在 | blocked |
| `LOCKED\|` | 步骤 1~5 | 运行锁被持有，或陈锁判定不确定（保守不抢） | blocked |
| `PARSE_ERROR\|` | 步骤 2 | 状态文件行 schema 异常 | failed |
| `RUNTIME_ERROR\|` | 步骤 2/4/5 | 未预期运行错误（锁丢失 / heartbeat 失败 / 锁 ownership 校验失败） | failed |
| `FETCH_COMPLETE\|` | 步骤 2 | API 查询 + 状态机完成，`result.json` 落盘 | fetch 阶段成功（不代表整轮 success） |
| `REVIEW_WRITE_OK\|` | 步骤 4 | review 证据原子写回成功 | 辅助阶段成功 |
| `REVIEW_WRITE_ERROR\|` | 步骤 4 | review 写回失败（stats/items 变化 / JSON 结构校验未过 / 完整性校验未过） | failed（不执行步骤 5，不替换主 md，保留 backup，释放 `run.lock`） |
| `VALIDATE_ERROR\|` | 步骤 5 | 写回校验未过，主 md 未动 | failed |
| `COMMIT_OK\|` | 步骤 5 | 原子替换完成 | success |
| `BACKUP_OK\|` / `SUMMARY\|` | 步骤 1/2 | 备份完成 / 人类可读统计摘要（含 `synced`） | 辅助观察 |

整轮 success 的判定条件：

```text
FETCH_COMPLETE
+ REVIEW_WRITE_OK（仅当本轮触发 review 时）
+ COMMIT_OK
```

若本轮没有 review 项，允许跳过 `REVIEW_WRITE_OK`。

`FETCH_COMPLETE` 不得单独代表整轮 success。

锁释放路径：`PARSE_ERROR` / `REVIEW_WRITE_ERROR` / `VALIDATE_ERROR` 显式释放；步骤 5 释放前确认锁内 PID 等于当前进程 PID；未捕获异常可能导致锁滞留——heartbeat 随之停止，30 分钟后经"锁内 PID 死亡确认"由下一轮安全接管。

## 10. `.monitor` 运行态产物

`.monitor\` 下全部文件由本文件内联代码生成，无外部 orchestrator。

| 文件 | 生成步骤 | 用途 |
|---|---|---|
| `run.lock` | 步骤 1 创建；步骤 2~5 heartbeat；步骤 4/5 释放 | 运行锁（原子创建互斥；内容 `pid` / `start` / `beat`；heartbeat 超 30 分钟 + PID 死亡才可接管） |
| `backups\*.md` | 步骤 1 | 运行前备份（毫秒时间戳，UTC+08:00） |
| `trash\*.md` | 步骤 3 | 超 3 天旧备份（只移不删，可恢复） |
| `result.json` | 步骤 2（`items` / `stats` 只读程序事实 + `review` 占位）+ 步骤 4（`review` 证据原子写回） | 程序事实 + 结构化辅助复核证据的唯一机器审计载体 |
| `result.review.tmp` | 步骤 4 | review 写回临时文件，校验通过后原子替换 `result.json` |
| `fetch_run.log` | 步骤 2 | 运行日志（一行一轮，含 `apiOK` / `apiErr`，明确声明无 HTML 回退） |

## 11. 状态语义

- 表格第 6 列只允许 `yes` / `no`（小写）。`review=true` 与 API 失败不进表格列，进顶部元信息统计行 + 备注段。
- `yes` = 本地版本 < GIT 最新正式 Release（由 `Compare-Ver` 判定）；未安装恒 `no`（但 GIT 列照常刷新）。
- `K` = 未安装项数。
- 本地 > 最新 / 版本不可比较 → 保留上轮 `flag` + `review=true`，不自动改判。
- `synced` = 本轮 API 成功、已安装（非"未安装"）、`Compare-Ver` 结果为 `eq` 的项数。
- 时间唯一内部事实 = `publishedUtc`（UTC，格式 `yyyy-MM-ddTHH:mm:ssZ`）；主表日期、微信 `MM-DD`、"今日发布"判断、汇报中的北京时间，全部由 `publishedUtc` 按 `UTC+08:00` 换算；"今日发布"判断以 `UTC+08:00` 当日为基准，不使用运行机器本地日期。

## 12. 已知限制

1. `WebFetch` 不适合抓 GitHub REST API 的 JSON。使用 `Invoke-RestMethod` 直连。
2. 搜索引擎快照滞后。以 API 返回为准。
3. `releases/latest` 忽略 prerelease，且不等于版本号最高者（按 `created_at` 取最新正式 Release）。用户用 rc/prototype 时经异常复核通道查预发布；主表始终用 GIT 最新正式 Release 语义。
4. 版本号格式不统一。展示原样，比较只用 `Compare-Ver`。禁止字符串比较（`"1.2.10" < "1.2.9"` 为 true 是错的）、禁止 agent 心算版本大小。
5. 未认证 API 限速 60/h。配置 `$env:GITHUB_TOKEN`（5000/h）。不得靠反复重跑或 HTML 通道替代 API 事实。
6. 状态文件是输入也是输出。解析旧表拿基线（含上轮 yes/no），再原地写回，不清空不另存。
7. `Format-Table` 是人类展示格式，不是机器接口。一律用 `ConvertTo-Json` 输出结构化结果。
8. 解析失败静默 `continue` 会导致监测项无声消失。一律 fail-closed：候选行解析失败整轮终止、不写回、保留备份、回报问题行。
9. 在当前 PowerShell `Invoke-RestMethod` 运行环境中，`published_at` 实测会被反序列化为 `[System.DateTime]` 对象（不是字符串）。只能 `.ToString("yyyy-MM-dd")`，不得 `.Substring`。跨 harness / 等价实现不得预设其类型，应先实测确认；无论返回字符串还是 DateTime，都不得盲目使用 `.Substring`。
10. 运行锁采用原子创建 + heartbeat + PID 存活检查模型，不是持续持有的 OS 文件句柄锁。

## 13. 用户偏好（不变）

- 表格 6 列：`#` / 项目名称 / GIT最新版本 / GIT更新日期 / 本地版本 / 是否更新（链接内嵌，无独立地址列）。
- 表内不用粗体；是否更新 yes/no 小写。
- 监测项增减一律由用户指定，不自行增删；404 仓库照留（`not_found`：404 仅表示当前请求下资源不可见，可能仓库不存在 / 无可用 release / 当前身份无法访问；`gitVer` / `gitDate` 置空，`flag` 保留上轮状态，`review=true`，不表述为已确认事实）。
- 未安装项本地版本填"未安装"、是否更新 no；但 GIT 发新版本仍刷新 GIT 列。
- 原地更新（事务式原子替换），不另存副本。
- 本地版本基线只读：程序永不修改，疑似错误标 `review=true`。
- 微信只推变更摘要 + 需更新项，不推完整表格；`K` 口径为"未安装"。
- 汇报语气：数字与结论 zero 主观干扰，不夸大、不渲染、不掩盖失败项。

## 14. 自动化任务推送配置

创建/编辑自动化任务时，在 WorkBuddy 客户端开启「推送到微信小程序」或「推送到自动化企微通知 bot」，框架负责推送。本文件不写任何 key/token（含 `GITHUB_TOKEN`，凭证只放 `.env` / 系统环境变量；原 `AUTOMATION-PROMPT.md` 已归档至 `.backup\`）。

## 15. Changelog

- **v1.7（2026-09-07 PowerShell 5.1 HTTP header 兼容修复轮）**：①修复 T04 P1：`X-RateLimit-Remaining` 不再直接调用 `WebHeaderCollection.TryGetValues()`，改由 `Get-ResponseHeaderValue` 统一读取，兼容 Windows PowerShell 5.1 与 PowerShell 7+ ②只有真实读取到 `0` 才判 `rate_limited`，读取失败不猜测 ③新增 HTTP response header runtime compatibility invariant ④保留 v1.6 的大小写严格 flag 校验修复。

- **v1.4（2026-09-06 执行型文档规范化轮）**：①`REVIEW_WRITE_ERROR` 明确终止步骤 5（不替换主 md、保留 backup、释放 `run.lock`、整轮 failed）②review 写回改为原子写入（`result.review.tmp` → JSON 结构校验 → `stats`/`items` 完整性校验 → 原子替换）③所有运行时刻统一 UTC 内部事实 + `UTC+08:00` 展示（`runAt` / `lock.start` / `lock.beat` / backup timestamp / `fetch_run.log`）④`not_found` 不再把状态说明文本写入 `gitVer`（`gitVer=""`、`gitDate=""`、`flag` 保留上轮状态、`review=true`）⑤写回校验由 `-ge` 改为精确相等 + repo 集合一致性校验 ⑥释放锁前确认 ownership（锁内 PID 必须等于当前进程 PID）⑦新增术语表、职责边界 invariant、Documentation Conventions 对齐 ⑧全文去人格化改写。
- v1.3（2026-09-06 复核硬化轮）：404 语义、review 写回保护、北京时间显式 `UTC+08:00`、移除 PAT 实例日期、Agent 职责边界、DateTime 跨 harness 文档。
- v1.1（2026-09-01）：职责边界 / 失败保留上轮状态 / 原子锁 + heartbeat 等基础确立。
