# github-version-monitor · README

本文件是 skill 的技术说明、部署说明、重建说明和约束说明。

`SKILL.md` 是 execution agent 每轮执行的操作规范与完整内联实现，是本 skill 的**唯一代码事实源**。本文件不重复维护大段 PowerShell 实现；凡与 `SKILL.md` 重复的长代码，一律改为指向 `SKILL.md` 对应章节。

---

## 0. 一句话定位

读取 `GitHub更新监测列表.md`（仓库链接 + 本地版本基线 + 上轮 yes/no），用 PowerShell 直连 GitHub REST API（每仓库单次调用）核对 GIT 最新正式 Release，由内联确定性状态机完成版本比较、yes/no 判定、翻转检测与统计，事务式原子写回该 md，并生成推送摘要。无 Python、无 Node、无子 agent 编排；API 失败项保留上轮状态，不伪装成功。

---

## 1. 目录结构

```
D:\AI\Workspace\automatic\github-version-monitor\
├─ SKILL.md                    ← skill 本体（execution agent 每轮执行的操作规范 + 完整内联实现，v1.4；唯一代码事实源）
├─ .backup\                    ← 归档区（AUTOMATION-PROMPT.md = 子 agent 派遣场景可选入口、旧 askill、旧状态文件副本）
├─ GitHub更新监测列表.md        ← 状态文件：既是输入（仓库清单 + 本地版本基线 + 上轮 yes/no）也是输出（原地更新）
├─ readme.md                   ← 本文件
├─ .env                        ← 运行时凭证（仅本机本目录：`GITHUB_TOKEN`；不进 git、不进 skill 代码）
├─ .gitignore                  ← 锁定 `.env` / `.monitor/` / `.backup/` 不入版本控制
├─ review-*.md                 ← 独立评审报告（留档）
└─ .monitor\                   ← 运行时目录（全部产物由 SKILL.md 内联代码生成，无外部 orchestrator）
   ├─ run.lock                 ← 运行锁（步骤1创建、步骤4/5释放；滞留 30 分钟 + PID 死亡才可接管）
   ├─ result.json              ← 程序事实 + 结构化辅助复核证据的唯一机器审计载体
   ├─ result.review.tmp        ← review 写回临时文件（校验通过后原子替换 result.json）
   ├─ fetch_run.log            ← 运行日志（一行一轮，记录 apiOK/apiErr 与"无 HTML 回退"）
   ├─ backups\                 ← 每次运行前对 md 的毫秒时间戳备份
   └─ trash\                   ← 三天前备份的"只移不删"暂存（可恢复）
```

**注册方式**：WorkBuddy 标准发现路径 `.workbuddy/skills/github-version-monitor` 是一个目录 junction，指向本目录。文件物理上全在本目录，WorkBuddy 仍能在标准路径加载到 `SKILL.md`（见 §7.1）。

---

## 2. Documentation Conventions

本节是防止文档再次退化为聊天式说明的长期约束。

### Audience

- `SKILL.md`：execution agent（机器执行代理）。
- `readme.md`：implementer / maintainer / harness integrator。

### Normative Terms

- `MUST` / 必须
- `MUST NOT` / 不得
- `SHOULD` / 应
- `MAY` / 可以

### State Names

所有状态名必须使用代码中的 canonical enum：`ok` / `not_found` / `rate_limited` / `server_error` / `network_error` / `invalid_response` / `metadata_incomplete` / `auth_error` / `forbidden` / `http_error`。

### Field Names

所有机器字段使用代码中的 canonical field：`gitVer` / `gitDate` / `localVer` / `flag` / `prevFlag` / `queryStatus` / `cmp` / `isNew` / `isFlip` / `review` / `publishedUtc` / `stats` / `items` / `runAt`。

### Time

内部 UTC；展示 `UTC+08:00`。禁止依赖运行环境本地时区。

### Source Authority

GitHub REST API 为版本事实源（API 主事实源）；HTML 页仅诊断辅助（HTML 诊断辅助源）。HTML 不得作为版本、日期、yes/no 的写回事实源。

### Agent Boundary

agent 只解释程序事实，不重算程序事实。agent 禁止计算 `stats` / `flag` / version ordering / `isNew` / `isFlip` / `synced` / API failure count / monitor total；agent 禁止修改 `items` / `stats` / `flag` / `gitVer` / `gitDate` / `localVer`。

### Human-facing Text

只允许出现在 report template（`SKILL.md` §8.6），不允许侵入程序规范。

### Terminology

全文使用 `SKILL.md` §1 术语表中的 canonical 术语，禁止同义词混用。

---

## 3. 设计约束（不可违背）

| # | 约束 | 违反后果 |
|---|------|----------|
| 1 | 不依赖 Python / Node.js 运行时 | 制造待淘汰资产 |
| 2 | 不派遣子 agent 编排 | token / 时间开销不可控 |
| 3 | 每仓库正常路径只调 1 次 `releases/latest`；异常复核每仓库最多追加 1 次列表接口；HTML 页仅诊断辅助、永不回写 | 双调用把 60/h 额度翻倍 → 自造 403 限流；HTML 替代 API 事实 |
| 4 | 全部逻辑内联写进 `SKILL.md`（唯一代码事实源），不另写脚本文件 | 减少依赖、保持单文件可移植 |
| 5 | 状态文件是输入也是输出：解析旧表拿本地版本基线与上轮 yes/no，再原地写回，不清空、不另存 | 丢失本地版本基线 / 多份副本混乱 |
| 6 | 所有数字取本轮实测值（`stats` JSON），禁止编造、禁止 agent 自行统计 | 假数据比无数据更糟 |
| 7 | 监测项增减一律由用户指定，不自行增删；404 仓库照留 | 擅自改清单 = 破坏用户证据 |
| 8 | API 失败如实标注并保留上轮状态，不用 HTML 通道或重跑替代 API 事实 | 伪装成功 = 欺骗交付 |
| 9 | 确定性下沉：版本比较、yes/no 判定、翻转检测、统计、表格改写全部由内联 PowerShell 计算；agent 只读取程序事实、执行允许的辅助复核、生成结构化 review evidence、撰写自然语言 | 旧版 agent 读 `Format-Table` 文本手工合并 → 漏行 / 错列 / 统计错 |
| 10 | 运行锁 + 原子写入：整轮在 `.monitor/run.lock` 锁内执行；md 走"临时文件 → 结构校验 → 原子替换" | 并发两轮互相覆盖；写一半崩溃留半个 md |
| 11 | 凭证只放 `.env` / 系统环境变量，不进 skill 代码、状态文件、git | 明文 token 进代码库 = 泄密 |

---

## 4. 执行逻辑（6 步，顺序不可乱）

1. **状态检查 + 获取运行锁 + 提前备份**：先检查状态文件存在（缺失 → `STATE_MISSING|`，不建锁、不创建空清单）；再原子争锁（`FileMode.CreateNew` 独占创建，两个并发只可能有一个成功，失败者输出 `LOCKED|` 直接退出）；取得锁后复制 `GitHub更新监测列表.md` 到 `.monitor/backups/` 毫秒时间戳副本。步骤 2~5 每步开头刷新锁 heartbeat；陈锁（heartbeat 超 30 分钟）只有在锁内 PID 确认死亡时才可接管，任何不确定一律保守 `LOCKED|`。
2. **解析 + 查询 + 状态机 + 比较 + 翻转 + 统计**：先刷新锁 heartbeat；fail-closed 解析（数据行必须 exactly 6 列且第 2 列为合法 releases 链接，任何 schema 异常 → 整轮 `PARSE_ERROR|`、不写回，无静默跳过路径）；每仓库调 1 次 `releases/latest`，按状态机分类（`ok` / `not_found` / `metadata_incomplete` / `auth_error` / `rate_limited` / `forbidden` / `server_error` / `http_error` / `network_error` / `invalid_response`——403 只有在 `X-RateLimit-Remaining=0` 时才判 `rate_limited`，否则为 `forbidden`）；`tag_name` 有值但 `published_at` 缺失 → `metadata_incomplete`，`gitVer` / `gitDate` 都不覆盖；程序用 `Compare-Ver` 计算 `flag`、`isNew`、`isFlip`、`review`；统计（含 `synced`）落盘 `result.json`（含 `review` 占位）+ 追加 `fetch_run.log`；输出 `FETCH_COMPLETE|` + `SUMMARY|` + JSON。单仓库 API 失败保留上轮状态并继续。
3. **事后清理**：刷新锁 heartbeat；把 `.monitor/backups` 中超过 3 天且非最新的备份移入 `.monitor/trash/`（永远保留最新一份，只移不删）。
4. **异常复核（辅助证据通道，仅待核项）**：三通道 = ①`releases/latest` 主查询（步骤 2 程序事实）②`releases?per_page=5` 列表接口（每异常仓库最多追加 1 次）③releases HTML 页（仅诊断辅助，结论只进备注标 `review=true`，永不回写 `gitVer` / `gitDate` / `flag`）。触发：`review=true` 或 `isNew=true` 且满足版本跳号 / 日期存疑条件。`rate_limited` 项不进入复核、不重试。复核不改 `flag`，证据结构化写回 `result.json.review`；写回必须原子（`result.review.tmp` → JSON 结构校验 → `stats`/`items` 完整性校验 → 原子替换）；写回失败输出 `REVIEW_WRITE_ERROR|`，不执行步骤 5、不替换主 md、保留 backup、释放 `run.lock`、整轮判定 `failed`；校验通过输出 `REVIEW_WRITE_OK|`。
5. **原地更新 md（程序改写 + 原子提交）**：刷新锁 heartbeat；agent 按步骤 2 JSON 撰写「结论 / 更新摘要 / 备注」三段填入写回脚本变量，脚本自动改写表格行（`gitVer` / `gitDate` / `flag`）、元信息行（如实标注"API 成功 X / 失败 E / 待核 Q，无 HTML 回退"）、替换三节正文，最后临时文件 → 结构校验（行数精确相等 + repo 集合一致 + flag 合法 + 四节锚点存在）→ 原子替换，释放运行锁（释放前确认锁内 PID 等于当前进程 PID）。校验不过（`VALIDATE_ERROR|`）不重试，保留主 md 原状。
6. **生成汇报**：(A) 运行结果报告模板 + (B) 微信推送精简摘要（见 §6），数字全取 `stats` JSON（含 `synced`）。

### 4.1 状态文件 schema（contract）

`GitHub更新监测列表.md` 必须满足（任何异常 → 整轮 `PARSE_ERROR|`，不写回）：

- 必须存在 `## 监测列表` 节，节内为 6 列 Markdown 表；
- 列顺序固定：`# | 项目名称 | GIT最新版本 | GIT更新日期 | 本地版本 | 是否更新`；
- 第 2 列必须为 `[项目名](https://github.com/{owner}/{repo}/releases)` 形式的合法 releases 链接；
- 数据行必须 exactly 6 列（5 列、7 列等变体一律 `PARSE_ERROR`，不静默跳过）；
- 第 6 列只允许小写 `yes` / `no`；
- 顶部引用块含"最近核对时间"行（写回时程序改写）；
- `## 结论` / `## 更新摘要` / `## 备注` / `## 核对方法` 四节为写回替换的锚点。

### 4.2 `result.json` schema（contract）

```json
{
  "runAt":  "UTC ISO 8601",
  "stats":  { "total": 0, "apiOk": 0, "apiErr": 0, "synced": 0, "yes": 0,
              "uninstalled": 0, "pendingReview": 0, "newReleases": 0,
              "flips": 0, "token": "set|unset" },
  "items":  [ { "repo": "owner/repo", "name": "…", "gitVer": "…", "gitDate": "…",
                "localVer": "…", "flag": "yes|no", "prevFlag": "yes|no",
                "latest": "…", "publishedUtc": "…", "status": "queryStatus enum",
                "cmp": "lt|eq|gt|incomparable|''", "isNew": false, "isFlip": false,
                "review": false, "error": "…" } ],
  "review": { "performed": false, "items": [] }
}
```

- `stats` ← PowerShell 事实，只读。
- `items` ← PowerShell 事实，只读。
- `review` ← 辅助复核证据，可由 agent 写；不得反向修改程序事实。

### 4.3 机器运行状态协议

本表是本轮结果的唯一判定接口。

| 标记 | 阶段 | 语义 | 本轮判定 |
|---|---|---|---|
| `STATE_MISSING\|` | 步骤 1 | 状态文件不存在 | blocked |
| `LOCKED\|` | 步骤 1~5 | 锁被持有或陈锁判定不确定 | blocked |
| `PARSE_ERROR\|` | 步骤 2 | schema 异常 | failed |
| `RUNTIME_ERROR\|` | 步骤 2/4/5 | 未预期运行错误（锁丢失 / heartbeat 失败 / 锁 ownership 校验失败） | failed |
| `FETCH_COMPLETE\|` | 步骤 2 | fetch 阶段成功（`result.json` 落盘） | fetch 阶段成功（不代表整轮 success） |
| `REVIEW_WRITE_OK\|` | 步骤 4 | review 证据原子写回成功 | 辅助阶段成功 |
| `REVIEW_WRITE_ERROR\|` | 步骤 4 | review 写回失败 | failed（不执行步骤 5，不替换主 md，保留 backup，释放 `run.lock`） |
| `VALIDATE_ERROR\|` | 步骤 5 | 写回校验未过，主 md 未动 | failed |
| `COMMIT_OK\|` | 步骤 5 | 原子替换完成 | success |
| `BACKUP_OK\|` / `SUMMARY\|` | 步骤 1/2 | 备份完成 / 统计摘要 | 辅助观察 |

整轮 success 判定：

```text
FETCH_COMPLETE
+ REVIEW_WRITE_OK（仅当本轮触发 review 时）
+ COMMIT_OK
```

若本轮没有 review 项，允许跳过 `REVIEW_WRITE_OK`。`FETCH_COMPLETE` 不得单独代表整轮 success。

---

## 5. 关键实现约束（重建必看）

完整实现见 `SKILL.md` 对应章节；本节仅描述 contract 与 invariant。

### 5.1 `published_at` 类型不确定

在当前 PowerShell `Invoke-RestMethod` 运行环境中，GitHub REST API 的 `published_at` 实测会被反序列化为 `[System.DateTime]` 对象，没有 `Substring` 方法。跨 harness / 等价实现不得预设其类型，应先实测确认（可能返回字符串）。无论返回字符串还是 DateTime，都不得盲目使用 `.Substring`。

正确写法：`$j.published_at.ToString("yyyy-MM-dd")`。内部状态另存完整 UTC：`$j.published_at.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')`。

### 5.2 API 请求预算

未认证 GitHub REST API 仅 60 次/小时。每仓库正常路径只 1 次 `releases/latest`；异常复核每仓库最多追加 1 次列表接口。仓库多（>50）或常限流时，配置 `$env:GITHUB_TOKEN`（提升至 5000/h）。不得退化为 HTML 通道替代 API 事实。

### 5.3 表格列索引映射

表格 6 列（`$r.Trim().Trim('|') -split '\|'` 后 0 索引数组）：

| 显示列 | 内容 | 拆分后索引 |
|--------|------|-----------|
| `#` | 序号 | `c[0]` |
| 项目名称 | `[名](releases链接)` | `c[1]` |
| GIT最新版本 | `vX.Y.Z` | `c[2]` |
| GIT更新日期 | `YYYY-MM-DD` | `c[3]` |
| 本地版本 | `vX.Y.Z` / 未安装 | `c[4]` |
| 是否更新 | yes/no | `c[5]` |

映射：`gitVer = $c[2]`、`localVer = $c[4]`、`prevFlag = $c[5]`（翻转检测必需输入）。必须先跳过分隔行（`($r -replace '[|\s:\-]','') -eq ''`）与表头（`$c[1] -match "项目名称"`）。

### 5.4 数据来源

- `WebFetch` 不适合抓 `api.github.com` 的纯 JSON。使用 `Invoke-RestMethod` 直连。
- 搜索引擎快照滞后。以 API 返回为准。
- `releases/latest` 忽略 prerelease，且不等于版本号最高者（按 `created_at` 取最新正式 Release）。用户用 rc/prototype 时经异常复核通道查预发布；HTML 页结论只进备注标 `review=true`，永不回写 `gitVer`。

### 5.5 状态文件读写闭环

解析旧表 → 拿本地版本基线 + 上轮 yes/no → 拿 API GIT 最新正式 Release → 原地写回。不清空、不另存新文件。备份单独走 `.monitor/backups`。

### 5.6 机器接口

`Format-Table` 是人类展示格式，不是机器接口。一律 `ConvertTo-Json` 输出结构化结果（`stats` + `items`），agent 从 JSON 取数撰写自然语言。

### 5.7 解析失败

候选行解析失败 → 收集问题行 → 整轮 `PARSE_ERROR` 终止、不写回主 md、保留备份、回报问题行。不得静默 `continue`。

### 5.8 版本比较

`"1.2.10" < "1.2.9"` 在字符串比较里是 true。版本大小只能用内置 `Compare-Ver`（数值分段 + prerelease < stable + 异通道/非支持格式 → `incomparable` 进 `review=true`），agent 禁止自行比较。`Compare-Ver` 是本技能自定义的受限版本比较器（监测场景专用），不是完整 SemVer parser——regex 只覆盖常见版本格式，不支持的格式一律 `incomparable` 进 `review=true`。

### 5.9 凭证

认证 token 来源：系统环境变量 `GITHUB_TOKEN` 优先 → 缺失则读同目录 `.env`。凭证使用最小权限（监测公开仓库只需 `public_repo` 只读）。具体 PAT 的到期日属于本地运维信息（记录在 `.env` 本地注释或运维备注），不是技能规范的一部分。

到期后果：PAT 过期后脚本每轮 `token=unset` → 回落未认证 60/h 限额；若 `TOKEN=unset` 且单日运行超 2 轮/小时，再次触发限流 → API 失败项按约束 8 保留上轮状态并如实标注（不走 HTML 替代），汇报提示配置新 token。skill 不崩溃、不假成功，只是回到限流前的约束内运行。

到期处理（用户操作，非 skill 职责）：

1. 到 GitHub 重新生成一个最小权限的 PAT（过期设为合理周期）；
2. 更新本目录 `.env` 的 `GITHUB_TOKEN=` 值（或重写系统 User 环境变量）；
3. 下一轮自动生效，无需改任何代码。不得把新 token 写进 `SKILL.md` / `readme.md` / 状态文件。

通用安全原则：即使 credential 权限有限（只读公开仓库），也不得写入 skill、状态文件或 git；一旦泄露，按 credential compromise 处理（立即吊销并轮换）。

### 5.10 运行锁模型

运行锁采用**原子创建 + heartbeat + PID 存活检查**模型，不是持续持有的 OS 文件句柄锁。

- 步骤 1 用 `FileMode.CreateNew` 原子创建锁文件，并发下只有一个进程能成功创建。
- 运行期间不持有持续 OS 文件句柄；步骤 2~5 每步开头用 `FileShare.None` 独占打开锁文件刷新 heartbeat，用于检测异常并发。
- 陈锁接管条件：heartbeat 超 30 分钟 **且** 锁内 PID 确认死亡。任何不确定一律保守 `LOCKED|`。
- 释放锁前必须确认锁内 PID 等于当前进程 PID；不一致则不删除，输出 `RUNTIME_ERROR|`。

---

## 6. 汇报格式（所有数字取本轮 `stats` JSON 实测值）

### (A) 运行结果报告模板（多优先级）

1. 开头客观还原：已按程序判定如实还原监测列表（yes/no 全部由 `Compare-Ver` 计算），已落盘复核无误；本地版本基线本轮未被自动修改；本轮 API 失败 E 项已保留上轮状态并如实标注。
2. 第一优先级：已安装且需更新（表格：`项目名 | 本地版本 | GIT 最新正式 Release | 跨越情况 | 发布日期`）。
3. 第二优先级：本轮新发现（`isNew=true` 项，含 UTC 发布时间与北京时间）与 no→yes 翻转（`isFlip=true` 项）。
4. 第三优先级：特别关注与提醒（`review=true` 待核项 + 客观异常信号）。
5. 第四优先级：完整状态汇总（监测总数 / `synced` / 需更新 / 未安装 / 本轮失败 + 各项名称）。
6. 小结：一句客观收尾。

### (B) 微信推送摘要（精简，框架推送用）

```
GitHub 监测完成：监测 N 项，本轮 M 项需更新、K 项未安装、E 项 API 失败（保留上轮状态）。
需更新：<项目名> <本地版本>→<GIT 最新正式 Release>(<发布日期>)；…
未安装（GIT 已有最新正式 Release）：<项目名> <GIT 最新正式 Release>；…
完整清单见 GitHub更新监测列表.md
```

约束：`N` = 监测总数，`M` = `flag=yes` 项数，`K` = 本地版本「未安装」项数（口径为"未安装"），`E` = 本轮 API 失败项数（`E=0` 时省略该句）；`synced` = 本轮 API 成功、已安装、`Compare-Ver` 结果为 `eq` 的项数，用于完整状态汇总；均取 `stats` 实测值，禁止编造；需更新行只列 yes 项，多个 `；` 分隔，无则写「无」；未安装行列未安装且 GIT 已有正式版的项；发布日期取 `MM-DD`（统一由内部唯一事实 `publishedUtc` 按 `UTC+08:00` 换算，"今日发布"判断同此口径）；末尾固定指向 `GitHub更新监测列表.md`；只推变更摘要不刷屏。

---

## 7. 注册与重建

### 7.1 WorkBuddy 注册

WorkBuddy 在以下路径发现 skill（目录内含 `SKILL.md` 即被加载）：

- 项目级：`<workspace>/.workbuddy/skills/<name>/SKILL.md`
- 用户级：`~/.workbuddy/skills/<name>/SKILL.md`

本仓库采用 junction 技巧：文件物理放在 `D:\AI\Workspace\automatic\github-version-monitor\`，再在标准发现路径建目录 junction：

```powershell
# 删除已清空的原真实目录后，建 junction（需同盘，无需管理员）
Remove-Item "D:\AI\Workspace\automatic\.workbuddy\skills\github-version-monitor" -Force
New-Item -ItemType Junction `
  -Path "D:\AI\Workspace\automatic\.workbuddy\skills\github-version-monitor" `
  -Target "D:\AI\Workspace\automatic\github-version-monitor"
```

效果：`.workbuddy/skills/github-version-monitor/SKILL.md` 能解析到新目录里的文件。

### 7.2 Reconstruction Contract

**Precondition**

1. 目标 harness 支持 PowerShell 5.1+ 或 PowerShell 7+，且具备 `Invoke-RestMethod` 等价能力。
2. 目标 harness 允许 execution agent 执行内联 PowerShell。
3. 目标 harness 可访问 `api.github.com`。
4. 已有一份符合 §4.1 schema 的 `GitHub更新监测列表.md`。

**Required Files**

1. `SKILL.md`（含 frontmatter 与全部内联实现，唯一代码事实源）。
2. `GitHub更新监测列表.md`（状态文件，符合 §4.1 schema）。
3. `.gitignore`（锁定 `.env` / `.monitor/` / `.backup/`）。

**Required Runtime**

1. PowerShell 5.1+ 或 7+。不依赖 Python / Node.js。

**Required Environment**

1. `$env:GITHUB_VERSION_MONITOR_BASE` 指向 skill 目录（可选；缺失时按 `$PSScriptRoot` → 本机默认路径解析）。
2. `$env:GITHUB_TOKEN` 或同目录 `.env` 中的 `GITHUB_TOKEN`（可选；缺失时按未认证 60/h 限额运行）。

**Required Execution Semantics**

1. 每仓库正常路径只调 1 次 `releases/latest`；异常复核每仓库最多追加 1 次列表接口。
2. `queryStatus != ok` 时不修改该监测项的 `gitVer` / `gitDate` / `flag`。
3. HTML 诊断辅助源不得作为版本、日期、yes/no 的写回事实源。
4. 版本比较只用 `Compare-Ver`；agent 不自行比较版本字符串。
5. 解析 fail-closed：数据行必须 exactly 6 列，任何 schema 异常 → `PARSE_ERROR|`。
6. 403 仅在 `X-RateLimit-Remaining = 0` 时判 `rate_limited`，否则判 `forbidden`。
7. 运行锁采用原子创建 + heartbeat + PID 存活检查模型（见 §5.10）。
8. md 写入走"临时文件 → 结构校验 → 原子替换"；校验为行数精确相等 + repo 集合一致 + flag 合法 + 四节锚点存在。
9. review 写回走"临时文件 → JSON 结构校验 → `stats`/`items` 完整性校验 → 原子替换"；失败输出 `REVIEW_WRITE_ERROR|` 并终止步骤 5。
10. 释放锁前确认锁内 PID 等于当前进程 PID。
11. 所有运行时刻内部 UTC，展示 `UTC+08:00`；日期内部事实为 `publishedUtc`。
12. agent 禁止计算 `stats` / `flag` / version ordering / `isNew` / `isFlip` / `synced` / API failure count / monitor total；agent 禁止修改 `items` / `stats` / `flag` / `gitVer` / `gitDate` / `localVer`。

**Validation**

1. 执行步骤 1，确认输出 `BACKUP_OK|` 且 `.monitor/backups/` 下生成毫秒时间戳副本。
2. 执行步骤 2，确认输出 `FETCH_COMPLETE|` + `SUMMARY|` + JSON，且 `.monitor/result.json` 含 `runAt` / `stats` / `items` / `review` 四字段。
3. 执行步骤 5，确认输出 `COMMIT_OK|`，主 md 数据行数量与 `items.Count` 精确相等，repo 集合一致，`run.lock` 已释放。
4. 构造一个 `review=true` 项，执行步骤 4，确认输出 `REVIEW_WRITE_OK|`，且 `result.json` 的 `stats` / `items` 与写回前完全一致。
5. 构造一个 schema 异常行，确认输出 `PARSE_ERROR|`，主 md 未被修改，备份保留。
6. 并发启动两轮，确认第二轮输出 `LOCKED|`，无并发覆盖。

**SKILL.md frontmatter（不可少）**

```yaml
---
name: github-version-monitor
description: GitHub 项目版本监测（自动化版·纯 PowerShell）——读取 GitHub更新监测列表.md 的监测清单，PowerShell 直连 GitHub REST API（每仓库单次调用），由内联确定性状态机完成查询分类、版本比较、yes/no 判定、翻转检测与统计，事务式原子写回该 md 并生成推送摘要。无 Python、无子 agent 编排；API 失败项保留上轮状态，不伪装成功。
---
```

---

## 8. 执行速查

- **执行顺序**：状态检查 + 原子锁 + 备份 → heartbeat → 解析（exactly 6 列）/ 查询 / 状态机 / `Compare-Ver` 比较 / 翻转 / 统计（`result.json`）→ heartbeat + 清理三天前备份 → 异常复核（仅 `review=true` 项，证据原子写回 `result.json.review`）→ heartbeat + 原子写回 md → 出 (A) + (B) 汇报。
- **协议标记**：`STATE_MISSING|` / `LOCKED|` = blocked；`PARSE_ERROR|` / `RUNTIME_ERROR|` / `REVIEW_WRITE_ERROR|` / `VALIDATE_ERROR|` = failed；`FETCH_COMPLETE|` + `REVIEW_WRITE_OK|`（若触发 review）+ `COMMIT_OK|` = success；`SUMMARY|` = 统计摘要（含 `synced`）。
- **时间**：内部 UTC；展示 `UTC+08:00`。日期唯一内部事实 = `publishedUtc`；展示日期 = `publishedUtc` → `UTC+08:00`。不使用 `.Substring`。
- **调用预算**：每仓库 1 次 `releases/latest`（异常复核最多 +1 次列表接口）；403 只有 `X-RateLimit-Remaining=0` 才是 `rate_limited`，401 → `auth_error`，403 + `remaining>0` → `forbidden`；API 失败项保留上轮状态，不走 HTML 替代。
- **列索引**：`gitVer=c[2]`，`localVer=c[4]`，`prevFlag=c[5]`（翻转检测输入）；数据行必须 exactly 6 列，异常 → `PARSE_ERROR|`。
- **版本比较**：只信 `Compare-Ver`（自定义受限比较器，非完整 SemVer），禁止字符串比较、禁止心算；`K` = 未安装项数；`synced` = 成功且已装且 `eq`。
- **数字全实测**（`stats` JSON）；监测项增减由用户指定；本地版本基线只读；`result.json` 的 `items` / `stats` 禁改，agent 只写 `review` 字段。
- **推送**由框架 UI 开关负责，skill 只产摘要、不写 key/token（凭证只放 `.env` / 系统变量）。
- **文件路径**：`$base` 三层解析（`GITHUB_VERSION_MONITOR_BASE` → `$PSScriptRoot` → 本机默认 `D:\AI\Workspace\automatic\github-version-monitor`）。

---

## 9. Failure Mode History

- 2026-09-01：单日 5 轮 × 22 仓库 ≈ 110 次调用远超未认证 60/h 限额，15/22 项限流后旧 orchestrator 走 HTML 页替代 API 事实、日期沿用旧 md，运行日志却记录 `OK=22 ERR=0`。
- 2026-09-01 前：存在未记录的外部 orchestrator 脚本（生成 `checklist.json` / `result.txt` 等），其 HTML 替代行为违反约束 8。v1.1 起废除，`.monitor` 产物全部由 `SKILL.md` 内联代码生成。

当请求预算超过 GitHub REST API 当前限制时，项目不得通过 HTML 数据替代 API 事实。API 失败项必须保留上轮状态，并在运行结果中显式记录失败数量。

---

## 10. Design Rationale

- 状态文件同时承担输入和输出角色：每轮自动化线程新开、不沿用历史上下文，上一轮状态只能从状态文件恢复。
- 全部逻辑内联单文件：减少依赖、保持跨 harness 可移植。
- 确定性下沉到 PowerShell：版本比较、yes/no、翻转、统计属于可判定计算，交给 LLM 会产生漏行 / 错列 / 统计错。
- 事务式原子写入：md 是唯一证据文件，写一半崩溃会破坏用户证据。
- 运行锁采用原子创建 + heartbeat + PID 检查：跨 harness 下持续 OS 文件句柄锁的实现风险高于收益。
- 403 需 `X-RateLimit-Remaining=0` 证据才判 `rate_limited`：避免把权限问题误报为限流。
- `not_found` 不把状态说明写入 `gitVer`：数据字段只保存该字段语义允许的数据。

---

## 11. 版本与变更记录

- **v1.4（2026-09-06 执行型文档规范化轮）**：①`REVIEW_WRITE_ERROR` 明确终止步骤 5 ②review 写回改为原子写入 ③所有运行时刻统一 UTC → `UTC+08:00` ④`not_found` 不再把状态说明写入 `gitVer` ⑤写回校验由 `-ge` 改为精确相等 + repo 集合一致性校验 ⑥释放锁前确认 ownership ⑦新增 Documentation Conventions ⑧Reconstruction Contract 工程化 ⑨全文去人格化改写 ⑩故障模式定义化。
- v1.3（2026-09-06 复核硬化轮）：404 语义、review 写回保护、北京时间显式 `UTC+08:00`、移除 PAT 实例日期、Agent 职责边界、DateTime 跨 harness 文档。
- v1.1（2026-09-01）：职责边界 / 失败保留上轮状态 / 原子锁 + heartbeat 等基础确立。

*本文件与 `SKILL.md` 同步维护。任何对 skill 逻辑的改动，若涉及约束、schema、状态机或机器状态协议，必须同步更新此处。*
