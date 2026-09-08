# Production Validation Prompt
## GitHub Version Monitor — SKILL-v1.7 Clean-Room Final Validation

你现在执行的是：

> **SKILL-v1.7 的独立生产准入验证。**

这是一个全新测试轮次。

本轮目标不是优化、重构或修复 SKILL，而是：

```text
验证：
SKILL-v1.7
是否满足当前真实生产环境的生产准入条件。
```

如果发现问题：

```text
必须记录
必须保留证据
不得修改被测 SKILL
不得为了 PASS 而调整测试结果
```

---

# 0. 当前生产环境定义

当前真实生产执行环境：

```text
PRIMARY RUNTIME:
PowerShell 7.x

TARGET ENVIRONMENT:
Windows

PS5.1:
仅作兼容性验证
不是生产准入的主要运行环境
```

因此：

> 所有生产行为测试默认必须优先在 PowerShell 7.x 完成。

PowerShell 5.1 仅用于：

```text
兼容性
header handling
字符串/文件处理差异
已知运行时差异
```

不得因为 PS5.1 的历史兼容性问题阻塞当前 PS7 生产准入，除非测试目标明确要求 PS5.1。

---

# 1. Clean-Room 测试目录

必须新建：

```text
<repo-root>\.production-validation-v17-final\
```

例如：

```text
D:\AI\Workspace\automatic\github-version-monitor\.production-validation-v17-final\
```

禁止直接复用：

```text
.production-validation\
.production-validation-v16-final\
任何历史 validation 目录
```

禁止复制旧测试：

```text
result.json
run.lock
fixture
stdout
stderr
test scripts
reports
```

旧测试目录可以保留，但：

```text
OLD_TEST_EVIDENCE_USED_AS_CURRENT_PASS = NO
```

---

# 2. 被测文件来源

被测对象必须来自当前 Git repository：

```text
SKILL-v1.7.md
```

同时获取：

```text
SKILL-v1.6.md
```

用于 diff。

不得：

```text
使用聊天缓存文件
使用历史下载文件
使用上轮 validation 目录中的复制品
自行重建 v1.7
```

---

# 3. Git 基线验证

首先：

```text
确认 repository
确认 branch
确认 commit
确认 SKILL-v1.6.md
确认 SKILL-v1.7.md
```

计算：

```powershell
Get-FileHash .\SKILL-v1.6.md -Algorithm SHA256
Get-FileHash .\SKILL-v1.7.md -Algorithm SHA256
```

保存：

```text
v16.sha256
v17.sha256
```

---

# 4. v1.6 → v1.7 diff integrity

必须生成：

```text
v16-v17.diff
```

使用真实 Git diff：

```powershell
git diff --no-index -- SKILL-v1.6.md SKILL-v1.7.md
```

或者等价逐字节 diff。

必须检查：

### v1.7 不得丢失 v1.6 以下能力

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
lock heartbeat
lock ownership
atomic md commit
atomic result persistence
strict lowercase yes/no
```

### v1.7 允许增加

```text
Get-ResponseHeaderValue
PS5.1 / PS7 HTTP header compatibility
T04 rate_limited compatibility fix
生产环境说明
v1.7 changelog
```

### 不允许出现

```text
mock URL
localhost production bypass
debug bypass
test-only branch
hardcoded test repository
hardcoded token
forced success
forced rate_limited
skip schema
skip lock
skip review
skip commit
```

如果 diff 中发现任何非预期删除：

```text
FAIL
P1
PRODUCTION_NOT_READY
```

---

# 5. 版本完整性测试

测试报告必须说明：

```text
v1.7 是从仓库 v1.6 正确派生
```

不能仅依据 Changelog 判断。

必须由：

```text
真实 diff
```

证明。

---

# 6. 环境测试

## T00-A — PowerShell 7

输出：

```text
$PSVersionTable
$PWD
whoami
Get-FileHash
```

必须证明：

```text
PowerShell major >= 7
```

这是生产主证据。

---

## T00-B — PowerShell 5.1

如系统存在：

```powershell
powershell.exe -NoProfile -Command "$PSVersionTable"
```

记录版本。

PS5.1 不存在：

```text
不判失败
```

记录：

```text
PS5.1_COMPATIBILITY_ENVIRONMENT = UNAVAILABLE
```

---

# 7. 测试判定规则

每个测试只能：

```text
PASS
FAIL
BLOCKED
```

PASS 必须同时满足：

```text
实际执行
+
实际目标状态
+
实际结果
+
证据
```

以下不能 PASS：

```text
代码阅读
理论正确
旧版本测试结果
“应该能工作”
目标状态没有真实出现
```

---

# 8. T01 — 正常 200

使用真实 GitHub 仓库。

主环境：

```text
PowerShell 7.x
```

验证：

```text
queryStatus=ok
latest 非空
publishedUtc 非空
gitVer 正确
gitDate 正确
flag 正确
```

保存：

```text
T01\
```

---

# 9. T02 — 404 / not_found

真实不存在的仓库。

验证：

```text
queryStatus=not_found
gitVer=""
gitDate=""
flag == prevFlag
review=true
reviewReasons 包含 not_found
```

并确认：

```text
不会把错误信息写进 gitVer
不会把 HTML 结果作为 API 事实
```

---

# 10. T03 — 401

使用真实无效认证。

期望：

```text
auth_error
gitVer 保留
gitDate 保留
flag 保留
review=true
```

---

# 11. T04 — v1.7 核心测试：403 + remaining=0

这是本版本最高优先级。

## 11.1 主生产环境

必须首先在：

```text
PowerShell 7.x
```

测试。

通过外部网络层 / mock HTTP harness 产生：

```text
HTTP 403
X-RateLimit-Remaining: 0
```

不得修改：

```text
SKILL-v1.7.md
```

期望：

```text
queryStatus=rate_limited
```

---

## 11.2 请求预算验证

实际统计：

```text
latest API = 1
review releases API = 0
HTML diagnostic = 0
retry = 0
```

必须证明：

```text
403 + remaining=0
        ↓
rate_limited
        ↓
no retry
no Step4
no extra API
no HTML
```

---

## 11.3 PowerShell 5.1 compatibility

如果环境存在 PS5.1：

重复 T04。

验证：

```text
PowerShell 5.1
403
X-RateLimit-Remaining=0
↓
rate_limited
```

如果 PS5.1 不存在：

```text
BLOCKED
```

但不能影响 PS7 生产准入。

---

# 12. T05 — 403 + remaining>0

产生：

```text
403
X-RateLimit-Remaining > 0
```

必须：

```text
forbidden
```

不能：

```text
rate_limited
```

分别在：

```text
PS7
PS5.1（若存在）
```

验证。

---

# 13. T06 — 429

产生真实：

```text
429
```

期望：

```text
rate_limited
no retry
no Step4
```

---

# 14. T07 — 5xx

产生：

```text
500
```

期望：

```text
server_error
```

---

# 15. T08 — network_error

优先：

```text
connection refused
DNS failure
network blackhole
```

不要使用：

```text
HTTP_PROXY
HTTPS_PROXY
```

作为唯一证据。

期望：

```text
network_error
gitVer 保留
gitDate 保留
flag 保留
review=true
```

---

# 16. T09 — invalid_response

产生真实：

```text
HTTP 200
tag_name missing
```

期望：

```text
invalid_response
```

不能代码推理代替。

无法安全实现：

```text
BLOCKED
```

---

# 17. T10 — metadata_incomplete

产生：

```text
HTTP 200
tag_name present
published_at missing
```

期望：

```text
metadata_incomplete
```

无法真实实现：

```text
BLOCKED
```

---

# 18. T11 — 普通版本比较

```text
1.2.3 < 1.2.4
```

必须：

```text
cmp=lt
flag=yes
```

---

# 19. T12 — 数值版本排序

验证：

```text
1.2.10 > 1.2.9
```

不得出现字符串排序。

---

# 20. T13 — prerelease

验证：

```text
1.2.3-rc1 < 1.2.3
```

---

# 21. T14 — incomparable

使用不支持版本格式。

验证：

```text
cmp=incomparable
review=true
flag 保留
```

---

# 22. T15 — versionJump

重新测试 boundary：

```text
major:
1 / 2 / 3

minor:
9 / 10 / 11

patch:
49 / 50 / 51
```

验证：

```text
versionJump=true
review=true
flag 不改变
```

---

# 23. T16 — dateSuspicious

构造：

```text
previous gitDate = later
new publishedUtc = earlier Beijing date
```

期望：

```text
dateSuspicious=true
review=true
flag unchanged
```

---

# 24. T17 — isFlip

构造：

```text
prevFlag=no
localVer < latest
```

期望：

```text
flag=yes
isFlip=true
```

---

# 25. T18 — State Preservation

必须重新验证：

```text
auth_error
forbidden
rate_limited
server_error
network_error
http_error
```

每个状态：

```text
gitVer unchanged
gitDate unchanged
flag unchanged
```

同时：

```text
not_found
```

必须单独验证：

```text
gitVer=""
gitDate=""
flag=prevFlag
```

---

# 26. T19 — 未安装

构造：

```text
localVer=未安装
```

期望：

```text
flag=no
gitVer refreshed
gitDate refreshed
```

---

# 27. T20 — result.json atomicity

外部锁注入：

```text
result.fetch.tmp
```

验证：

```text
old result.json SHA256 unchanged
result.json remains valid JSON
no partial state
```

---

# 28. T21 — review atomicity

阻塞：

```text
result.review.tmp
```

验证：

```text
REVIEW_WRITE_ERROR
result.json not corrupted
stats unchanged
items unchanged
lock handled correctly
```

---

# 29. T22 — md temp write failure

阻塞：

```text
GitHub更新监测列表.md.tmp
```

验证：

```text
main md unchanged
no partial write
```

---

# 30. T23 — md replacement failure

阻止 replacement。

验证：

```text
VALIDATE_ERROR
main md unchanged
RUN_STATUS|failed|
```

---

# 31. T24 — 5 columns

必须：

```text
PARSE_ERROR
```

---

# 32. T25 — 7 columns

必须：

```text
PARSE_ERROR
```

---

# 33. T26 — lowercase flag

必须重新验证：

```text
valid:
yes
no

invalid:
YES
Yes
yEs
NO
No
pending
true
```

全部 invalid：

```text
PARSE_ERROR
```

确认：

```text
yes != YES
no != NO
```

---

# 34. T27 — duplicate repo

必须：

```text
PARSE_ERROR
```

---

# 35. T28 — illegal index

必须：

```text
PARSE_ERROR
```

---

# 36. T29 — missing anchors

分别删除：

```text
## 结论
## 更新摘要
## 备注
## 核对方法
```

每次：

```text
PARSE_ERROR
```

---

# 37. T30 — concurrency

启动两个真实：

```text
PowerShell 7
```

进程。

必须：

```text
one owner
one LOCKED
```

不得：

```text
double commit
double success
mutual lock deletion
```

---

# 38. T31 — heartbeat

验证 lock：

```text
pid
start
step
beat
```

并确认 step 变化。

---

# 39. T32 — fresh/live lock

live PID + fresh heartbeat：

```text
LOCKED
```

---

# 40. T33 — stale + alive

构造：

```text
heartbeat > 30 minutes
PID alive
```

必须：

```text
LOCKED
no takeover
```

---

# 41. T34 — stale + dead

构造：

```text
heartbeat > 30 minutes
PID dead
```

允许：

```text
takeover
```

---

# 42. T35 — ownership mismatch

foreign PID。

验证：

```text
RUNTIME_ERROR
foreign lock retained
```

---

# 43. T36 — process kill

必须在：

```text
PowerShell 7
```

实际：

```text
Stop-Process
```

选择至少一个真实执行点：

```text
Step2
Step3
Step4
Step5
```

然后重新运行。

验证：

```text
lock
backup
result.json
main md
```

---

# 44. T37 — full success

完整运行：

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
RUN_STATUS|success|
```

---

# 45. T38 — review failure

真实 fault injection。

必须：

```text
REVIEW_WRITE_ERROR
no COMMIT_OK
RUN_STATUS|failed|
main md unchanged
```

---

# 46. T39 — commit success + lock release failure

必须真实产生：

```text
COMMIT_OK
RUNTIME_ERROR
RUN_STATUS|failed|
```

严禁：

```text
RUN_STATUS|success|
```

---

# 47. T40 — blocked semantics

分别测试：

```text
STATE_MISSING
LOCKED
```

每个：

```text
blocked
```

---

# 48. T41 — token unset

验证：

```text
stats.token=unset
```

---

# 49. T42 — token set

验证：

```text
stats.token=set
```

绝不输出：

```text
GITHUB_TOKEN
Authorization
Cookie
secret
```

---

# 50. T43 — Full Extended Pipeline

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

除 404 项外所有 repo 必须真实存在。

主运行环境：

```text
PowerShell 7
```

完整执行：

```text
Step1
Step2
Step3
Step4
Step5
Step6
```

确认：

```text
BACKUP_OK
FETCH_COMPLETE
SUMMARY
REVIEW_WRITE_OK（存在 review 时）
COMMIT_OK
RUN_STATUS|success|
```

同时比较：

```text
result.json
main md
backup
fetch_run.log
lock
```

之间的数据一致性。

---

# 51. T44 — v1.6 → v1.7 diff integrity

必须再次执行：

```text
git diff v1.6 v1.7
```

并明确输出：

```text
UNEXPECTED_DELETIONS
UNEXPECTED_ADDITIONS
```

重点验证：

```text
versionJump
dateSuspicious
reviewReasons
result.fetch.tmp
result.review.tmp
schema
RUN_STATUS
not_found
lock
atomic commit
```

全部必须存在。

最终：

```text
PASS
```

必须有：

```text
v16.sha256
v17.sha256
v16-v17.diff
```

---

# 52. T45 — contamination scan

扫描：

```text
SKILL-v1.7.md
```

禁止存在：

```text
mock API logic
test bypass
debug bypass
hardcoded token
test repository
forced success
forced rate_limited
skip lock
skip schema
skip commit
```

允许 changelog/documentation 中正常出现：

```text
test
validation
compatibility
mock
```

但必须根据上下文判断。

输出：

```text
NO_CONTAMINATION_FOUND
```

或：

```text
CONTAMINATION_FOUND
```

---

# 53. Additional T46 — Production Runtime Contract

新增：

```text
T46
```

这是针对当前生产环境的运行时契约检查。

必须在：

```text
PowerShell 7.x
```

完整执行一次。

验证：

```text
SKILL 中声明的生产 runtime = PS7.x
实际运行 = PS7.x
没有要求 PS5.1 才能完成生产主流程
```

确认以下核心 API 在 PS7 中实际执行：

```text
Invoke-RestMethod
Invoke-WebRequest
ConvertFrom-Json
ConvertTo-Json
Move-Item
FileMode.CreateNew
```

全部正常。

---

# 54. Evidence

每项测试保存：

```text
test-report.md
stdout.txt
stderr.txt
```

涉及文件：

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
SHA256 before
SHA256 after
```

涉及 API：

```text
HTTP status
target headers
actual request count
```

但禁止：

```text
GITHUB_TOKEN
Authorization
Cookie
complete secrets
```

---

# 55. T04 强制证据

T04 是 v1.7 的核心 gate。

必须同时记录：

```text
runtime
HTTP status
X-RateLimit-Remaining
observed queryStatus
actual latest requests
actual review API requests
actual HTML requests
retry count
```

必须证明：

```text
403 + remaining=0
        ↓
rate_limited
        ↓
no retry
no Step4
no extra request
```

---

# 56. Final Counting

总测试数：

```text
46
```

必须：

```text
PASS + FAIL + BLOCKED = 46
```

报告必须列：

```text
PASS =
FAIL =
BLOCKED =

P0 =
P1 =
P2 =
```

---

# 57. Production Gate

## PRODUCTION_READY

只有全部满足：

```text
P0 = 0
P1 = 0
FAIL = 0
BLOCKED = 0
T01-T46 = PASS
T04-PS7 = PASS
T36 = PASS
T38 = PASS
T39 = PASS
T43 = PASS
T44 = PASS
T45 = PASS
T46 = PASS
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
T04 PS7 FAIL
状态机错误
rate_limited 错误
lock 错误
atomicity 错误
final status 错误
数据丢失
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

不得解释为 READY。

---

# 58. v1.7 版本判定原则

如果：

```text
T04-PS7 PASS
T44 PASS
T45 PASS
所有生产关键测试 PASS
没有 FAIL
没有 BLOCKED
```

才允许：

```text
PRODUCTION_READY
```

PS5.1 兼容测试如果失败：

```text
必须单独记录
不得影响当前 PS7 生产准入
```

但必须说明：

```text
PS5.1 compatibility = FAIL
```

不能隐瞒。

---

# 59. 最终报告

生成：

```text
production-validation-report-v17-final.md
```

必须包含：

```text
A. Environment
B. Version / SHA256
C. v1.6 → v1.7 Diff Integrity
D. Contract Integrity
E. Test Summary T01-T46
F. Critical Findings
G. Evidence Index
H. Production Gate
I. Execution Summary
J. Remaining Limitations
K. PS7 Production Assessment
L. PS5.1 Compatibility Assessment
```

---

# 60. Execution Summary

明确回答：

```text
PowerShell 7 available: YES/NO
PowerShell 7 executed: YES/NO
PowerShell 5.1 available: YES/NO
PowerShell 5.1 executed: YES/NO

Real GitHub API accessed: YES/NO
Mock HTTP executed: YES/NO
T04 real 403+remaining=0: YES/NO/BLOCKED
T05 real 403+remaining>0: YES/NO/BLOCKED
T06 real 429: YES/NO/BLOCKED
T07 real 5xx: YES/NO/BLOCKED
T08 real network_error: YES/NO/BLOCKED
T09 real invalid_response: YES/NO/BLOCKED
T10 real metadata_incomplete: YES/NO/BLOCKED

Concurrency tested: YES/NO
Process Kill tested: YES/NO
result.json atomicity tested: YES/NO
review atomicity tested: YES/NO
md atomicity tested: YES/NO
lock release failure tested: YES/NO

v1.6→v1.7 diff tested: YES/NO
contamination scan tested: YES/NO
production PS7 full pipeline tested: YES/NO
```

---

# 61. Final Report Ending

严格输出：

```text
VERSION: v1.7

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
<完整报告路径>
```

最后必须遵守：

```text
不要修改 SKILL-v1.7.md。
不要修复后再假装同一轮测试。
不要继承旧 PASS。
不要把 BLOCKED 解释为 PASS。
不要把 PS5.1 的兼容性问题混同为 PS7 生产问题。
不要隐藏 T04。
不要弱化 Production Gate。
证据优先于结论。
```