# Production Validation Prompt — SKILL-v1.8 Targeted Regression Validation

## 目标

验证 `SKILL-v1.8.md` 是否修复 v1.7 已确认的 `$commitSucceeded` P1，并保持 v1.7 已验证能力不回归。

本轮不是自由探索、不是重构、不是修改 SKILL。

最终只能得到：

```text
PRODUCTION_READY
PRODUCTION_NOT_READY
PRODUCTION_BLOCKED
```

---

## 0. 唯一事实源与运行环境

Git 仓库：

```text
https://github.com/demonpiapia/github-version-monitor
```

被测文件：

```text
SKILL-v1.8.md
```

持久化状态文件：

```text
.output/GitHub更新监测列表.md
```

运行时目录：

```text
.monitor/
```

`.monitor` 是运行态，不作为本轮 Git 版本基线。

生产主运行环境：

```text
PowerShell 7.x on Windows
```

PowerShell 5.1 仅用于兼容性验证；其兼容性失败不得自动阻塞当前 PS7 生产准入。

---

## 1. Clean-Room

创建全新目录：

```text
<repo-root>\\.production-validation-v18-final\\
```

不得复用：

```text
.production-validation
.production-validation-v16-final
.production-validation-v17-final
```

禁止继承旧测试：

```text
result.json
run.lock
fixture
stdout
stderr
旧脚本
旧报告
```

历史测试仅允许用于背景参考，不得直接作为本轮 PASS 证据。

---

## 2. Git 完整性

确认：

```text
SKILL-v1.6.md
SKILL-v1.7.md
SKILL-v1.8.md
.output/GitHub更新监测列表.md
```

分别计算 SHA256。

生成：

```text
v16-v17.diff
v17-v18.diff
```

重点检查：

### v1.8 必须保留 v1.7 的能力

```text
versionJump
dateSuspicious
reviewReasons
result.fetch.tmp
result.review.tmp
schema validation
RUN_STATUS|success|
RUN_STATUS|failed|
404 -> not_found
rate_limited
Get-ResponseHeaderValue
lock heartbeat
lock ownership
atomic md commit
atomic result persistence
strict lowercase yes/no
```

### v1.8 允许新增/改变

```text
$commitSucceeded 修复
COMMIT_OK / RUN_STATUS invariant 加固
.output/GitHub更新监测列表.md 路径同步
Changelog
```

不得存在：

```text
mock API URL
forced success
test-only branch
debug bypass
hardcoded token
hardcoded test repository
skip lock
skip schema
skip commit
```

若发现非预期能力删除：

```text
P1
PRODUCTION_NOT_READY
```

---

# 3. 核心修复测试

## T37-v18 — 正常提交 → RUN_STATUS success

使用全新测试状态目录。

在 PowerShell 7 中执行完整流程。

必须真实观察：

```text
COMMIT_OK|
RUN_STATUS|success|
```

并确认：

```text
$commitSucceeded = $true
```

发生在 `Move-Item` 成功之后。

同时确认：

```text
lockReleased = true
```

### 硬门槛

如果出现：

```text
COMMIT_OK|
RUN_STATUS|failed|
```

则：

```text
FAIL
P1
PRODUCTION_NOT_READY
```

---

## T38-v18 — review write failure

在外部测试层阻塞：

```text
result.review.tmp
```

不得修改 SKILL。

期望：

```text
REVIEW_WRITE_ERROR|
no COMMIT_OK|
RUN_STATUS|failed|
```

主 md 不变。

---

## T39-v18 — commit success + lock release failure

必须真实触发：

```text
COMMIT_OK|
RUNTIME_ERROR|
RUN_STATUS|failed|
```

绝不能：

```text
RUN_STATUS|success|
```

---

# 4. T43-v18 Full Pipeline

建立全新 fixture，至少包含：

```text
normal upgrade
synced
uninstalled
unsupported version
404
versionJump
```

除明确 404 项外，repo 必须真实存在。

使用：

```text
PowerShell 7.x
.output/GitHub更新监测列表.md
```

完整执行 Step 1 → Step 6。

必须确认：

```text
BACKUP_OK|
FETCH_COMPLETE|
SUMMARY|
COMMIT_OK|
RUN_STATUS|success|
```

并确认主状态文件实际位于：

```text
.output/GitHub更新监测列表.md
```

而不是仓库根目录。

---

# 5. 状态路径回归

## T46-v18 — `.output` path contract

建立：

```text
.output/GitHub更新监测列表.md
```

不要在根目录创建同名状态文件。

运行完整 Step 1 / Step 2。

必须：

```text
读取 .output/GitHub更新监测列表.md
写回 .output/GitHub更新监测列表.md
```

根目录：

```text
GitHub更新监测列表.md
```

不得被创建。

如果根目录出现同名状态文件：

```text
FAIL
P1
```

---

# 6. v1.7 回归关键项

以下不能全部依赖历史报告，至少重新执行：

## T04-v18 — PS7 rate limited

真实：

```text
403
X-RateLimit-Remaining=0
```

期望：

```text
rate_limited
```

并确认：

```text
no retry
no Step4 API
no HTML
```

---

## T05-v18 — PS7 forbidden

```text
403
X-RateLimit-Remaining>0
```

期望：

```text
forbidden
```

---

## T08-v18 — network_error

必须在 PS7 中实际命中无 HTTP response 的错误路径。

不要只使用 PowerShell 5.1 proxy 行为推理。

---

## T18-v18 — preservation

至少实际验证：

```text
auth_error
forbidden
rate_limited
server_error
network_error
http_error
```

确认：

```text
gitVer unchanged
gitDate unchanged
flag unchanged
```

另外验证：

```text
404 -> not_found
```

其专用规则：

```text
gitVer=""
gitDate=""
flag=prevFlag
```

---

## T26-v18 — strict lowercase flag

必须重新验证：

```text
yes/no  -> valid
YES/Yes/yEs/NO/No -> invalid
```

必须 `PARSE_ERROR|`。

---

# 7. Schema / atomicity / lock 回归

至少重新执行：

```text
T20 result.json atomicity
T21 review atomicity
T22 md temp failure
T23 md replacement failure
T30 concurrency
T31 heartbeat
T33 stale + alive
T34 stale + dead
T35 ownership mismatch
T36 process kill
```

原则：

```text
历史 PASS 可以指导测试选择
但不能在本轮作为唯一 PASS 证据
```

---

# 8. PS5.1 compatibility

如果机器存在 PowerShell 5.1，则至少执行：

```text
T04-PS5.1
T05-PS5.1
```

验证：

```text
403 + remaining=0 -> rate_limited
403 + remaining>0 -> forbidden
```

如果 PS5.1 不存在：

```text
BLOCKED
```

不影响 PS7 production gate。

如果 PS5.1 存在但失败：

```text
记录 compatibility FAIL
不得隐瞒
```

但除非另有明确生产要求，不把它自动升级为 PS7 production P1。

---

# 9. Evidence 规则

所有执行过的测试至少保存：

```text
stdout.txt
stderr.txt
test-report.md
```

涉及状态文件：

```text
md-before.md
md-after.md
```

涉及 result：

```text
result-before.json
result-after.json
```

涉及 lock：

```text
lock-before.txt
lock-after.txt
```

涉及 atomicity：

```text
SHA256 before
SHA256 after
```

涉及 API：

```text
HTTP status
relevant header metadata
request count
```

不得保存：

```text
GITHUB_TOKEN
Authorization
Cookie
完整 secret
```

---

# 10. 测试脚本污染

本轮所有测试 harness 都必须位于：

```text
.production-validation-v18-final\\
```

测试脚本可以为测试环境服务，但：

```text
不得修改 SKILL-v1.8.md
不得修改生产 .output 状态文件
不得把修复写入 extracted production script 后再报告 PASS
```

如果为了让测试通过而修改了被测代码：

```text
该测试结果无效
重新测试
并在报告中披露
```

---

# 11. Final Gate

总测试项目按实际执行表统计，不要机械规定数量。

必须单独统计：

```text
PASS
FAIL
BLOCKED
```

以及：

```text
P0
P1
P2
```

## PRODUCTION_READY

只有同时满足：

```text
P0 = 0
P1 = 0
FAIL = 0
所有生产关键测试 PASS
T37-v18 PASS
T39-v18 PASS
T43-v18 PASS
T46-v18 PASS
v1.7 -> v1.8 diff integrity PASS
```

BLOCKED 的非生产关键兼容测试如果存在，不得把它隐藏，但应明确其范围；若任何生产关键项 BLOCKED，Production Gate 必须保持 CLOSED。

## PRODUCTION_NOT_READY

任意：

```text
P0 > 0
P1 > 0
FAIL > 0
```

尤其：

```text
正常提交仍 RUN_STATUS|failed|
.output 路径错误
rate_limited 分类错误
lock 错误
atomicity 错误
```

必须 NOT_READY。

## PRODUCTION_BLOCKED

仅当：

```text
P0=0
P1=0
FAIL=0
但关键生产测试存在 BLOCKED
```

---

# 12. 最终报告

生成：

```text
production-validation-report-v18-final.md
```

章节：

```text
A. Environment
B. Version / SHA256
C. v1.6 -> v1.7 -> v1.8 Diff Integrity
D. Runtime / State Path Contract
E. T37-v18 / T38-v18 / T39-v18
F. T04-v18 / T05-v18 / T08-v18 / T18-v18 / T26-v18
G. Schema / Atomicity / Lock Regression
H. T43-v18 Full Pipeline
I. PS5.1 Compatibility
J. Evidence Index
K. Critical Findings
L. Production Gate
M. Execution Summary
N. Remaining Limitations
```

最终必须明确：

```text
PS7 available: YES/NO
PS7 executed: YES/NO
PS5.1 available: YES/NO
PS5.1 executed: YES/NO

T04-PS7: PASS/FAIL/BLOCKED
T04-PS5.1: PASS/FAIL/BLOCKED
T05-PS7: PASS/FAIL/BLOCKED
T05-PS5.1: PASS/FAIL/BLOCKED
T08-PS7: PASS/FAIL/BLOCKED

T37-v18: PASS/FAIL/BLOCKED
T38-v18: PASS/FAIL/BLOCKED
T39-v18: PASS/FAIL/BLOCKED
T43-v18: PASS/FAIL/BLOCKED
T46-v18: PASS/FAIL/BLOCKED

v1.7->v1.8 diff integrity: PASS/FAIL/BLOCKED
state path contract: PASS/FAIL/BLOCKED
```

最后严格输出：

```text
VERSION: v1.8
PRIMARY_RUNTIME: PowerShell 7.x

PASS: N
FAIL: N
BLOCKED: N

P0: N
P1: N
P2: N

PRODUCTION_GATE: OPEN | CLOSED

FINAL_VERDICT:
PRODUCTION_READY
```

或：

```text
FINAL_VERDICT:
PRODUCTION_NOT_READY
```

或：

```text
FINAL_VERDICT:
PRODUCTION_BLOCKED
```

禁止根据预期结果填写 Verdict。Verdict 必须由实际证据决定。
