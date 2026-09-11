# github-version-monitor · README

本文件是 `github-version-monitor` 的技术说明、部署说明、重建说明与 Harness 适配契约。

当前稳定版本：**v1.12**。

本项目的两个核心文件职责不同：

- `SKILL-v1.12.md`：**当前 Skill 本体、唯一代码事实源**。它包含 execution agent 的操作规范以及完整的内联 PowerShell 实现。
- `readme.md`：**理解、部署、适配与重建说明**。它描述 Skill 的行为契约、运行边界、状态模型以及如何在不同 Harness 中正确重建本地 Skill；不复制完整 PowerShell 实现。

当未来出现新的 `SKILL-vX.YY.md` 时，应始终以**最新版本 Skill 文件**作为实现事实源，并同步更新本 README 中与版本、契约、结构有关的说明。

---

## 0. 项目定位

`github-version-monitor` 是一个用于周期性检查 GitHub 项目正式 Release 是否高于本地版本基线的自动化 Skill。

核心流程：

```text
读取状态文件
    ↓
PowerShell 7+ 直连 GitHub REST API
    ↓
确定性状态机
    ↓
版本比较 / yes-no / 翻转 / 统计
    ↓
必要时生成辅助 review 证据
    ↓
事务式更新状态文件
    ↓
输出机器可消费结果 + 人类摘要
```

项目的实际目标是：

> **提供一个可被不同 AI Harness 可靠执行、并可作为未来自动升级软件内部组件使用的稳定 Skill。**

本项目**不是**大型测试框架，也不以支持大量历史 PowerShell/运行环境为目标。

---

## 1. 当前稳定基线

当前版本：

```text
v1.12
```

生产运行时：

```text
Windows
PowerShell 7.x+
pwsh.exe
```

**PowerShell 5.1 不属于支持目标。**

任何 Harness、Agent、启动器或包装程序均必须：

1. 使用 `pwsh.exe`；
2. 验证 `$PSVersionTable.PSVersion.Major -ge 7`；
3. 不得 fallback 到 `powershell.exe`；
4. 若无法满足 PowerShell 7+，停止执行并报告环境不兼容，不得把执行结果记为 PASS。

---

## 2. 当前仓库结构

```text
D:\AI\Workspace\automatic\github-version-monitor\
├─ SKILL-v1.12.md                         ← 当前 Skill 本体 / 唯一代码事实源
├─ readme.md                              ← 本文件
├─ .output\
│  └─ GitHub更新监测列表.md               ← 持久化状态文件
├─ .monitor\                             ← runtime，仅运行时生成，不进入 Git
│  ├─ run.lock
│  ├─ result.json
│  ├─ result.review.tmp
│  ├─ fetch_run.log
│  ├─ backups\
│  └─ trash\
├─ .exec-plan\                           ← execution plan / 过程资产
├─ .handoff\                             ← agent context / handoff
├─ .selfreview\                          ← local agent self-review
├─ .GPT\                                 ← GPT → Local Agent 指令资产
└─ .production-validation-v112-final\    ← v1.12 定向验证资产
```

其中：

```text
Skill 本体事实       → SKILL-v1.12.md
生产持久状态          → .output/GitHub更新监测列表.md
运行时事实            → .monitor/result.json
运行日志              → .monitor/fetch_run.log
运行锁                → .monitor/run.lock
历史备份              → .monitor/backups / .monitor/trash
```

`.monitor\` 是 runtime，不是版本资产；不得把其中的历史运行产物当成新的生产实现。

---

## 3. 唯一事实源原则

对 Skill 本体的理解、修改、重建与适配，一律遵守：

```text
Git repository = 唯一事实源
```

不得用：

- 聊天里的旧版本快照；
- 旧 validation report；
- Agent 自己记忆的历史逻辑；
- 其他 Harness 的旧 Skill；

替代仓库中的最新 `SKILL-vX.YY.md`。

尤其注意：

> **历史 validation PASS 只能证明历史版本在当时测试条件下通过，不能自动转移为当前版本 PASS。**

---

## 4. Skill 本体与 README 的关系

### 4.1 `SKILL-v1.12.md`

面向 execution agent。

它定义：

- 执行顺序；
- PowerShell 实现；
- 状态文件 schema；
- API 状态机；
- 版本比较；
- review 触发条件；
- 锁与 heartbeat；
- 原子写入；
- 机器状态协议；
- Agent 与 PowerShell 的职责边界；
- 汇报格式。

它是**唯一代码事实源**。

### 4.2 `readme.md`

面向：

- 新 Harness 的适配者；
- implementer / maintainer；
- validation harness integrator；
- 需要根据最新 Skill 重建本地技能的 Agent。

README 的目标不是让 Agent 直接照抄当前 WorkBuddy 的目录，而是让 Agent **理解 Skill 的不可变行为契约，并根据自己的 Harness 能力生成等价的本地 Skill**。

---

## 5. 核心功能契约

Skill 读取：

```text
.output/GitHub更新监测列表.md
```

每个监测项包含：

```text
项目名称
GitHub releases 链接
GIT 最新正式 Release
GIT 更新日期
本地版本基线
是否更新 yes/no
```

程序负责：

```text
API 请求
HTTP 分类
版本比较
flag
isNew
isFlip
review 触发器
stats
状态文件更新
事务校验
机器运行状态
```

Agent 负责：

```text
读取程序事实
执行允许的辅助复核
整理 review 证据
撰写结论 / 更新摘要 / 备注
```

Agent 不得重新计算：

```text
stats
flag
version ordering
isNew
isFlip
synced
API failure count
monitor total
```

Agent 不得修改：

```text
items
stats
flag
gitVer
gitDate
localVer
```

`review` 只能作为辅助证据，不能反向改变程序计算出的事实字段。

---

## 6. API 与数据来源

版本事实源：

```text
GitHub REST API
GET /repos/{owner}/{repo}/releases/latest
```

`releases/latest` 是主事实源。

HTML releases 页面仅允许作为**诊断辅助源**：

```text
https://github.com/{owner}/{repo}/releases
```

HTML 不能成为：

```text
版本事实源
日期事实源
yes/no 事实源
```

不得使用搜索引擎快照、二手信息或其他网页内容替代 API 主事实。

### 调用预算

正常路径：

```text
每仓库 1 次 releases/latest
```

异常 review：

```text
最多追加 1 次 releases?per_page=5
+
最多 1 次 HTML 诊断请求
```

`rate_limited`：

```text
不重试
不追加 review API
不使用 HTML 替代 API
```

---

## 7. 查询状态机

`queryStatus` 使用固定 canonical enum：

```text
ok
not_found
rate_limited
server_error
network_error
invalid_response
metadata_incomplete
auth_error
forbidden
http_error
```

核心语义：

| 状态 | 处理 |
|---|---|
| `ok` | 使用 API 正式 Release 数据继续比较与更新 |
| `not_found` | `gitVer=""`、`gitDate=""`，保留上轮 `flag`，进入 review |
| `rate_limited` | 保留上轮状态，不重试，不进入步骤 4 |
| `server_error` | 保留上轮状态，进入 review |
| `network_error` | 保留上轮状态，进入 review |
| `invalid_response` | 保留上轮状态，进入 review |
| `metadata_incomplete` | 保留上轮状态，进入 review |
| `auth_error` | 保留上轮状态，进入 review |
| `forbidden` | 保留上轮状态，进入 review |
| `http_error` | 保留上轮状态，进入 review |

核心原则：

> `queryStatus != ok` 时，默认不覆盖该项已有的 `gitVer` / `gitDate` / `flag`；不要把 API 失败伪装成成功。

---

## 8. 版本比较规则

版本大小只能由 Skill 内置的 `Compare-Ver` 判定。

当前比较器属于：

```text
受限版本比较器
```

不是完整 SemVer parser。

已支持常见：

```text
1
1.2
1.2.3
1.2.3-rc1
1.2.3-beta1
...
```

对于不支持或不同预发布通道无法可靠比较的版本：

```text
incomparable
↓
review=true
```

不要把该比较器扩展成通用 SemVer 实现，也不要让 Agent 通过字符串比较或人工心算替代程序结果。

---

## 9. 状态文件契约

生产状态文件：

```text
.output/GitHub更新监测列表.md
```

它同时承担：

```text
Input
repo list
local version baseline
previous yes/no

Output
gitVer
gitDate
flag
summary / notes / metadata
```

### 固定表结构

表头必须为：

```text
# | 项目名称 | GIT最新版本 | GIT更新日期 | 本地版本 | 是否更新
```

数据行必须 exactly 6 列。

第 2 列必须是合法 GitHub releases 链接：

```text
[项目名](https://github.com/{owner}/{repo}/releases)
```

第 6 列只能是：

```text
yes
no
```

且大小写严格为小写。

必须存在：

```text
## 监测列表
## 结论
## 更新摘要
## 备注
## 核对方法
```

顶部必须存在“最近核对时间”信息。

解析采用 fail-closed：

```text
schema 异常
    ↓
PARSE_ERROR|
    ↓
主 md 不写回
```

不得静默跳过异常数据行。

监测项的增删只能由用户指定；Skill 不自行增删监测项。

---

## 10. `result.json` 契约

`.monitor/result.json` 是机器侧运行事实的主要载体。

核心字段：

```json
{
  "runAt": "UTC ISO 8601",
  "stats": {
    "total": 0,
    "apiOk": 0,
    "apiErr": 0,
    "synced": 0,
    "yes": 0,
    "uninstalled": 0,
    "pendingReview": 0,
    "newReleases": 0,
    "flips": 0,
    "token": "set|unset"
  },
  "items": [],
  "review": {
    "performed": false,
    "items": []
  }
}
```

其中：

```text
stats / items = PowerShell 程序事实
review        = 辅助证据
```

review 写回不得修改 `stats` / `items`。

---

## 11. 运行锁与事务模型

### 运行锁

当前模型：

```text
FileMode.CreateNew
+
heartbeat
+
PID 存活检查
```

不是持续持有的 OS 文件句柄锁。

陈锁接管条件：

```text
heartbeat > 30 分钟
AND
锁内 PID 已确认死亡
```

任何不确定情况：

```text
LOCKED|
```

保守退出。

释放锁前必须验证锁内 PID 与当前进程 PID 一致。

### 主 Markdown 写入

必须：

```text
临时文件
↓
结构校验
↓
原子替换
```

禁止直接半写主状态文件。

### review 写入

必须：

```text
result.review.tmp
↓
JSON 校验
↓
stats/items 完整性校验
↓
原子替换 result.json
```

---

## 12. 机器运行状态协议

这是未来自动化软件集成时最重要的接口之一。

### Blocked

```text
STATE_MISSING|
LOCKED|
```

表示本轮未完成正常业务执行，不应被当作成功。

### Failed

```text
PARSE_ERROR|
RUNTIME_ERROR|
REVIEW_WRITE_ERROR|
VALIDATE_ERROR|
RUN_STATUS|failed|
```

表示发生业务或运行错误。

### Success

关键成功链：

```text
FETCH_COMPLETE|
+
REVIEW_WRITE_OK|       # 仅当实际触发 review 时需要
+
COMMIT_OK|
+
RUN_STATUS|success|
```

`COMMIT_OK|` 不是最终状态。

真正决定整轮 success 的最终机器接口是：

```text
RUN_STATUS|success|
```

### Housekeeping

```text
HOUSEKEEPING_WARNING|
```

只表示 backup/trash 等清理阶段存在问题。

它：

```text
不改变核心业务终态
不应使正常核心业务变成 failed
```

但 lock ownership / heartbeat 不属于普通 housekeeping；如果无法确认锁安全性，应优先保证并发安全。

---

## 13. 时间规范

内部事实统一使用：

```text
UTC
```

展示统一使用：

```text
UTC+08:00
```

禁止依赖运行机器的本地时区。

统一转换方式：

```powershell
[DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromHours(8))
```

Release 日期内部事实：

```text
publishedUtc
```

运行时间、heartbeat、backup timestamp、log timestamp 同样使用 UTC 作为内部事实。

---

## 14. Harness 重建 / 适配契约

本 README 的重要用途之一是：

> **任何 AI Harness 中的 Agent 读取本 README 后，都应能够基于最新 `SKILL-vX.YY.md`，重建出符合自己 Harness 实际能力的本地 Skill。**

这里的“重建”不是重新设计业务逻辑，而是：

```text
保持 Skill 行为契约不变
+
适配目标 Harness 的发现机制 / 文件布局 / 执行方式 / 上下文方式
```

### 14.1 必须保留的东西

重建后的本地 Skill 必须保留：

```text
1. 核心业务逻辑
2. queryStatus canonical enum
3. Compare-Ver 语义
4. 状态文件 schema
5. API 是唯一版本事实源
6. API failure 保留上轮状态
7. Agent / PowerShell 职责边界
8. 原子写入
9. 运行锁安全语义
10. result.json 机器事实
11. RUN_STATUS 终态语义
12. review 不反向修改程序事实
13. PowerShell 7.x+ 强制要求
```

目标 Harness 可以改变：

```text
Skill 文件在其本地注册目录的位置
Skill 被发现的方式
Harness 自身要求的 frontmatter / metadata
Harness 的上下文传递方式
Harness 的用户提示包装
Harness 的报告提交入口
```

但是这些变化不得改变 Skill 的核心业务语义。

---

## 15. Harness 适配的推荐流程

任何新 Harness 的 Agent 应按照下面顺序工作。

### Step 1 — 读取仓库最新版本

先读取：

```text
最新 SKILL-vX.YY.md
readme.md
```

不得从旧 Harness Skill 开始改。

### Step 2 — 确认 Harness 能力

确认：

```text
Skill discovery path
execution mechanism
working directory semantics
file read/write ability
PowerShell 7+ availability
network access to api.github.com
environment variable injection
secret handling
stdout/stderr capture
process exit / result capture
```

### Step 3 — 建立能力映射

把 Harness 能力映射到 Skill 需求：

| Skill 需求 | Harness 适配问题 |
|---|---|
| 读取 Skill 文件 | Harness 如何发现/加载技能 |
| 执行 PowerShell | 是否能直接启动 `pwsh.exe` |
| 固定生产路径 | Harness 如何传递工作目录/绝对路径 |
| 状态文件 | 文件系统是否可写 |
| `.monitor` | runtime 是否允许生成 |
| `GITHUB_TOKEN` | Secret / env 如何注入 |
| 机器状态 | stdout/stderr 如何可靠捕获 |
| 报告 | Harness 如何保存或展示结果 |

### Step 4 — 重建本地 Skill

生成 Harness 原生版本时：

```text
复制/转换当前最新 Skill 的规范
↓
只修改 Harness 适配层
↓
不改变核心业务逻辑
```

如果目标 Harness 有自己的 SKILL metadata 格式，可以转换 frontmatter，但不得改变程序语义。

### Step 5 — 强制 PowerShell 7+

目标 Skill 的执行包装必须明确：

```text
pwsh.exe
```

并在执行前确认：

```powershell
$PSVersionTable.PSVersion.Major -ge 7
```

不允许：

```text
powershell.exe
PowerShell 5.1
自动 fallback
```

### Step 6 — 显式路径

至少明确：

```text
Repository absolute path
Skill absolute path
State file absolute path
```

不得要求 Agent 通过“当前目录”“编辑器打开目录”“默认工作区”等隐式上下文猜测。

### Step 7 — 验证 Harness 适配

验证重点不是重新认证整个 Skill，而是证明：

```text
Harness 能正确加载 Skill
+
pwsh 7+ 能运行
+
路径传递正确
+
程序 stdout 能被 Harness 正确读取
+
result.json 可读取
+
RUN_STATUS 可可靠判断
+
状态文件可以安全更新
```

如果 Harness 无法提供某项必要能力：

> **报告不兼容，不得为了适配而削弱 Skill 安全语义。**

---

## 16. Harness 重建时禁止做的事情

不得因为目标 Harness 的限制而：

```text
降级到 PowerShell 5.1
把 API 事实换成 HTML
让 Agent 自己比较版本
让 Agent 自己统计
去掉原子写入
去掉锁
允许 API failure 自动改成成功
让 Agent 修改程序事实
使用旧 Skill 版本代替最新版本
```

也不得把某个具体 Harness 的目录结构、工具名称、运行命令硬编码成所有 Harness 的通用要求。

例如：

```text
WorkBuddy 的 discovery path
```

只能视为 WorkBuddy 的适配示例，不能视为本项目的通用标准。

---

## 17. WorkBuddy 当前适配说明

当前项目历史上使用过 WorkBuddy。

WorkBuddy 适配可以采用项目级或用户级 Skill discovery 机制，具体位置由实际 WorkBuddy 版本和本地环境决定。

如果使用 junction：

```text
物理仓库目录
    ↓
WorkBuddy 标准 Skill 发现目录
```

也只能作为该 Harness 的适配层。

**不得把 WorkBuddy 的路径规则写进通用 Skill 逻辑。**

---

## 18. 凭证

认证凭证：

```text
GITHUB_TOKEN
```

来源优先级：

```text
系统环境变量
↓
同目录 .env
```

凭证不得写入：

```text
SKILL
README
状态文件
validation report
Git history
```

公开仓库监测可以使用对应环境允许的最小权限凭证；无 token 时 Skill 仍应按照自身状态机运行，但要如实面对未认证限额与限流结果。

具体 token 生命周期属于本机运维问题，不属于 Skill 逻辑契约。

---

## 19. 汇报要求

Skill 生成两类人类可读输出：

### 运行结果报告

至少应包含：

1. 本轮客观状态；
2. 已安装且需要更新项目；
3. 本轮新发现 / 翻转；
4. `review=true` 项；
5. 状态汇总；
6. 一句客观结论。

所有数字必须来自本轮 `stats`，禁止 Agent 自行重新统计。

### 推送摘要

精简包含：

```text
监测总数
需更新
未安装
API 失败（如有）
需更新项目摘要
未安装项目摘要
状态文件位置
```

推送能力由外部 Harness/UI 提供；Skill 只生成内容，不保存推送平台密钥。

---

## 20. 当前执行速查

```text
前置：PowerShell 7.x+ / pwsh.exe / 显式绝对路径

步骤 1
状态检查 → 创建 .monitor → 获取运行锁 → backup

步骤 2
heartbeat → 解析 → API → 状态机 → Compare-Ver → isNew/isFlip → stats → result.json

步骤 3
heartbeat → backup/trash housekeeping

步骤 4
heartbeat → 对 review 项执行辅助复核 → 原子更新 result.json.review

步骤 5
heartbeat → Agent 提供自然语言三段 → 程序改写表格 → schema 校验 → 原子替换主 md → 释放锁

步骤 6
生成运行报告与推送摘要
```

---

## 21. 设计原则

当前设计只保留对实际使用有直接价值的工程约束：

```text
确定性计算交给 PowerShell

数据事实与自然语言解释分离

API failure 不伪装成功

状态文件不能被半写

并发运行不能互相覆盖

review 不能污染程序事实

机器结果必须可解析

PowerShell 7+ 强制

Harness 只适配运行环境，不改变业务语义
```

本项目不要求每个版本都进行大型生产认证。

只有当 Skill 本体发生实质逻辑变化时，才需要相应增加定向验证；测试规模应与实际风险和修改范围相匹配。

---

## 22. Failure Mode History

项目历史中曾出现以下真实问题：

### API 限流后错误走 HTML fallback

历史旧实现曾因调用量过高触发 API 限流，随后错误使用 HTML 页面替代 API 事实，并造成状态与日志不一致。

因此当前固定原则：

```text
API 是唯一事实源
HTML 只能诊断
API failure 必须如实记录
```

### 事务 / 状态问题

历史版本曾出现 failure path 缺少 `return`，导致一次运行产生多个最终失败状态。

后来确认并非所有静态 audit 中识别出的 `return` 都属于真正 fatal path，因此当前不采用“看到 return 就机械补 RUN_STATUS”的策略。

原则变为：

```text
真实业务终态必须明确

但不要为了形式化审计而扩大代码复杂度
```

### Housekeeping 与核心业务耦合

v1.12 已将 backup/trash 清理失败降级为：

```text
HOUSEKEEPING_WARNING|
```

清理失败不阻断正常核心监测；lock ownership / heartbeat 仍保持安全优先级。

---

## 23. 版本记录

### v1.12 — 当前稳定版本

主要变化：

```text
1. 强制 PowerShell 7.x+
2. 强制使用 pwsh.exe
3. 明确 repository / skill / state 的执行路径
4. housekeeping failure 不阻断核心业务
5. 重新审查历史 fatal-path audit，拒绝机械补丁
6. 保持核心 API / 状态机 / 原子写入 / 锁机制不变
```

v1.12 已完成压缩后的定向验证：

```text
PS7 强制
正常成功路径
API failure
核心写入 failure
housekeeping failure
final status 语义
```

验证报告：

```text
production-validation-report-v112-final.md
```

当前结论：

```text
Production Gate = OPEN
v1.12 = 当前稳定版本
```

### 历史版本摘要

```text
v1.5   历史基线
v1.6   有效架构基线
v1.7   大面积回滚，废弃
v1.8   修复 commitSucceeded regression / .output 路径
v1.9   修复临时文件 / 锁异常清理问题
v1.10  修复 review failure 路径，但发现 stats/items integrity failure 缺少 return
v1.11  最小修复 stats/items integrity failure path
v1.12  收敛验证体系，强化 PS7 / 路径契约 / housekeeping 边界
```

---

## 24. 给未来 Harness Agent 的最重要指令

读取本 README 和仓库中的**最新 `SKILL-vX.YY.md`**后，请遵守以下顺序：

```text
1. 以最新 SKILL 文件为唯一实现事实源
2. 以本 README 为行为 / 适配解释
3. 识别自己所在 Harness 的 discovery / execution 能力
4. 生成符合该 Harness 规范的本地 Skill
5. 保持核心业务语义不变
6. 强制 PowerShell 7.x+
7. 使用 pwsh.exe
8. 显式指定绝对路径
9. 不因 Harness 限制而削弱安全约束
10. 只验证适配是否工作，不重新发明一套测试体系
```

如果目标 Harness 与本 Skill 的必要运行条件不兼容，应明确报告：

```text
HARNESS_INCOMPATIBLE
```

而不是通过降级 PowerShell、改用 HTML、让 Agent 手工计算或取消事务/锁等方式“适配成功”。

---

*本 README 是说明与适配契约，不是第二份 Skill 实现。任何与 Skill 本体冲突的细节，以仓库中最新 `SKILL-vX.YY.md` 为准。*
