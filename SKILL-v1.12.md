---
name: github-version-monitor
description: GitHub 项目版本监测（自动化版·纯 PowerShell）——读取 GitHub更新监测列表.md 的监测清单，PowerShell 直连 GitHub REST API（每仓库单次调用），由内联确定性状态机完成查询分类、版本比较、yes/no 判定、翻转检测与统计，事务式原子写回该 md 并生成推送摘要。无 Python、无子 agent 编排；API 失败项保留上轮状态，不伪装成功。
---

# GitHub 项目版本监测（自动化版·纯 PowerShell）

> 版本：v1.12
> 生产执行基准：PowerShell 7.x ONLY。禁止使用 Windows PowerShell 5.1。

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

- 每轮自动化线程新开，不沿用历史上下文。上一轮的全部状态只能从 `.output/GitHub更新监测列表.md` 与 `.monitor/result.json` 恢复。
- 状态文件同时承担输入和输出角色。输入字段包括仓库链接、本地版本基线、上轮 yes/no；成功运行后仅由程序更新允许写回的字段。
- 全部逻辑内联在本文件，不另写脚本文件，不依赖外部 orchestrator。
- 不依赖 Python / Node.js 运行时。
- 不派遣子 agent 编排。
- 每仓库正常路径只调 1 次 `releases/latest`；待核仓库除 `rate_limited` 外最多追加 1 次 `releases?per_page=5` 与 1 次 HTML 诊断请求。
- 凭证只放 `.env` 或系统环境变量，不写入本文件、状态文件或 git。
- 生产执行必须使用 `pwsh.exe`（非 `powershell.exe`）。
- 生产执行必须显式指定以下绝对路径：
  - Repository: `D:\AI\Workspace\automatic\github-version-monitor`
  - Skill: `D:\AI\Workspace\automatic\github-version-monitor\SKILL-v1.12.md`
- Agent 不得根据当前 cwd、编辑器状态或默认 shell 推断路径。
- 五个步骤代码块必须在同一 pwsh 7 会话中顺序执行。

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
3. 当 `queryStatus != ok` 时，默认保留该监测项的 `gitVer`、`gitDate`、`flag`；唯一例外是 `not_found`，其专门语义为 `gitVer=""`、`gitDate=""`、`flag` 保留上轮状态。不得用 HTML 诊断辅助源或重跑替代 API 事实。
4. `releases/latest` 语义为 GitHub 官方最新正式 Release，不等于版本号最高者。不得自行重排该语义。
5. 本地版本基线只读。程序永不修改本地版本列；疑似错误只标 `review=true`。
6. 不自行增删监测项。解析时还必须校验第 6 列为大小写严格的小写 `yes|no`、`#` 为整数、repo 不重复、`## 监测列表` 唯一存在且表头与固定 6 列 contract 一致；canonical flag/enum 的字符串比较不得依赖 PowerShell 默认大小写不敏感语义。
7. 整轮在运行锁内执行。md 只能经步骤 5 的"临时文件 → 结构校验 → 原子替换"通道写入。
8. `rate_limited` 项不得重试，不得进入步骤 4。
9. `versionJump` / `dateSuspicious` 仅为程序化 review 触发器，不参与 `flag` 计算。
10. `result.json` 初次生成与 review 更新均必须经临时文件 + JSON 校验 + 原子替换。
11. `RUN_STATUS|...|` 是整轮最终终态；`COMMIT_OK|` 仅是中间成功信号。`RUN_STATUS|success|` 只能在 `$commitSucceeded = $true` 且 `$lockReleased = $true` 时输出。
12. canonical flag / enum 的比较必须使用大小写敏感语义，不得依赖 PowerShell 默认大小写不敏感比较。
13. 步骤 4 的不可恢复错误路径必须在清理/锁处理之后输出且仅输出一次 `RUN_STATUS|failed|`，不得以裸 `return` 作为最终状态。

## 5. 数据来源与状态文件

- 状态文件：`.output/GitHub更新监测列表.md`。这是持久化状态文件：既是输入（仓库清单 + 本地版本基线 + 上轮 yes/no），也是输出（原地更新）。
- 解析由步骤 2 的 PowerShell 完成，逐行读取 `owner/repo`（第 2 列链接）、`gitVer`（第 3 列）、`gitDate`（第 4 列）、`localVer`（第 5 列）、上轮 `flag`（第 6 列，翻转检测的必要输入）。agent 不手动抄表。
- 若状态文件不存在：不创建空清单，输出 `STATE_MISSING|` 并终止。
- 本地版本基线只读。

### 5.1 状态文件 schema（contract）

`.output/GitHub更新监测列表.md` 必须满足以下 contract；任何异常均 `PARSE_ERROR|`，主 md 不写回：

- 必须恰好存在一个 `## 监测列表` 节。
- 节内必须存在固定表头：`# | 项目名称 | GIT最新版本 | GIT更新日期 | 本地版本 | 是否更新`。
- 每个数据行必须 exactly 6 列。
- 第 1 列必须为整数序号；第 2 列必须是 `[项目名](https://github.com/{owner}/{repo}/releases)` 形式的 releases 链接；第 6 列只允许大小写严格匹配的小写 `yes|no`。
- `owner/repo` 不得重复。
- 必须存在顶部“最近核对时间”行，以及 `## 结论` / `## 更新摘要` / `## 备注` / `## 核对方法` 四个写回锚点。
- 解析器不得静默跳过候选数据行。

### 5.2 `result.json` schema（contract）

```json
{
  "runAt":"UTC ISO 8601",
  "stats":{"total":0,"apiOk":0,"apiErr":0,"synced":0,"yes":0,"uninstalled":0,"pendingReview":0,"newReleases":0,"flips":0,"token":"set|unset"},
  "items":[{"repo":"owner/repo","name":"…","gitVer":"…","gitDate":"…","localVer":"…","flag":"yes|no","prevFlag":"yes|no","latest":"…","publishedUtc":"…","status":"queryStatus enum","cmp":"lt|eq|gt|incomparable|","isNew":false,"isFlip":false,"versionJump":false,"dateSuspicious":false,"review":false,"reviewReasons":[],"error":"…"}],
  "review":{"performed":false,"items":[]}
}
```

### 5.3 程序化 review 触发器（contract）

- `queryStatus != ok` → `review=true`，但 `rate_limited` 不进入复核请求。
- `cmp=incomparable` → `review=true`，原因 `incomparable_version`。
- `not_found` → `review=true`，原因 `not_found`。
- `isNew=true` 且 `versionJump=true` 或 `dateSuspicious=true` → `review=true`。
- `versionJump`：major 差 ≥2，或同 major minor 差 ≥10，或同 major/minor patch 差 ≥50。
- `dateSuspicious`：新 `publishedUtc` 对应北京时间日期早于上一轮 `gitDate`。

### 5.4 机器运行状态协议（contract）

`RUN_STATUS|success|` / `RUN_STATUS|failed|` 是整轮唯一最终终态；`COMMIT_OK|` 仅为中间信号。`COMMIT_OK|` 必须对应 `$commitSucceeded = $true`；只有主 md 原子替换成功且锁安全释放后才允许 `RUN_STATUS|success|`。

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
# PowerShell 7.x 强制检查
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Output ("RUNTIME_ERROR|PowerShell 7.x required, current: {0}" -f $PSVersionTable.PSVersion.ToString())
    return
}
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
$md = Join-Path (Join-Path $base '.output') 'GitHub更新监测列表.md'
$monitorDir = Join-Path $base '.monitor'

function Release-LockSafely { try { $raw=Get-Content $lockPath -Raw -ErrorAction Stop; if($raw -notmatch ('pid='+[regex]::Escape([string]$PID)+';')){return $false}; Remove-Item $lockPath -Force -ErrorAction Stop; return(-not(Test-Path $lockPath)) } catch { return $false } }

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

function ConvertTo-UtcIso {
    param($Value)
    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) { return '' }
    if ($Value -is [DateTimeOffset]) { return $Value.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ') }
    if ($Value -is [DateTime]) { return ([DateTimeOffset]$Value).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ') }
    return ([DateTimeOffset]::Parse([string]$Value)).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
}

# 解析（fail-closed：候选行解析失败 → 整轮终止，不静默跳过）
$sections=@($text -split '(?m)^## ');$monitorSections=@($sections|Where-Object{$_ -match '^监测列表(?:\r?\n|$)'});$parseErrors=@();$repos=@()
if($monitorSections.Count -ne 1){$parseErrors+=('`## 监测列表` 节数量应为 1，实际 {0}'-f $monitorSections.Count)}
if($monitorSections.Count -eq 1){$sec=$monitorSections[0];$rows=@($sec -split "`n"|Where-Object{$_-match '^\s*\|'});$headerCount=0;$dataRows=@();foreach($r in $rows){$t=$r.Trim();if(($t-replace '[|\s:\-]','')-eq ''){continue};$c=@($t.Trim('|')-split '\|'|ForEach-Object{$_.Trim()});if($c.Count -eq 6 -and (($c-join '|')-ceq '#|项目名称|GIT最新版本|GIT更新日期|本地版本|是否更新')){$headerCount++;continue};$dataRows+=,[PSCustomObject]@{Text=$t;Cells=$c}};if($headerCount-ne 1){$parseErrors+=('监测列表固定表头数量应为 1，实际 {0}'-f $headerCount)};if($text-notmatch '(?m)^>.*最近核对时间'){$parseErrors+='缺少顶部“最近核对时间”行'};foreach($anchor in @('结论','更新摘要','备注','核对方法')){if($text-notmatch ('(?m)^##\s*'+[regex]::Escape($anchor)+'\s*$')){$parseErrors+=('缺少写回锚点：## {0}'-f $anchor)}};$linkRe=[regex]'\[([^\]]+)\]\(https?://github\.com/([^/]+)/([^/]+)/releases\)';foreach($row in $dataRows){$t=$row.Text;$c=$row.Cells;if($c.Count-ne 6){$parseErrors+=('列数 {0}（应为 6）：{1}'-f $c.Count,$t);continue};if($c[0]-cnotmatch '^\d+$'){$parseErrors+=('第 1 列序号非法：{0}'-f $t);continue};$m=$linkRe.Match($c[1]);if(-not $m.Success){$parseErrors+=('第 2 列非合法 releases 链接：{0}'-f $t);continue};if($c[5]-cnotmatch '^(yes|no)$'){$parseErrors+=('第 6 列 flag 非法：{0}'-f $t);continue};$repoKey='{0}/{1}'-f $m.Groups[2].Value,$m.Groups[3].Value;if(@($repos|Where-Object{$_.repo-ceq $repoKey}).Count -gt 0){$parseErrors+=('repo 重复：{0}'-f $repoKey);continue};$repos+=[PSCustomObject]@{repo=$repoKey;name=$m.Groups[1].Value;prevGitVer=$c[2];prevGitDate=$c[3];localVer=$c[4];prevFlag=$c[5]}}}
if($parseErrors.Count -gt 0 -or $repos.Count -eq 0){Write-Output 'PARSE_ERROR|状态文件 schema 校验失败，本轮终止，不写回主 md。';$parseErrors|ForEach-Object{Write-Output "  问题：$_"};try{$rawLock=Get-Content $lockPath -Raw -ErrorAction Stop;if($rawLock-match('pid='+[regex]::Escape([string]$PID)+';')){Remove-Item $lockPath -Force -ErrorAction Stop}}catch{Write-Output 'RUNTIME_ERROR|PARSE_ERROR 后释放锁失败。'};return}

# API 查询（每仓库 1 次 latest；状态机分类；时间内部 UTC）
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

# 比较 + 翻转检测 + 状态机合流（queryStatus != ok 默认保留；not_found 为唯一数据字段特例）
$final=@();foreach($o in $out){$newGitVer=$o.prevGitVer;$newGitDate=$o.prevGitDate;$newFlag=$o.prevFlag;$isNew=$false;$isFlip=$false;$review=$false;$cmp='';$versionJump=$false;$dateSuspicious=$false;$reasons=@();if($o.queryStatus -eq 'ok' -and $o.latest){$isNew=($o.latest -ne $o.prevGitVer);if($isNew){$newGitVer=$o.latest;$newGitDate=$o.published;$oldV=ConvertTo-NormVer $o.prevGitVer;$newV=ConvertTo-NormVer $o.latest;if($null-ne $oldV -and $null-ne $newV){if(($newV.Major-$oldV.Major)-ge 2 -or (($newV.Major-eq $oldV.Major)-and (($newV.Minor-$oldV.Minor)-ge 10))-or (($newV.Major-eq $oldV.Major)-and ($newV.Minor-eq $oldV.Minor)-and (($newV.Patch-$oldV.Patch)-ge 50))){$versionJump=$true;$reasons+='version_jump'}};if($o.publishedUtc-and $o.prevGitDate-match '^\d{4}-\d{2}-\d{2}$'){$newDate=([DateTimeOffset]::Parse($o.publishedUtc)).ToOffset([TimeSpan]::FromHours(8)).Date;$oldDate=[DateTime]::ParseExact($o.prevGitDate,'yyyy-MM-dd',$null).Date;if($newDate-lt $oldDate){$dateSuspicious=$true;$reasons+='date_suspicious'}}};if($o.localVer-match '未安装'){$newFlag='no'}else{$cmp=Compare-Ver $o.localVer $o.latest;switch($cmp){'lt'{$newFlag='yes'};'eq'{$newFlag='no'};default{$newFlag=$o.prevFlag;$review=$true;$reasons+='incomparable_version'}}};if($o.prevFlag-ceq 'no'-and $newFlag-ceq 'yes'){$isFlip=$true};if($versionJump-or $dateSuspicious){$review=$true}}elseif($o.queryStatus-eq 'not_found'){$newGitVer='';$newGitDate='';$newFlag=$o.prevFlag;$review=$true;$reasons+='not_found'}else{$review=$true;$reasons+='api_failure'};$final += [PSCustomObject]@{repo=$o.repo;name=$o.name;gitVer=$newGitVer;gitDate=$newGitDate;localVer=$o.localVer;flag=$newFlag;prevFlag=$o.prevFlag;latest=$o.latest;publishedUtc=$o.publishedUtc;status=$o.queryStatus;cmp=$cmp;isNew=$isNew;isFlip=$isFlip;versionJump=$versionJump;dateSuspicious=$dateSuspicious;review=$review;reviewReasons=@($reasons);error=$o.error}}

# 统计 + 落盘 + JSON 机器接口输出
$stats = [PSCustomObject]@{
    total         = $final.Count
    apiOk         = @($final | Where-Object status -eq 'ok').Count
    apiErr        = @($final | Where-Object status -ne 'ok').Count
    synced        = @($final | Where-Object { $_.status -eq 'ok' -and ($_.localVer -notmatch '未安装') -and $_.cmp -eq 'eq' }).Count
    yes           = @($final | Where-Object { $_.flag -ceq 'yes' }).Count
    uninstalled   = @($final | Where-Object { $_.localVer -match '未安装' }).Count
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
    Write-Output 'RUNTIME_ERROR|result.fetch.tmp JSON 结构校验失败，未替换 result.json。'
    Release-LockSafely
    return
}
try{Move-Item -Path $tmpResult -Destination $resultPath -Force}catch{
    Remove-Item $tmpResult -Force -ErrorAction SilentlyContinue
    Write-Output ('RUNTIME_ERROR|result.json 原子替换失败：{0}'-f $_.Exception.Message)
    Release-LockSafely
    return
}
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
# housekeeping: backup/trash 清理 — 失败不阻断核心业务
try {
    New-Item -ItemType Directory -Force -Path $trashDir | Out-Null
    Get-ChildItem $backupDir -Filter 'GitHub更新监测列表.backup.*.md' |
      Sort-Object Name -Descending | Select-Object -Skip 1 |
      Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-3) } |
      ForEach-Object { Move-Item $_.FullName (Join-Path $trashDir $_.Name) -Force }
} catch {
    Write-Output ("HOUSEKEEPING_WARNING|backup/trash cleanup failed: {0}" -f $_.Exception.Message)
}
```

### 步骤 4 · 异常复核（辅助证据通道·程序化收集·预算封顶）

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
$ErrorActionPreference='Stop'
$base=if($env:GITHUB_VERSION_MONITOR_BASE){$env:GITHUB_VERSION_MONITOR_BASE}elseif($PSScriptRoot){$PSScriptRoot}else{'D:\AI\Workspace\automatic\github-version-monitor'}
$monitorDir=Join-Path $base '.monitor';$resultPath=Join-Path $monitorDir 'result.json';$tmpPath=Join-Path $monitorDir 'result.review.tmp';$lockPath=Join-Path $monitorDir 'run.lock'
function Release-LockSafely { try{$raw=Get-Content $lockPath -Raw -ErrorAction Stop;if($raw-notmatch('pid='+[regex]::Escape([string]$PID)+';')){return $false};Remove-Item $lockPath -Force -ErrorAction Stop;return(-not(Test-Path $lockPath))}catch{return $false} }
try{$raw=Get-Content $lockPath -Raw -ErrorAction Stop;if($raw-notmatch('pid='+[regex]::Escape([string]$PID)+';')){throw 'ownership mismatch'};$startTok=if($raw-match 'start=([^;\r\n]+)'){$Matches[1]}else{[DateTimeOffset]::UtcNow.ToString('o')};$fs=[IO.File]::Open($lockPath,[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None);try{$fs.SetLength(0);$b=[Text.Encoding]::UTF8.GetBytes(('pid={0};start={1};step=4;beat={2}'-f $PID,$startTok,[DateTimeOffset]::UtcNow.ToString('o')));$fs.Write($b,0,$b.Length)}finally{$fs.Close()}}catch{Write-Output ('RUNTIME_ERROR|步骤4 heartbeat 失败：{0}'-f $_.Exception.Message);Write-Output 'RUN_STATUS|failed|步骤4 heartbeat 失败，整轮终止。';return}
try { $doc=Get-Content $resultPath -Raw|ConvertFrom-Json } catch { Write-Output ('RUNTIME_ERROR|读取 result.json 失败：{0}'-f $_.Exception.Message); $released=Release-LockSafely; if (-not $released) { Write-Output 'RUNTIME_ERROR|读取 result.json 失败后锁释放失败，保留锁供陈锁机制接管。' }; Write-Output 'RUN_STATUS|failed|读取 result.json 失败，整轮终止。'; return };$origStats=$doc.stats|ConvertTo-Json -Depth 8 -Compress;$origItems=$doc.items|ConvertTo-Json -Depth 8 -Compress;$candidates=@($doc.items|Where-Object{$_.review-eq $true});$reviewItems=@();$headers=@{'User-Agent'='workbuddy-version-monitor';'Accept'='application/vnd.github+json';'X-GitHub-Api-Version'='2026-03-10'};if($env:GITHUB_TOKEN){$headers['Authorization']='Bearer '+$env:GITHUB_TOKEN}
foreach($it in $candidates){if($it.status-eq 'rate_limited'){$reviewItems+=[PSCustomObject]@{repo=$it.repo;sources=@('releases_latest');finding='主查询已限流；不重试、不追加复核请求。';conclusion='pending';reasons=@($it.reviewReasons);apiListStatus='skipped_rate_limited';apiList=@();htmlStatus='skipped_rate_limited';htmlTitle=''};continue};$apiList=@();$apiListStatus='error';$htmlStatus='error';$htmlTitle='';$parts=@();try{$apiList=@(Invoke-RestMethod -Uri "https://api.github.com/repos/$($it.repo)/releases?per_page=5" -Headers $headers -TimeoutSec 20)|ForEach-Object{$pub='';if($_.published_at){try{$pub=ConvertTo-UtcIso $_.published_at}catch{}};[PSCustomObject]@{tag_name=[string]$_.tag_name;published_at=$pub;prerelease=[bool]$_.prerelease;draft=[bool]$_.draft}};$apiListStatus='ok'}catch{$parts+='列表接口复核请求失败。'};if($apiListStatus-eq 'ok' -and $apiList.Count -gt 0){$parts+=('列表接口前{0}项：{1}'-f $apiList.Count,(($apiList|ForEach-Object{"$($_.tag_name)|pre=$($_.prerelease)|draft=$($_.draft)|published=$($_.published_at)"})-join '; '))}elseif($apiListStatus-eq 'ok'){$parts+='列表接口返回空集合。'};try{$html=Invoke-WebRequest -Uri "https://github.com/$($it.repo)/releases" -Headers @{'User-Agent'='workbuddy-version-monitor'} -TimeoutSec 20 -UseBasicParsing;$htmlStatus=[string]$html.StatusCode;$htmlTitle=[regex]::Match([string]$html.Content,'<title>\s*(?<t>.*?)\s*</title>','IgnoreCase').Groups['t'].Value;$parts+=('HTML 诊断 HTTP {0}；页面标题仅供诊断：{1}'-f $htmlStatus,$htmlTitle)}catch{$parts+='HTML 诊断请求失败。'};$reviewItems+=[PSCustomObject]@{repo=$it.repo;sources=@('releases_api','html');finding=($parts-join ' ');conclusion='pending';reasons=@($it.reviewReasons);apiListStatus=$apiListStatus;apiList=@($apiList);htmlStatus=$htmlStatus;htmlTitle=$htmlTitle}}
$doc.review=[PSCustomObject]@{performed=$true;items=@($reviewItems)};$newStats=$doc.stats|ConvertTo-Json -Depth 8 -Compress;$newItems=$doc.items|ConvertTo-Json -Depth 8 -Compress;if($newStats-ne $origStats-or $newItems-ne $origItems){Remove-Item $tmpPath -Force -ErrorAction SilentlyContinue;Write-Output 'REVIEW_WRITE_ERROR|review 修改了 stats/items，拒绝覆盖 result.json。';$released=Release-LockSafely;if(-not $released){Write-Output 'RUNTIME_ERROR|review stats/items 完整性失败后锁释放失败，保留锁供陈锁机制接管。'};Write-Output 'RUN_STATUS|failed|review 程序事实完整性校验失败，整轮终止。';return};try {
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
$md = Join-Path (Join-Path $base '.output') 'GitHub更新监测列表.md'
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
try {
    Set-Content -Path $tmp -Value $newText -Encoding UTF8 -NoNewline
    $check = Get-Content $tmp -Raw -ErrorAction Stop
} catch {
    Remove-Item $tmp -Force -ErrorAction SilentlyContinue
    Write-Output ('RUNTIME_ERROR|主 md 临时文件写入/读取失败：{0}' -f $_.Exception.Message)
    $lockReleased = $false
    try {
        $lockRaw = Get-Content $lockPath -Raw -ErrorAction Stop
        $lockPid = if ($lockRaw -match 'pid=(\d+)') { [int]$Matches[1] } else { -1 }
        if ($lockPid -eq $PID) {
            Remove-Item $lockPath -Force -ErrorAction Stop
            $lockReleased = -not (Test-Path $lockPath)
        }
    } catch { $lockReleased = $false }
    if (-not $lockReleased) { Write-Output 'RUNTIME_ERROR|主 md 临时文件失败后锁释放失败，保留锁供陈锁机制接管。' }
    Write-Output 'RUN_STATUS|failed|主 md 未提交。'
    return
}
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
$repoMatch=($mdRepos.Count -eq $jsonRepos.Count)-and(-not(Compare-Object $mdRepos $jsonRepos))
$anchorsOk=($check -match '## 监测列表')-and($check -match '## 结论')-and($check -match '## 更新摘要')-and($check -match '## 备注')-and($check -match '## 核对方法')
$commitSucceeded=$false
$header='| # | 项目名称 | GIT最新版本 | GIT更新日期 | 本地版本 | 是否更新 |'
$headerOk=($check -split "`r?`n"|Where-Object{$_.Trim() -ceq $header}).Count -eq 1
if ($rows2.Count -eq $items.Count -and $badFlag.Count -eq 0 -and $repoMatch -and $headerOk -and $anchorsOk) {
    try {
        Move-Item -Path $tmp -Destination $md -Force
        $commitSucceeded=$true
        Write-Output "COMMIT_OK|已原子替换主 md（数据行 $($rows2.Count)，yes/no 校验通过，repo 集合一致）。"
    } catch {
        Remove-Item $tmp -Force -ErrorAction SilentlyContinue
        Write-Output ('RUNTIME_ERROR|主 md 原子替换失败：{0}' -f $_.Exception.Message)
    }
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
    Write-Output 'RUN_STATUS|failed|主 md 提交状态不可否认，但运行锁未安全释放。'
} elseif ($commitSucceeded) {
    Write-Output 'RUN_STATUS|success|fetch + 必要 review + commit + lock release 完成。'
} else {
    Write-Output 'RUN_STATUS|failed|主 md 未提交。'
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
完整清单见 .output\GitHub更新监测列表.md
```

字段约束：`N` = 监测总数，`M` = `flag=yes` 项数，`K` = 本地版本「未安装」项数，`E` = 本轮 API 失败项数（`E=0` 时省略该句）；均取 `stats` 实测值。「需更新」行仅列 yes 项，格式 `项目名 本地版本→GIT 最新正式 Release(发布日期)`，多个 `；` 分隔，无则写「无」；「未安装」行列未安装且 GIT 已有正式版的项（只给 GIT 最新正式 Release）；发布日期取主 md「GIT更新日期」列简写 `MM-DD`（统一由内部唯一事实 `publishedUtc` 按 `UTC+08:00` 换算；"今日发布"判断同样以 `publishedUtc` 为准）；末尾固定指向 `.output/GitHub更新监测列表.md`；只推变更摘要不刷屏。

## 9. 机器运行状态协议

本表是本轮结果的唯一判定接口。各 harness 据此判定，不依赖自然语言猜测。

| 标记 | 阶段 | 语义 | 本轮判定 |
|---|---|---|---|
| `STATE_MISSING\|` | 步骤 1 | 状态文件不存在 | blocked |
| `LOCKED\|` | 步骤 1~5 | 运行锁被持有，或陈锁判定不确定（保守不抢） | blocked |
| `PARSE_ERROR\|` | 步骤 2 | 状态文件行 schema 异常 | failed |
| `RUNTIME_ERROR\|` | 步骤 1/2/4/5 | 未预期运行错误（锁丢失 / heartbeat 失败 / 锁 ownership 校验失败） | failed |
| `FETCH_COMPLETE\|` | 步骤 2 | API 查询 + 状态机完成，`result.json` 落盘 | fetch 阶段成功（不代表整轮 success） |
| `REVIEW_WRITE_OK\|` | 步骤 4 | review 证据原子写回成功 | 辅助阶段成功 |
| `REVIEW_WRITE_ERROR\|` | 步骤 4 | review 写回失败（stats/items 变化 / JSON 结构校验未过 / 完整性校验未过） | failed（不执行步骤 5，不替换主 md，保留 backup，释放 `run.lock`） |
| `VALIDATE_ERROR\|` | 步骤 5 | 写回校验未过，主 md 未动 | failed |
| `COMMIT_OK\|` | 步骤 5 | 主 md 原子替换完成 | 非终态；最终以 `RUN_STATUS` 为准 |
| `BACKUP_OK\|` / `SUMMARY\|` | 步骤 1/2 | 备份完成 / 人类可读统计摘要（含 `synced`） | 辅助观察 |
| `HOUSEKEEPING_WARNING\|` | 步骤 3 | backup/trash 清理失败（trash 目录创建 / backup 移动 / 权限不足等） | 辅助观察（不改变终态，核心流程继续） |

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
- `not_found`：404 仅表示当前请求下资源不可见；`gitVer=""`、`gitDate=""`、`flag` 保留上轮状态，`review=true`，原因 `not_found`。
- `versionJump` / `dateSuspicious` 仅作为 review 触发器，不改变 `flag`。
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
9. `published_at` 在不同 PowerShell / harness 中可能是 `DateTime`、`DateTimeOffset` 或字符串；统一通过 `ConvertTo-UtcIso` 归一化为 UTC，不依赖 `.Substring`。
10. 运行锁采用原子创建 + heartbeat + PID 存活检查模型，不是持续持有的 OS 文件句柄锁。

## 13. 用户偏好（不变）

- 表格 6 列：`#` / 项目名称 / GIT最新版本 / GIT更新日期 / 本地版本 / 是否更新（链接内嵌，无独立地址列）。
- 表内不用粗体；是否更新 yes/no 小写。
- 监测项增减一律由用户指定，不自行增删；404 仓库照留（`not_found`：404 仅表示当前请求下资源不可见，可能仓库不存在 / 无可用 release / 当前身份无法访问；`gitVer` / `gitDate` 置空，`flag` 保留上轮状态，`review=true`，不表述为已确认事实）。
- 未安装项本地版本填"未安装"、是否更新 no；但 GIT 发新版本仍刷新 GIT 列。
- `.output/GitHub更新监测列表.md` 原地更新（事务式原子替换），不另存副本。
- 本地版本基线只读：程序永不修改，疑似错误标 `review=true`。
- 微信只推变更摘要 + 需更新项，不推完整表格；`K` 口径为"未安装"。
- 汇报语气：数字与结论 zero 主观干扰，不夸大、不渲染、不掩盖失败项。

## 14. 自动化任务推送配置

创建/编辑自动化任务时，在 WorkBuddy 客户端开启「推送到微信小程序」或「推送到自动化企微通知 bot」，框架负责推送。本文件不写任何 key/token（含 `GITHUB_TOKEN`，凭证只放 `.env` / 系统环境变量；原 `AUTOMATION-PROMPT.md` 已归档至 `.backup\`）。

## 15. Changelog

- **v1.12（2026-09-10 最小修改与定向验证轮）**：①P1：强制 PowerShell 7.x ONLY，移除 PS5.1 兼容性声明，Step 1 代码块新增 PS7 版本检查，执行契约显式指定绝对路径与 pwsh.exe + 同会话顺序执行声明 ②P2：Step 3 backup/trash housekeeping 清理包裹独立 try/catch，失败时输出 HOUSEKEEPING_WARNING 并继续，不阻断核心业务流程；heartbeat 保持不变（lock ownership ≠ housekeeping）；§9 协议表新增 HOUSEKEEPING_WARNING 登记 ③P3：逐个审查 v1.11 审计识别的 6 条 fatal path（L254/L320/L406/L412/L444/L529），结论为均不需要修改（均有明确错误状态输出，§9 表已将其判定为 failed） ④§9 协议表 RUNTIME_ERROR 阶段列扩展为"步骤 1/2/4/5" ⑤不扩展 SemVer / 不增加 API 请求 / 不扩大 review / 不重新设计 lock / 完全忽略 PS5.1。
- **v1.11（2026-09-09 唯一失败终态回归修复轮）**：①修复 v1.10 T38-stats-items P1：Step 4 `stats/items` 程序事实完整性失败分支在输出 `RUN_STATUS|failed|` 后补齐 `return`，阻止落入后续 JSON 校验路径 ②确保该失败路径只输出一次 `RUN_STATUS|failed|`，满足 constraint #13 的唯一最终终态要求 ③其余 v1.10 行为与生产路径保持不变。
- **v1.10（2026-09-09 review 失败终态闭环修复轮）**：①修复 v1.9 T38：Step 4 `result.review.tmp` 写入失败、临时 JSON 校验失败、原子替换失败及其他不可恢复 review 错误均在清理与锁处理后明确输出 `RUN_STATUS|failed|`，不再以裸 `return` 作为终态 ②补齐步骤 4 `result.json` 读取失败与 heartbeat 失败的最终失败状态输出 ③新增 invariant：任何不可恢复提前终止路径都必须产生唯一 `RUN_STATUS|failed|` 终态；其余 v1.9 行为与生产路径保持不变。
- **v1.9（2026-09-08 运行时异常清理与锁释放修复轮）**：①修复 v1.8 T38：Step 4 `result.review.tmp` 写入失败现在进入受保护异常分支，清理临时文件并尝试释放运行锁，最终不进入 Step 5 ②修复 v1.8 T23：Step 5 主 md 临时文件写入/读取失败现在清理临时文件、释放运行锁并输出 `RUN_STATUS|failed|`；主 md 原子替换失败同样清理临时文件并进入统一 failed 终态 ③将异常路径的 `tmp` 清理、lock release、最终失败状态形成显式闭环 ④保留 v1.8 的 `$commitSucceeded`、`.output` 状态路径、PS7 生产基准与其他核心能力不变。
- **v1.8（2026-09-08 生产验证 P1 修复 + 状态路径同步轮）**：①修复 v1.7 T37/T43 暴露的 `$commitSucceeded` 状态遗漏：主 md 原子替换成功后立即置 `$commitSucceeded=$true`，确保正常提交可正确输出 `RUN_STATUS|success|` ②将 `COMMIT_OK|` 与 `$commitSucceeded=$true` 的对应关系、以及 `RUN_STATUS|success|` 必须同时满足 commit 与 lock release 成功写入 invariant ③将持久化状态文件路径统一为 `.output/GitHub更新监测列表.md`，并同步所有解析、写回、汇报引用 ④其余 v1.7 能力保持不变。
- **v1.7（2026-09-07 从仓库 v1.6 正确派生的生产兼容修复轮）**：①完整保留 v1.6 的 `versionJump` / `dateSuspicious` / `reviewReasons` / schema contract / `result.fetch.tmp` / `RUN_STATUS` / 404→`not_found` / lock ownership-safe 等能力 ②新增 `Get-ResponseHeaderValue`，兼容 Windows PowerShell 5.1 与 PowerShell 7+ header 类型 ③修复 T04：403 + `X-RateLimit-Remaining=0` 只有真实读取到 `0` 才判 `rate_limited` ④生产执行基准明确为 PowerShell 7.x，PS5.1 仅作兼容性验证。

- **v1.4（2026-09-06 执行型文档规范化轮）**：①`REVIEW_WRITE_ERROR` 明确终止步骤 5（不替换主 md、保留 backup、释放 `run.lock`、整轮 failed）②review 写回改为原子写入（`result.review.tmp` → JSON 结构校验 → `stats`/`items` 完整性校验 → 原子替换）③所有运行时刻统一 UTC 内部事实 + `UTC+08:00` 展示（`runAt` / `lock.start` / `lock.beat` / backup timestamp / `fetch_run.log`）④`not_found` 不再把状态说明文本写入 `gitVer`（`gitVer=""`、`gitDate=""`、`flag` 保留上轮状态、`review=true`）⑤写回校验由 `-ge` 改为精确相等 + repo 集合一致性校验 ⑥释放锁前确认 ownership（锁内 PID 必须等于当前进程 PID）⑦新增术语表、职责边界 invariant、Documentation Conventions 对齐 ⑧全文去人格化改写。
- v1.3（2026-09-06 复核硬化轮）：404 语义、review 写回保护、北京时间显式 `UTC+08:00`、移除 PAT 实例日期、Agent 职责边界、DateTime 跨 harness 文档。
- v1.1（2026-09-01）：职责边界 / 失败保留上轮状态 / 原子锁 + heartbeat 等基础确立。
