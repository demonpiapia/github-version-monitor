# GitHub Version Monitor — GPT Handoff

## 1. Project

Repository:

`https://github.com/demonpiapia/github-version-monitor`

从现在开始：

```text
Git repository = 唯一事实源
```

不要使用聊天中的旧文件快照替代 Git 仓库文件。

---

## 2. Current Architecture

当前仓库核心结构：

```text
github-version-monitor/
├─ SKILL-v1.x.md
├─ readme.md
├─ .output/
│  └─ GitHub更新监测列表.md
├─ .exec-plan/
├─ .handoff/
├─ .selfreview/
├─ .GPT/                  # 本地，不要求同步 Git
└─ .monitor/              # runtime，仅运行时生成，不进入 Git
```

职责：

```text
.GPT/
    GPT → Local Agent 指令

.exec-plan/
    Local Agent → Execution Plan

.handoff/
    Agent → Agent context

.selfreview/
    Local Agent self-audit

.output/
    Production persistent state

.monitor/
    Runtime artifacts
```

---

## 3. Production Runtime

Canonical production environment:

```text
Windows
PowerShell 7.x
```

PowerShell 5.1：

```text
兼容性验证
不是 production gate 主环境
```

---

## 4. Production State

唯一生产状态文件：

```text
.output/GitHub更新监测列表.md
```

它同时承担：

```text
Input:
repo list
local version baseline
previous yes/no

Output:
gitVer
gitDate
flag
```

采用：

```text
原地更新
临时文件
结构校验
原子替换
```

未来允许微调：

```text
表格外观
汇报格式
```

不计划大改状态结构。

---

## 5. Runtime Directory

`.monitor/`：

```text
不提交 Git
不作为版本资产
必须由 SKILL 在真实运行时自行创建
```

此前 v1.6–v1.9 测试曾经没有真正验证 `.monitor` 的自动初始化。

v1.10 已开始真实验证：

```text
Step 1 自动创建 .monitor
result.json / fetch_run.log / backups 等实际生成
正常成功后 run.lock 释放
```

因此以后不能把“代码中声明 .monitor 存在”视为充分证据，应该优先依赖真实运行证据。

---

## 6. Version History

```text
v1.5
    历史基线

v1.6
    有效架构基线

v1.7
    曾发生大面积回滚，已废弃

v1.8
    修复 commitSucceeded regression
    同步 .output 状态路径

v1.9
    修复临时文件/锁异常清理问题

v1.10
    修复 review failure terminal-status 路径
    但又发现 stats/items integrity failure path 缺少 return

v1.11
    已形成
    核心修复：
    stats/items integrity failure
    → RUN_STATUS|failed|
    → return
```

---

## 7. v1.10 Final Validation

v1.10 最终验证：

```text
PRODUCTION_NOT_READY
```

核心 P1：

```text
Step 4
stats/items 完整性失败
    ↓
RUN_STATUS|failed|
    ↓
缺少 return
    ↓
继续执行
    ↓
第二次失败
    ↓
第二次 RUN_STATUS|failed|
```

因此：

```text
RUN_STATUS|failed| count = 2
```

违反：

```text
唯一最终终态
```

这一问题由实际 harness + 静态 early-return audit 双重确认，不属于推测。

---

## 8. v1.11 Scope

v1.11 是最小 P1 修复版本。

核心修改：

```powershell
if ($newStatsJson -ne $origStatsJson -or $newItemsJson -ne $origItemsJson) {
    ...
    Write-Output 'RUN_STATUS|failed|...'
    return
}
```

目标：

```text
一个 fatal path
    ↓
恰好一个 RUN_STATUS
```

不应顺手进行大型重构。

---

## 9. v1.11 Validation

已经准备好定向验证 Prompt：

`v1.11-targeted-validation-prompt.md`

下一阶段测试重点：

```text
T38-stats-items
T38-A
T38-B
T38-C
T38-heartbeat
T38-result-read

T22
T23
T37
T39
T43
T46

T04-PS7
T04-PS5.1
T05-PS5.1
T18
T26

.monitor initialization
.output path
early-return audit
final-status uniqueness audit
v1.10 → v1.11 diff integrity
self-review
```

核心硬门槛：

```text
T38-stats-items
RUN_STATUS|failed| count = 1
RUN_STATUS|success| count = 0
```

---

## 10. Validation Rules

当前固定原则：

```text
PASS ≠ theoretical correctness
PASS = actual execution + actual expected result + evidence

BLOCKED ≠ PASS
FAIL ≠ BLOCKED

旧版本 PASS 不得直接作为新版本 PASS

不得修改被测 SKILL 后继续把原测试记为 PASS

Structural Diff
+
Behavioral Validation
```

特别需要防止：

```text
“关键词还存在”
```

被误当成：

```text
“行为仍然正确”
```

---

## 11. Local Agent Workflow

Local Agent 的资产：

```text
.exec-plan/
.handoff/
.selfreview/
```

Self-review 文件命名规则：

```text
.selfreview/selfreview-v<version>-YYYYMMDD-HHMMSS.md
```

不能使用不带时间戳的固定文件名。

---

## 12. Current Collaboration Model

```text
GPT
    ↓
Architecture
Audit
Version design
Prompt

        ↓

Local Agent
    ↓
Execution
Testing
Git
Real environment verification

        ↓

Git Repository
    ↓
Single source of truth
```

聊天上下文不再作为项目事实数据库。

---

## 13. Current Next Action

当前不要重新测试 v1.10。

当前直接：

```text
SKILL-v1.11
    ↓
Clean-room targeted validation
    ↓
production-validation-report-v111-final.md
```

测试完成后，以 Git 仓库中的：

```text
production-validation-report-v111-final.md
.production-validation-v111-final/
.exec-plan/
.handoff/
.selfreview/
```

作为下一轮 GPT 审核输入。

---

## 14. Desired Review Behavior for New Conversation

新对话中的 GPT 应：

```text
1. 先读取当前 Git repository
2. 不信任聊天里的旧版本文件
3. 优先审核最新 validation report
4. 再检查 evidence / selfreview / exec-plan
5. 根据实际证据判断 Production Gate
6. 只有在确认需要修改时才形成下一版本
```

禁止：

```text
从头重建历史
重新假设旧版本状态
把历史 PASS 当当前 PASS
```

---

## 15. Current State

```text
Current effective version:
v1.11

Previous:
v1.10 = PRODUCTION_NOT_READY

Current production gate:
CLOSED

Current action:
等待 v1.11 targeted validation
```