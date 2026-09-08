# Production Validation Prompt
## GitHub Version Monitor — SKILL-v1.10 Targeted Validation

你现在执行：

> **SKILL-v1.10 的定向生产验证。**

本轮不是优化任务，不是重构任务，也不是让你修改 SKILL。

唯一目标：

```text
验证 SKILL-v1.10 是否正确修复 v1.9 的 T38 P1，
并确认该修复没有破坏既有关键行为。
```

---

# 0. 生产环境定义

当前生产主环境：

```text
Windows
PowerShell 7.x
```

PS5.1：

```text
仅作兼容性回归
不作为生产 Gate 主环境
```

生产状态文件：

```text
.output/GitHub更新监测列表.md
```

运行时目录：

```text
.monitor/
```

---

# 1. Clean-Room

创建全新目录：

```text
.production-validation-v110-final/
```

不要复用：

```text
.production-validation/
.production-validation-v17-final/
.production-validation-v18-final/
.production-validation-v19-final/
```

中的当前测试状态、fixture、stdout、结果文件。

旧测试只能作为历史参考：

```text
OLD_EVIDENCE_USED_AS_CURRENT_PASS = NO
```

---

# 2. 被测文件

从当前 Git repository 获取：

```text
SKILL-v1.10.md
SKILL-v1.9.md
.output/GitHub更新监测列表.md
```

不得使用：

```text
聊天中的 SKILL
旧下载文件
旧 validation 目录中的副本
```

---

# 3. SHA256

计算并保存：

```powershell
Get-FileHash .\SKILL-v1.9.md -Algorithm SHA256
Get-FileHash .\SKILL-v1.10.md -Algorithm SHA256
Get-FileHash .\.output\GitHub更新监测列表.md -Algorithm SHA256
```

保存：

```text
v19.sha256
v110.sha256
state.sha256
```

---

# 4. v1.9 → v1.10 Diff Integrity

生成：

```text
v19-v110.diff
```

必须证明：

## v1.10 保留 v1.9 的关键能力

至少：

```text
versionJump
dateSuspicious
reviewReasons

schema validation
strict lowercase yes/no

404 -> not_found
rate_limited
network_error
auth_error
forbidden
server_error
invalid_response
metadata_incomplete

result.fetch.tmp
result.review.tmp

lock
heartbeat
ownership

atomic result persistence
atomic review persistence
atomic md commit

commitSucceeded
COMMIT_OK
RUN_STATUS|success|
RUN_STATUS|failed|

.output/GitHub更新监测列表.md

PS7 production baseline
PS5.1 compatibility
```

## v1.10 允许新增/修改

核心应为：

```text
Step 4 所有不可恢复错误出口
    ↓
cleanup
    ↓
lock release
    ↓
明确最终失败状态
```

尤其修复：

```text
T38
review write failure
→ REVIEW_WRITE_ERROR
→ RUN_STATUS|failed|
```

以及同层其他提前 `return` 路径。

## 禁止

```text
mock URL
forced success
debug bypass
test-only branch
hardcoded token
hardcoded test repository
skip schema
skip lock
skip commit
```

如果发现非预期删除：

```text
FAIL
```

不得用“能力关键词仍存在”替代行为判断。

---

# 5. T38 — 核心 P1 回归

这是本轮最高优先级。

使用外部 fault injection，使：

```text
.monitor/result.review.tmp
```

无法正常写入。

例如：

```text
exclusive file lock
read-only condition
其他不修改 SKILL 的文件系统故障
```

目标：

```text
Set-Content / review tmp write
```

真实失败。

期望：

```text
REVIEW_WRITE_ERROR|
```

同时：

```text
RUN_STATUS|failed|
```

必须存在。

并且：

```text
COMMIT_OK|
不存在

RUN_STATUS|success|
不存在
```

检查：

```text
result.json 未损坏
stats 未改变
items 未改变
主 md 未修改
tmp 按 contract 清理
lock 按 ownership 规则处理
```

---

# 6. T38 多异常分支

不要只测试 Set-Content。

至少覆盖：

### T38-A

```text
review tmp 创建/写入失败
```

### T38-B

```text
review JSON validation failure
```

### T38-C

```text
review tmp → result.json atomic replacement failure
```

每个都必须：

```text
REVIEW_WRITE_ERROR|
+
RUN_STATUS|failed|
```

如果测试 harness 无法制造某一种异常：

```text
BLOCKED
```

不能推理 PASS。

---

# 7. T22 — md tmp 写入失败

重新验证：

```text
Step 5
Set-Content $tmp
```

发生实际失败。

确认：

```text
主 md unchanged
tmp cleaned
lock released
RUN_STATUS|failed|
```

---

# 8. T23 — md atomic replacement failure

重新验证：

```text
Move-Item $tmp -> $md
```

实际失败。

确认：

```text
主 md unchanged
tmp cleaned
lock released
RUN_STATUS|failed|
```

不能出现：

```text
COMMIT_OK|
```

---

# 9. T37 — 正常成功路径

在 PowerShell 7.x 运行完整流程：

```text
Step1
Step2
Step3
Step4
Step5
Step6
```

期望：

```text
BACKUP_OK|
FETCH_COMPLETE|
SUMMARY|
REVIEW_WRITE_OK|（存在 review 时）
COMMIT_OK|
RUN_STATUS|success|
```

确认：

```text
lock released
md updated
result.json valid
```

这是必须 PASS 的生产核心测试。

---

# 10. T39 — Commit 成功 + Lock release 失败

重新验证：

```text
commitSucceeded = true
lockReleased = false
```

必须实际得到：

```text
COMMIT_OK|
RUNTIME_ERROR|
RUN_STATUS|failed|
```

且：

```text
RUN_STATUS|success|
不存在
```

用于验证 v1.10 没有破坏上一版本已经正确的 invariant。

---

# 11. T43 — Full Extended Pipeline Regression

建立全新 fixture。

至少：

```text
normal upgrade
synced
uninstalled
unsupported version
404
versionJump
```

除 404 外 repo 必须真实存在。

PowerShell 7.x 完整执行：

```text
Step1 → Step6
```

确认：

```text
BACKUP_OK|
FETCH_COMPLETE|
SUMMARY|
REVIEW_WRITE_OK|
COMMIT_OK|
RUN_STATUS|success|
```

验证：

```text
result.json
.output/GitHub更新监测列表.md
backup
fetch_run.log
lock
```

一致。

---

# 12. T46 — .output State Path Regression

验证：

```text
.output/GitHub更新监测列表.md
```

是唯一生产状态文件。

确认：

```text
读取来自 .output
写回来自 .output
backup 基于 .output 文件
```

根目录不得重新出现：

```text
GitHub更新监测列表.md
```

---

# 13. T04 — rate_limited Regression

虽然本轮不是专门修 T04，但必须做关键回归。

PowerShell 7：

```text
403
X-RateLimit-Remaining=0
```

必须：

```text
rate_limited
```

并且：

```text
latest request = 1
review API = 0
HTML = 0
retry = 0
```

---

# 14. PS5.1 Header Compatibility Regression

如果系统存在 PowerShell 5.1：

重新验证：

```text
403 + remaining=0
→ rate_limited

403 + remaining>0
→ forbidden
```

验证：

```text
Get-ResponseHeaderValue
```

在：

```text
System.Net.WebHeaderCollection
```

上的行为。

PS5.1 FAIL：

```text
记录 compatibility FAIL
```

但不自动阻塞 PS7 production gate。

---

# 15. T26 — Strict Flag Regression

快速验证：

```text
yes
no
```

合法。

以下全部：

```text
YES
Yes
yEs
NO
No
pending
true
```

必须：

```text
PARSE_ERROR|
```

---

# 16. T18 — State Preservation Regression

至少验证：

```text
auth_error
forbidden
rate_limited
server_error
network_error
http_error
not_found
```

一般失败状态：

```text
gitVer unchanged
gitDate unchanged
flag unchanged
```

404：

```text
gitVer=""
gitDate=""
flag=prevFlag
review=true
```

---

# 17. Lock Regression

重新执行：

### 并发

```text
two PS7 processes
```

必须：

```text
one owner
one LOCKED
```

### stale + alive

```text
heartbeat > 30m
PID alive
→ LOCKED
```

### stale + dead

```text
heartbeat > 30m
PID dead
→ takeover
```

### ownership mismatch

```text
RUNTIME_ERROR
foreign lock retained
```

---

# 18. Process Kill Regression

至少真实执行一次：

```text
Stop-Process
```

选择：

```text
Step2
Step3
Step4
Step5
```

之一。

重新运行后检查：

```text
lock
backup
result.json
main md
```

不得出现错误提交。

---

# 19. Runtime Error Contract Static Audit

扫描 v1.10 中：

```text
Set-Content
Move-Item
Add-Content
Get-Content
ConvertFrom-Json
ConvertTo-Json
File.Open
```

针对生产状态文件相关的关键操作，确认：

```text
异常可控
tmp cleanup
lock handling
final status
```

特别搜索所有：

```text
return
```

逐个确认：

> 是否有可能在整轮失败后提前 return，而没有输出 `RUN_STATUS|failed|`。

这个检查非常重要。

本轮 P1 的本质就是“提前 return 导致最终状态缺失”，不能只检查已知 T38 行。

输出：

```text
early-return-final-status-audit.md
```

---

# 20. Final Invariant Verification

必须真实验证以下：

### I1

```text
atomic md replacement success
→ commitSucceeded=true
```

### I2

```text
commitSucceeded=true
+
lockReleased=true
→ RUN_STATUS|success|
```

### I3

```text
commitSucceeded=true
+
lockReleased=false
→ RUN_STATUS|failed|
```

### I4

```text
review write failure
→ no md commit
```

### I5

```text
review write failure
→ RUN_STATUS|failed|
```

### I6

```text
md replacement failure
→ main md unchanged
```

### I7

```text
failure
→ safe cleanup
+
lock handling
+
terminal failed status
```

---

# 21. Evidence Rules

每个实际测试至少保存：

```text
stdout.txt
stderr.txt
test-report.md
```

涉及文件：

```text
before/
after/
```

涉及 hash：

```text
sha256-before.txt
sha256-after.txt
```

涉及 lock：

```text
lock-before.txt
lock-after.txt
```

涉及 API：

```text
HTTP status
target headers
request count
```

禁止保存：

```text
GITHUB_TOKEN
Authorization
Cookie
完整 secrets
```

---

# 22. Self-Review

测试结束后执行独立 self-review。

生成：

```text
.selfreview/selfreview-v19.md
```

至少检查：

```text
1. 被测对象是否为真实 v1.10
2. 是否修改过 v1.10
3. 是否误用了旧 PASS
4. 是否存在旧 fixture
5. T38 是否真实命中失败分支
6. 每个 FAIL 是否有证据
7. 是否把 BLOCKED 写成 PASS
8. 是否把 FAIL 写成 BLOCKED
9. 报告数字是否一致
10. evidence 与结论是否一致
11. v1.9→v1.10 diff 是否真实
12. early return final status audit 是否完成
```

---

# 23. Final Report

生成：

```text
production-validation-report-v110-final.md
```

必须包含：

```text
A. Environment
B. Version / SHA256
C. v1.9 → v1.10 Diff Integrity
D. Targeted Test Summary
E. T38 Detailed Validation
F. Critical Findings
G. Invariant Verification
H. State Path Verification
I. PS7 Production Assessment
J. PS5.1 Compatibility Assessment
K. Runtime Error Contract Audit
L. Self-Review Findings
M. Evidence Index
N. Production Gate
O. Execution Summary
P. Remaining Limitations
```

---

# 24. Final Counting

不要假设固定测试总数。

根据实际执行项目统计：

```text
EXECUTED =
PASS =
FAIL =
BLOCKED =
```

必须：

```text
PASS + FAIL + BLOCKED = EXECUTED
```

---

# 25. Production Gate

## PRODUCTION_READY

必须同时：

```text
P0 = 0
P1 = 0
FAIL = 0
BLOCKED = 0
```

并且必须：

```text
T22 = PASS
T23 = PASS
T37 = PASS
T38 = PASS
T39 = PASS
T43 = PASS
T46 = PASS

T04-PS7 = PASS
Diff Integrity = PASS
Runtime Error Audit = PASS
Self-Review = PASS
```

---

## PRODUCTION_NOT_READY

任意：

```text
P0 > 0
P1 > 0
FAIL > 0
```

特别是：

```text
T38 FAIL
RUN_STATUS terminal state missing
主 md 被错误修改
lock ownership 错误
数据损坏
```

都必须：

```text
PRODUCTION_NOT_READY
```

---

## PRODUCTION_BLOCKED

仅当：

```text
P0 = 0
P1 = 0
FAIL = 0
BLOCKED > 0
```

才允许。

---

# 26. 最终执行摘要

报告必须明确：

```text
PS7 available:
PS7 executed:
PS5.1 available:
PS5.1 executed:

T22:
T23:
T37:
T38:
T39:
T43:
T46:

T04-PS7:
T04-PS5.1:
T05-PS7:
T05-PS5.1:

T26:
T18:
lock regression:
process kill:
runtime error audit:
diff integrity:
self-review:

FINAL_VERDICT:
```

---

# 27. 最终原则

```text
Git repository = 唯一事实源

SKILL-v1.10.md = 唯一被测对象

PowerShell 7.x = 生产主运行环境

PowerShell 5.1 = 兼容性回归环境

旧版本 PASS ≠ 当前版本 PASS

代码存在 ≠ 行为正确

关键失败路径必须真实注入

BLOCKED ≠ PASS

FAIL ≠ BLOCKED

不得修改被测 SKILL 来消除测试失败

证据优先于结论
```