# Production Validation Prompt
## GitHub Version Monitor — SKILL-v1.9 Targeted Final Validation

你现在执行：

> **SKILL-v1.9 的定向生产验证。**

本轮测试对象唯一确定为：

```text
SKILL-v1.9.md
```

生产主运行环境：

```text
Windows
PowerShell 7.x
```

PowerShell 5.1：

```text
仅做兼容性回归
不作为当前生产准入主环境
```

---

# 0. 核心目标

v1.8 已通过正常提交、PS7/PS5.1 header compatibility、核心状态机等测试，但发现 3 个 P2：

```text
T38:
Step 4 result.review.tmp 写入异常
→ 异常冒泡
→ lock 残留

T22:
Step 5 md.tmp 创建/写入异常
→ 异常冒泡
→ lock 残留

T23:
Step 5 Move-Item 原子替换异常
→ tmp 残留
→ lock 残留
```

v1.9 的唯一修复目标：

```text
任何上述异常
        ↓
不污染主状态
        ↓
清理能够安全清理的 tmp
        ↓
正确处理 lock
        ↓
输出明确失败状态
        ↓
不得伪装 success
```

不得扩大测试范围后偷偷修改 SKILL。

---

# 1. Clean-Room

新建：

```text
.production-validation-v19-final/
```

禁止复用：

```text
.production-validation/
.production-validation-v17-final/
.production-validation-v18-final/
```

中的实际测试状态作为当前 PASS 证据。

可以参考旧报告，但：

```text
OLD_EVIDENCE_USED_AS_CURRENT_PASS = NO
```

---

# 2. 被测文件来源

必须从当前 Git repository 获取：

```text
SKILL-v1.8.md
SKILL-v1.9.md
```

以及生产状态：

```text
.output/GitHub更新监测列表.md
```

运行态：

```text
.monitor/
```

必须在测试目录重新生成。

不得使用聊天中的旧副本。

---

# 3. Git / SHA256

计算：

```powershell
Get-FileHash .\SKILL-v1.8.md -Algorithm SHA256
Get-FileHash .\SKILL-v1.9.md -Algorithm SHA256
Get-FileHash .\.output\GitHub更新监测列表.md -Algorithm SHA256
```

保存：

```text
v18.sha256
v19.sha256
state.sha256
```

---

# 4. v1.8 → v1.9 Diff Integrity

生成：

```text
v18-v19.diff
```

必须确认 v1.9 保留 v1.8 的全部关键能力：

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

特别检查：

> 不得因 v1.9 修复异常路径而删除任何 v1.8 已验证能力。

禁止：

```text
mock URL
forced success
test-only branch
debug bypass
hardcoded token
hardcoded test repo
skip lock
skip schema
skip review
skip commit
```

保存：

```text
diff-integrity.md
```

---

# 5. T23 — md atomic replacement failure

这是 v1.9 三个修复中最重要的异常路径之一。

构造：

```text
GitHub更新监测列表.md.tmp
```

并使：

```text
Move-Item -Path $tmp -Destination $md -Force
```

真实失败。

例如使用外部文件锁：

```text
exclusive/shared file lock
```

不得修改 SKILL。

验证：

```text
主 md unchanged
tmp 是否被清理
lock 是否被释放
有没有 COMMIT_OK
有没有 RUN_STATUS|failed|
有没有 RUN_STATUS|success|
```

期望：

```text
主 md = unchanged
tmp = cleaned
lock = released
COMMIT_OK = absent
RUN_STATUS|failed| = present
RUN_STATUS|success| = absent
```

如果 v1.9 的具体错误策略明确允许 tmp 保留，也必须严格按照 SKILL 实际 contract 判断；不能自行假设。

---

# 6. T22 — md temporary write failure

使：

```text
$md.tmp
```

创建或写入失败。

例如：

```text
read-only directory
external file lock
```

验证：

```text
主 md unchanged
tmp 不产生错误残留
lock released
RUN_STATUS|failed|
```

重点：

> 异常必须被捕获，不能直接冒泡导致执行上下文异常终止。

---

# 7. T38 — review write failure

使：

```text
result.review.tmp
```

无法：

```text
Set-Content
```

或原子替换失败。

验证：

```text
result.json unchanged
stats unchanged
items unchanged

tmp cleaned
lock released

REVIEW_WRITE_ERROR|
RUN_STATUS|failed|

no COMMIT_OK
no RUN_STATUS|success|
```

重点检查：

> 异常必须经过明确错误分支，而不是直接退出脚本。

---

# 8. 失败路径统一性测试

对 T22 / T23 / T38 分别保存：

```text
before/
after/
stdout.txt
stderr.txt
test-report.md
```

涉及文件必须保存 SHA256：

```text
main md
result.json
tmp
```

至少：

```text
sha256-before.txt
sha256-after.txt
```

---

# 9. T37 — 正常成功回归

必须确认 v1.9 修复没有破坏正常成功路径。

PowerShell 7.x：

```text
完整 Step 1-6
```

期望：

```text
BACKUP_OK|
FETCH_COMPLETE|
SUMMARY|
REVIEW_WRITE_OK|（有 review 时）
COMMIT_OK|
RUN_STATUS|success|
```

必须确认：

```text
lock released
md updated
result.json valid
```

---

# 10. T39 — Commit success + lock release failure

重新验证：

```text
COMMIT_OK|
RUNTIME_ERROR|
RUN_STATUS|failed|
```

必须确认：

```text
never RUN_STATUS|success|
```

即：

```text
commitSucceeded = true
lockReleased = false
        ↓
RUN_STATUS|failed|
```

---

# 11. T43 — Full Extended Pipeline

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

真实 repo：

```text
除明确 404 fixture 外，必须确认仓库真实存在
```

执行：

```text
Step1
Step2
Step3
Step4
Step5
Step6
```

最终：

```text
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

数据一致。

---

# 12. T46 — .output state path regression

确认：

```text
.output/GitHub更新监测列表.md
```

是唯一生产状态文件。

验证：

```text
根目录不存在 GitHub更新监测列表.md
```

并确认：

```text
读取 .output/
写回 .output/
backup 基于 .output 状态文件
```

不得重新使用：

```text
.\GitHub更新监测列表.md
```

---

# 13. PS5.1 Compatibility Regression

如果系统存在：

```text
powershell.exe 5.1
```

至少执行：

```text
T04-PS5.1
T05-PS5.1
```

验证：

```text
403 + remaining=0 -> rate_limited
403 + remaining>0 -> forbidden
```

以及：

```text
Get-ResponseHeaderValue
```

在：

```text
System.Net.WebHeaderCollection
```

下仍然工作。

PS5.1 失败：

```text
记录 compatibility FAIL
```

但：

```text
不自动阻塞 PS7 production gate
```

---

# 14. Strict Schema Regression

快速回归：

```text
valid yes
valid no

YES
Yes
yEs
NO
No
pending
true
```

非法：

```text
PARSE_ERROR|
```

并确认：

```text
main md unchanged
lock released
```

---

# 15. Lock Regression

重新验证：

### Concurrency

```text
two PS7 processes
```

期望：

```text
one owner
one LOCKED
```

### Ownership

foreign PID：

```text
RUNTIME_ERROR
foreign lock retained
```

### Stale alive

```text
heartbeat > 30 min
PID alive
→ LOCKED
```

### Stale dead

```text
heartbeat > 30 min
PID dead
→ takeover
```

---

# 16. State Machine Regression

至少重新验证：

```text
T02 404 -> not_found
T04 rate_limited
T05 forbidden
T08 network_error
T14 incomparable
T15 versionJump
T16 dateSuspicious
T17 isFlip
T18 state preservation
T19 uninstalled
```

不需要重新建立完整历史测试矩阵，但必须真正运行关键路径。

---

# 17. Runtime Error Contract

重点检查所有异常路径：

```text
Step 1
Step 2
Step 3
Step 4
Step 5
```

是否存在：

```text
try/catch
cleanup
lock release
final status
```

特别搜索：

```text
Set-Content
Move-Item
Add-Content
ConvertFrom-Json
ConvertTo-Json
Get-Content
File.Open
```

对每个会导致生产状态改变的关键文件操作，检查：

```text
异常是否被处理
```

但：

> 静态检查只能作为辅助，T22/T23/T38 必须实际执行。

---

# 18. v1.9 必须证明的核心 invariant

### Invariant 1

```text
主 md 只有 atomic replacement 成功后才算提交成功
```

### Invariant 2

```text
Move-Item success
    ↓
commitSucceeded=true
```

### Invariant 3

```text
commitSucceeded=true
AND
lockReleased=true
    ↓
RUN_STATUS|success|
```

### Invariant 4

```text
commitSucceeded=true
AND
lockReleased=false
    ↓
RUN_STATUS|failed|
```

### Invariant 5

```text
review write failure
    ↓
no md commit
```

### Invariant 6

```text
md commit failure
    ↓
main md remains unchanged
```

### Invariant 7

```text
failure
    ↓
tmp cleanup where defined safe
+
lock release where ownership confirmed
+
RUN_STATUS|failed|
```

如果 v1.9 中任何 invariant 与代码行为不一致：

```text
FAIL
```

---

# 19. Evidence Rules

每项测试至少：

```text
stdout.txt
stderr.txt
test-report.md
```

涉及文件：

```text
before
after
SHA256
```

涉及 lock：

```text
lock-before
lock-after
```

涉及最终状态：

```text
actual final output
```

涉及 API：

```text
actual HTTP status
actual relevant headers
request count
```

绝对禁止：

```text
GITHUB_TOKEN
Authorization
Cookie
完整 secret
```

---

# 20. 不得修改被测 Skill

整个测试过程中：

```text
SKILL-v1.9.md
```

禁止修改。

如果发现 bug：

```text
记录
停止对应结论
继续独立测试
```

不能：

```text
修改 → 重跑 → 当成原始 PASS
```

---

# 21. Self-Review

测试完成后执行一次独立 self-review。

必须检查：

```text
有没有测试对象修改
有没有旧 evidence 被当作当前 PASS
有没有 fixture 错误
有没有测试脚本修改导致假 PASS
有没有 FAIL 被写成 BLOCKED
有没有 BLOCKED 被写成 PASS
有没有报告数字不一致
有没有证据与结论矛盾
```

生成：

```text
.selfreview/production-validation-selfreview.md
```

---

# 22. Final Report

生成：

```text
production-validation-report-v19-final.md
```

必须包含：

```text
A. Environment
B. Version / SHA256
C. v1.8 -> v1.9 Diff Integrity
D. Targeted Test Summary
E. Critical Findings
F. Evidence Index
G. Invariant Verification
H. State Path Verification
I. PS7 Production Assessment
J. PS5.1 Compatibility Assessment
K. Self-Review Findings
L. Production Gate
M. Execution Summary
N. Remaining Limitations
```

---

# 23. Final Counting

本轮不再假设固定 46 项。

必须按照**实际执行的测试项目**统计：

```text
Executed =
PASS =
FAIL =
BLOCKED =
```

并确保：

```text
PASS + FAIL + BLOCKED = Executed
```

不要人为加入不存在的测试编号。

---

# 24. Production Gate

## PRODUCTION_READY

必须：

```text
P0 = 0
P1 = 0
FAIL = 0
BLOCKED = 0
```

且：

```text
T22 PASS
T23 PASS
T38 PASS
T37 PASS
T39 PASS
T43 PASS
T46 PASS
Diff Integrity PASS
Self-Review PASS
```

同时：

```text
PS7 primary runtime PASS
```

---

## PRODUCTION_NOT_READY

任意：

```text
P0 > 0
P1 > 0
FAIL > 0
```

尤其：

```text
T22 FAIL
T23 FAIL
T38 FAIL
T37 FAIL
T39 FAIL
T43 FAIL
```

必须：

```text
PRODUCTION_NOT_READY
```

---

## PRODUCTION_BLOCKED

只有：

```text
P0 = 0
P1 = 0
FAIL = 0
BLOCKED > 0
```

才允许：

```text
PRODUCTION_BLOCKED
```

---

# 25. Final Execution Summary

必须明确回答：

```text
PS7 available:
PS7 executed:
PS5.1 available:
PS5.1 executed:

Real GitHub API:
Mock HTTP:

T04-PS7:
T04-PS5.1:
T05-PS7:
T05-PS5.1:

T22:
T23:
T37:
T38:
T39:
T43:
T46:

Concurrency:
Process Kill:
result atomicity:
review atomicity:
md atomicity:
lock release failure:
state path verification:
diff integrity:
self-review:
```

---

# 26. 最终结论

报告最后严格输出：

```text
VERSION: v1.9

EXECUTED: N
PASS: N
FAIL: N
BLOCKED: N

P0: N
P1: N
P2: N

PRIMARY_RUNTIME: PowerShell 7.x

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

并给出：

```text
REPORT:
<production-validation-report-v19-final.md 完整路径>
```

最终原则：

```text
Git repository = 唯一事实源
证据优先于结论
实际执行优先于静态推理
FAIL 不得改写为 BLOCKED
BLOCKED 不得改写为 PASS
旧版本证据不得冒充新版本证据
不得修改被测 SKILL 来消除测试失败
```