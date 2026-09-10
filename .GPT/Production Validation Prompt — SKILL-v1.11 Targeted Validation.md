# Production Validation Prompt
## GitHub Version Monitor — SKILL-v1.11 Targeted Validation

你现在执行：

> **SKILL-v1.11 的定向生产验证。**

本轮目标：

```text
验证 v1.11 是否真正修复 v1.10 的 P1：
T38-stats-items 路径只能产生一个 RUN_STATUS|failed|，
并确认该修复没有破坏 v1.10 已通过的关键能力。
```

本轮：

```text
禁止修改 SKILL-v1.11.md
禁止为了 PASS 修改测试逻辑掩盖失败
禁止继承旧 PASS 作为本轮 PASS
```

---

# 0. Production Runtime

当前生产主环境：

```text
Windows
PowerShell 7.x
```

PS5.1：

```text
仅做兼容性回归
不作为 production gate 主环境
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

建立：

```text
.production-validation-v111-final/
```

禁止直接复用：

```text
.production-validation-v110-final/
.production-validation-v19-final/
其他历史 validation 目录
```

历史证据只可参考：

```text
OLD_EVIDENCE_USED_AS_CURRENT_PASS = NO
```

本轮所有 fixture、runtime state、result.json、lock、stdout、stderr 必须重新建立。

---

# 2. 被测对象来源

必须从当前 Git repository 获取：

```text
SKILL-v1.11.md
SKILL-v1.10.md
.output/GitHub更新监测列表.md
```

不得使用聊天中的文件副本。

---

# 3. Baseline SHA256

计算：

```powershell
Get-FileHash .\SKILL-v1.10.md -Algorithm SHA256
Get-FileHash .\SKILL-v1.11.md -Algorithm SHA256
Get-FileHash .\.output\GitHub更新监测列表.md -Algorithm SHA256
```

保存：

```text
v110.sha256
v111.sha256
state.sha256
```

验证结束后再次计算，确认被测对象和生产状态未被测试修改。

---

# 4. v1.10 → v1.11 Diff Integrity

生成：

```text
v110-v111.diff
```

必须确认：

## v1.11 保留 v1.10 的关键能力

至少：

```text
.output/GitHub更新监测列表.md
.monitor/

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

Get-ResponseHeaderValue
PS7 production baseline
PS5.1 compatibility
```

## v1.11 允许的核心变化

只能是：

```text
Step 4 stats/items integrity failure
    ↓
输出 RUN_STATUS|failed|
    ↓
立即 return
```

以及与该修复直接相关的：

```text
documentation
invariant
changelog
```

如果发现其他关键能力被删除、重构或语义改变：

```text
FAIL
```

特别检查：

```text
versionJump
dateSuspicious
schema
not_found
atomicity
lock
RUN_STATUS
.output
```

不得只检查“关键词还存在”。

---

# 5. T38-stats-items — 本轮最高优先级

这是 v1.11 的硬门槛。

必须真实制造：

```text
review 阶段 stats/items 完整性检查失败
```

推荐方法：

```text
同进程 harness
```

篡改：

```text
$doc.stats
或
$doc.items
```

使：

```text
$newStatsJson != $origStatsJson
```

然后执行被测 Step 4。

期望：

```text
RUN_STATUS|failed| count = 1
```

不是：

```text
0
2
```

必须同时出现：

```text
REVIEW_WRITE_ERROR|
```

并且：

```text
不存在第二次 RUN_STATUS|failed|
不存在 RUN_STATUS|success|
不存在继续执行后续 review write
```

---

# 6. T38-stats-items 精确行为链

必须实际证明：

```text
stats/items integrity failure
        ↓
REVIEW_WRITE_ERROR
        ↓
RUN_STATUS|failed|
        ↓
return
        ↓
Step 4 终止
```

而不能出现：

```text
RUN_STATUS|failed|
↓
继续执行
↓
第二个 REVIEW_WRITE_ERROR
↓
第二个 RUN_STATUS|failed|
```

最终验证：

```text
RUN_STATUS_COUNT = 1
```

这是 v1.11 的核心接受标准。

---

# 7. T38-A — review tmp 写入失败

重新执行。

验证：

```text
REVIEW_WRITE_ERROR|
RUN_STATUS|failed| count=1
```

同时：

```text
no COMMIT_OK
no RUN_STATUS|success|
result.json 不损坏
stats/items 不改变
主 md 不变
tmp cleanup 正确
lock handling 正确
```

---

# 8. T38-B — review JSON validation failure

注入：

```text
非法 review JSON
```

必须：

```text
REVIEW_WRITE_ERROR|
RUN_STATUS|failed| count=1
```

不能：

```text
继续执行到下一错误路径
产生第二个 RUN_STATUS
```

---

# 9. T38-C — review atomic replacement failure

阻止：

```text
result.review.tmp
→ result.json
```

验证：

```text
REVIEW_WRITE_ERROR|
RUN_STATUS|failed| count=1
no COMMIT_OK
lock safe
result.json safe
```

---

# 10. T38-heartbeat

使 Step 4 heartbeat 失败。

期望：

```text
RUNTIME_ERROR|
RUN_STATUS|failed| count=1
```

---

# 11. T38-result-read

使：

```text
result.json
```

无法读取。

期望：

```text
RUNTIME_ERROR|
RUN_STATUS|failed| count=1
```

---

# 12. T38 全部子测试的统一检查

对：

```text
T38-A
T38-B
T38-C
T38-heartbeat
T38-result-read
T38-stats-items
```

每项分别统计：

```text
RUN_STATUS|success| count
RUN_STATUS|failed| count
REVIEW_WRITE_ERROR count
RUNTIME_ERROR count
COMMIT_OK count
```

统一要求：

```text
failed count = 1
success count = 0
```

并且错误路径不能发生重复 final status。

---

# 13. T22 — md temp write failure

验证：

```text
main md unchanged
tmp cleanup
lock released
RUN_STATUS|failed| count=1
```

---

# 14. T23 — md atomic replacement failure

验证：

```text
main md unchanged
tmp cleanup
lock released
RUN_STATUS|failed| count=1
```

---

# 15. T37 — normal success regression

PowerShell 7.x。

执行完整：

```text
Step1
Step2
Step3
Step4
Step5
Step6
```

必须：

```text
BACKUP_OK|
FETCH_COMPLETE|
SUMMARY|
REVIEW_WRITE_OK|（存在 review 时）
COMMIT_OK|
RUN_STATUS|success| count=1
```

必须：

```text
RUN_STATUS|failed| count=0
lock released
md updated
result.json valid
```

---

# 16. T39 — commit success + lock release failure

再次验证：

```text
commitSucceeded=true
lockReleased=false
```

必须：

```text
COMMIT_OK|
RUNTIME_ERROR|
RUN_STATUS|failed| count=1
RUN_STATUS|success| count=0
```

确保 v1.11 没破坏 v1.10 已通过的 invariant。

---

# 17. T43 — full extended pipeline

建立全新 fixture。

至少包含：

```text
normal upgrade
synced
uninstalled
unsupported version
404
versionJump
```

除 404 外 repo 必须真实存在。

PowerShell 7.x。

验证：

```text
BACKUP_OK|
FETCH_COMPLETE|
SUMMARY|
REVIEW_WRITE_OK|（有 review）
COMMIT_OK|
RUN_STATUS|success|
```

同时确认：

```text
.output/GitHub更新监测列表.md
```

才是生产状态路径。

---

# 18. T46 — .output path regression

确认：

```text
.output/GitHub更新监测列表.md
```

唯一生产状态文件。

确认：

```text
根目录不存在 GitHub更新监测列表.md
```

验证：

```text
读取 .output/
写回 .output/
backup 基于 .output/
```

---

# 19. T04 — rate_limited regression

PowerShell 7.x：

```text
403
X-RateLimit-Remaining=0
```

必须：

```text
rate_limited
```

请求：

```text
latest = 1
review API = 0
HTML = 0
retry = 0
```

---

# 20. T04 / T05 — PS5.1 compatibility regression

如果 PS5.1 存在：

### T04-PS5.1

```text
403 + remaining=0
→ rate_limited
```

### T05-PS5.1

```text
403 + remaining>0
→ forbidden
```

PS5.1 不得阻塞 PS7 production gate。

---

# 21. T26 — strict flag regression

验证：

```text
yes
no
```

合法。

以下：

```text
YES
Yes
yEs
NO
No
pending
true
```

全部：

```text
PARSE_ERROR|
```

---

# 22. T18 — state preservation regression

至少：

```text
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

验证：

除 not_found 外：

```text
gitVer unchanged
gitDate unchanged
flag unchanged
```

not_found：

```text
gitVer=""
gitDate=""
flag=prevFlag
review=true
```

---

# 23. Lock regression

重新至少测试：

```text
concurrency
ownership
stale + alive
stale + dead
process kill
```

要求与 v1.10 已验证行为一致。

特别：

```text
一次正常 success：
lock released

一次 failure：
lock safe

foreign ownership：
不得删除 foreign lock
```

---

# 24. Runtime artifact initialization

这是之前的历史验证缺口，本轮必须保留真实证据。

测试开始时：

```text
.monitor 不存在
```

从 Step 1 开始由 SKILL 自己创建。

验证实际生成：

```text
.monitor/
run.lock
backups/
result.json
fetch_run.log
```

涉及 review 时：

```text
result.review.tmp
```

真实出现。

正常结束：

```text
run.lock 不存在
```

不得由测试 harness 预先创建 `.monitor` 来掩盖 Skill 的初始化逻辑。

---

# 25. Process Kill

至少一次。

PowerShell 7.x。

在：

```text
Step2
Step4
Step5
```

至少一个实际执行点杀进程。

然后新一轮：

```text
stale/dead lock
takeover
```

验证。

---

# 26. Early Return Audit

扫描：

```text
SKILL-v1.11.md
```

所有：

```text
return
```

必须分类：

```text
正常控制流 return
函数 return
fatal return
```

对于 fatal return：

必须确认：

```text
terminal status already emitted exactly once
```

输出：

```text
early-return-final-status-audit.md
```

重点检查：

```text
Step1
Step2
Step3
Step4
Step5
```

不能只检查本次修复的 L480。

---

# 27. Final Status Uniqueness Audit

新增硬性检查：

对所有 fatal test：

```text
RUN_STATUS|success|
RUN_STATUS|failed|
```

统计总数。

规则：

```text
正常 success：
success=1
failed=0

失败：
success=0
failed=1
```

如果出现：

```text
success>1
failed>1
success + failed != 1
```

均：

```text
FAIL
P1
```

---

# 28. Diff / Behavioral Integrity

必须同时进行：

```text
Structural diff
+
Behavioral regression
```

特别：

> “代码关键词仍存在”不能证明行为没有回归。

至少用：

```text
T37
T38
T39
T43
```

证明行为完整。

---

# 29. Evidence Rules

每项测试至少：

```text
stdout.txt
stderr.txt
test-report.md
```

涉及状态：

```text
md-before.md
md-after.md
result-before.json
result-after.json
lock-before.txt
lock-after.txt
```

涉及 atomicity：

```text
sha256-before.txt
sha256-after.txt
```

涉及 API：

```text
status
relevant headers
request count
```

禁止：

```text
GITHUB_TOKEN
Authorization
Cookie
完整 secrets
```

---

# 30. Test Harness Integrity

测试过程中允许修复：

```text
orchestrator
wrapper
fixture
report generator
```

但每次修复必须：

```text
记录时间
记录原因
说明不属于被测 SKILL
重新执行受影响测试
```

严禁：

```text
修改 SKILL-v1.11.md
修改后重新标记原测试 PASS
```

如果测试 harness 自身产生错误：

```text
先修 harness
再重新执行对应测试
旧证据不覆盖新证据
```

---

# 31. Self-Review

生成：

```text
.selfreview/selfreview-v111-YYYYMMDD-HHMMSS.md
```

注意：

> 文件名必须带实际时间戳。

检查：

```text
1. 被测对象是否真实为 v1.11
2. SHA256 是否一致
3. 是否修改过 v1.11
4. 是否复用了旧 PASS
5. T38-stats-items 是否真实命中
6. RUN_STATUS|failed| 是否恰好一次
7. T22/T23/T37/T39/T43 是否重新执行
8. .monitor 是否由 SKILL 自己创建
9. .output path 是否正确
10. 是否存在证据与结论矛盾
11. 是否存在 FAIL 被改写为 BLOCKED
12. 是否存在 BLOCKED 被改写为 PASS
13. diff 是否包含非预期删除
14. early-return audit 是否完成
15. final-status uniqueness audit 是否完成
```

---

# 32. Final Report

生成：

```text
production-validation-report-v111-final.md
```

必须包含：

```text
A. Environment
B. Version / SHA256
C. v1.10 → v1.11 Diff Integrity
D. T38 Detailed Validation
E. Targeted Regression Summary
F. Runtime Artifact Validation
G. Final Status Uniqueness Audit
H. Early Return Audit
I. Invariant Verification
J. PS7 Production Assessment
K. PS5.1 Compatibility Assessment
L. Self-Review
M. Evidence Index
N. Production Gate
O. Execution Summary
P. Remaining Limitations
```

---

# 33. Final Counting

不要预设测试总数。

按照实际执行：

```text
EXECUTED =
PASS =
FAIL =
BLOCKED =
```

并确保：

```text
PASS + FAIL + BLOCKED = EXECUTED
```

每个测试项目只能有一个最终状态。

---

# 34. Production Gate

## PRODUCTION_READY

必须同时满足：

```text
P0 = 0
P1 = 0
FAIL = 0
BLOCKED = 0
```

并且：

```text
T38-stats-items = PASS
T22 = PASS
T23 = PASS
T37 = PASS
T39 = PASS
T43 = PASS
T46 = PASS

T04-PS7 = PASS
T26 = PASS
T18 = PASS

Runtime artifact initialization = PASS
Early Return Audit = PASS
Final Status Uniqueness Audit = PASS
Diff Integrity = PASS
Self-Review = PASS
```

尤其：

```text
T38-stats-items
RUN_STATUS|failed| count = 1
```

是硬门槛。

---

# 35. PRODUCTION_NOT_READY

任意：

```text
P0 > 0
P1 > 0
FAIL > 0
```

必须：

```text
PRODUCTION_NOT_READY
```

尤其：

```text
RUN_STATUS 重复
RUN_STATUS 缺失
正常成功输出 failed
失败路径输出 success
```

全部至少 P1。

---

# 36. PRODUCTION_BLOCKED

只有：

```text
P0=0
P1=0
FAIL=0
BLOCKED>0
```

允许：

```text
PRODUCTION_BLOCKED
```

---

# 37. Final Execution Summary

必须明确：

```text
PS7 available:
PS7 executed:

PS5.1 available:
PS5.1 executed:

T38-stats-items:
T38-A:
T38-B:
T38-C:
T38-heartbeat:
T38-result-read:

T22:
T23:
T37:
T39:
T43:
T46:

T04-PS7:
T04-PS5.1:
T05-PS5.1:

T26:
T18:

lock regression:
process kill:
.monitor initialization:
.output path:
early-return audit:
final-status uniqueness audit:
diff integrity:
self-review:
```

---

# 38. Final Output

最后输出：

```text
VERSION: v1.11

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

以及：

```text
REPORT:
<production-validation-report-v111-final.md>
```

---

# 39. Absolute Rules

```text
Git repository = 唯一事实源
SKILL-v1.11.md = 唯一被测对象
PowerShell 7.x = 生产主运行环境
PS5.1 = 兼容性回归
.monitor = 必须由 SKILL 自己初始化
.output = 唯一生产状态路径

代码存在 != 行为正确
旧 PASS != 当前 PASS
BLOCKED != PASS
FAIL != BLOCKED

不修改被测 SKILL
不篡改旧证据
不隐藏失败
不允许重复 RUN_STATUS
不允许缺失 RUN_STATUS
```