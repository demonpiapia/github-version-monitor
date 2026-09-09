# SKILL-v1.8 定向回归验证 — 最终执行计划

> **版本**: exec-plan-v18-a  
> **制定日期**: 2026-09-08  
> **依据**: `.GPT/v1.8-targeted-validation-prompt.md`（唯一事实源）  
> **执行模式**: 单一子 agent 串行执行，禁止并行

---

## 0. 已验证基线

| 项 | 值 | 状态 |
|---|---|---|
| Git branch | main | clean working tree |
| HEAD commit | c31db02 | feat: add SKILL-v1.8 |
| PS7 | 7.6.4 | 可用 |
| PS5.1 | 5.1.22621.963 | 可用 |
| SKILL-v1.6.md SHA256 | `7480B6B5E34BDD8B2F07552F8B174F41421BB7BF3537A8486DF35A9BC3F55CD7` | 与 handoff 一致 |
| SKILL-v1.7.md SHA256 | `F386879CCB1CA4C88D6DDBC5D9057D906913897C743F03151ABE164108B97DDC` | 与 handoff 一致 |
| SKILL-v1.8.md SHA256 | `8C6B1CC31B61839853DEA0ABCEB903BD763ACE03A677130D08C3D56D8728CA68` | 与 handoff 一致 |
| `.output/...md` SHA256 | `7396981A2FBF019D3DAD0C906A2B6E9C05D36C4746F35E0C0063FD1F3EB19CD3` | 与 handoff 一致 |
| `$commitSucceeded=$true` | SKILL-v1.8.md L579 | 修复已存在于原始代码 |

---

## 1. 核心验证目标

验证 SKILL-v1.8.md 是否修复了 v1.7 的 `$commitSucceeded` P1 回归 bug，且 v1.7 已验证能力不回归。最终产出 `PRODUCTION_READY` / `PRODUCTION_NOT_READY` / `PRODUCTION_BLOCKED` 之一。

---

## 2. 测试架构

### 2.1 代码提取原则

从 SKILL-v1.8.md 原文逐字提取 PowerShell 代码块，禁止修改被测代码。提取的脚本仅用于测试执行环境控制，不改变逻辑。

### 2.2 测试隔离

所有测试放在 `.production-validation-v18-final/` 下，每个测试有独立子目录，通过 `GITHUB_VERSION_MONITOR_BASE` 环境变量指向测试目录，fixture 放在 `<test-dir>/.output/GitHub更新监测列表.md`。

### 2.3 API 模拟

- 状态机测试 (T04/T05/T08/T18): 本地 `System.Net.HttpListener` 返回受控 HTTP 响应
- 全管线测试 (T37/T43/T46): 真实 GitHub API + 真实仓库

### 2.4 证据规则（严格遵循 prompt 第 9 节）

所有测试至少保存：

```
stdout.txt
stderr.txt
test-report.md
```

涉及状态文件时追加：

```
md-before.md
md-after.md
```

涉及 result.json 时追加：

```
result-before.json
result-after.json
```

涉及 lock 时追加：

```
lock-before.txt
lock-after.txt
```

涉及 atomicity 时追加：

```
SHA256 before
SHA256 after
```

涉及 API 时追加：

```
HTTP status
relevant header metadata
request count
```

不得保存：`GITHUB_TOKEN` / `Authorization` / `Cookie` / 完整 secret。

---

## 3. 阶段分解（串行子 agent，禁止并行）

---

### Phase 1: 基础设施 + 基线 + 代码提取

**子 agent 任务**: 创建测试目录、验证 SHA256、生成 diff、提取代码、创建测试工具

**具体工作**:

1. 创建 `.production-validation-v18-final/` 目录树（含 `lib/`, 各测试子目录）
2. 重算 4 个文件 SHA256，与基线比对：
   - `SKILL-v1.6.md` → `7480B6B5...`
   - `SKILL-v1.7.md` → `F386879C...`
   - `SKILL-v1.8.md` → `8C6B1CC3...`
   - `.output/GitHub更新监测列表.md` → `7396981A...`
3. 生成两个 diff（prompt 第 2 节要求）：
   - `v16-v17.diff`（`git diff --no-index SKILL-v1.6.md SKILL-v1.7.md`）
   - `v17-v18.diff`（`git diff --no-index SKILL-v1.7.md SKILL-v1.8.md`）
4. Diff 完整性分析：
   - **v1.8 必须保留 v1.7 的 15 项能力**（逐项显式核验）：
     ```
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
   - **v1.8 允许的 4 项变更**（确认存在且仅这些）：
     ```
     $commitSucceeded 修复
     COMMIT_OK / RUN_STATUS invariant 加固
     .output/GitHub更新监测列表.md 路径同步
     Changelog
     ```
   - **禁止项检查**（不得存在）：
     ```
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
   - 若发现非预期能力删除 → P1 + PRODUCTION_NOT_READY
5. 从 SKILL-v1.8.md 提取 PowerShell 代码块（逐字提取，不修改）：
   - `lib/step1.ps1` — Step 1 (状态检查 + 锁 + 备份)
   - `lib/step2.ps1` — Step 2 (解析 + 查询 + 状态机 + 统计)
   - `lib/step3.ps1` — Step 3 (备份清理)
   - `lib/step4.ps1` — Step 4 (复核)
   - `lib/step5-full.ps1` — Step 5 完整 (提交 + 锁释放 + RUN_STATUS)
   - `lib/step5-commit.ps1` — Step 5 提交部分 (到 L583 为止，用于 T39)
   - `lib/step5-lockrelease.ps1` — Step 5 锁释放部分 (L585-602，用于 T39)
6. 创建 `lib/run-full-pipeline.ps1` — 串行执行 step1→step2→step3→step4→step5-full
7. 创建 `lib/mock-listener.ps1` — HTTP 模拟监听器
8. 创建 `lib/create-fixture.ps1` — fixture 生成工具

**证据**: `phase1-report.md`（SHA256 表、两个 diff 分析、15 项能力核验表、4 项允许变更确认、禁止项检查结果、提取验证）

---

### Phase 2: 核心修复测试 (T37/T38/T39) — 硬门槛

**子 agent 任务**: 执行 3 项核心修复验证

#### T37-v18 — 正常提交 → RUN_STATUS|success|（硬门槛）

- Fixture: 2 个真实仓库（如 microsoft/vscode localVer=1.0.0 + torvalds/linux localVer=6.5.0）
- 在 PS7 中运行完整 Step 1→6
- 验证: `COMMIT_OK|` + `RUN_STATUS|success|` + 锁已释放 + md 已更新
- 验证修复点: `$commitSucceeded=$true` 在 Move-Item 成功后被设置（通过 step5-full.ps1 行为确认 — 成功路径输出 RUN_STATUS|success|）
- 验证: `lockReleased = true`
- **硬门槛**: 如果出现 `COMMIT_OK|` + `RUN_STATUS|failed|` → FAIL + P1 + PRODUCTION_NOT_READY
- **证据**: stdout.txt / stderr.txt / test-report.md / md-before.md / md-after.md / result-before.json / result-after.json / SHA256 before-after

#### T38-v18 — review 写回失败

- 在 Step 4 执行前阻塞 `result.review.tmp` 创建（设置目录权限或预创建只读文件）
- 不得修改 SKILL
- 验证: `REVIEW_WRITE_ERROR|` + 无 `COMMIT_OK|` + `RUN_STATUS|failed|` + 主 md SHA256 不变
- **证据**: stdout.txt / stderr.txt / test-report.md / md-before.md / md-after.md / result-before.json / result-after.json / SHA256 before-after

#### T39-v18 — 提交成功 + 锁释放失败

- 运行 step5-commit.ps1（提交成功，输出 COMMIT_OK）
- 修改锁文件 PID 为不匹配值（如 pid=999999）
- 运行 step5-lockrelease.ps1（锁释放失败）
- 验证: `COMMIT_OK|` + `RUNTIME_ERROR|` + `RUN_STATUS|failed|` + 绝不出现 `RUN_STATUS|success|`
- **证据**: stdout.txt / stderr.txt / test-report.md / lock-before.txt / lock-after.txt / result-before.json / result-after.json

**早期判定**: T37-v18 FAIL → 立即标记 PRODUCTION_NOT_READY 倾向，但仍完成后续测试以保留完整证据

---

### Phase 3: 状态机回归 (T04/T05/T08/T18/T26)

**子 agent 任务**: 执行 5 项状态机回归测试

#### T04-PS7 — PS7 rate_limited（报告格式名: T04-PS7）

- 本地 HTTP listener 返回 403 + `X-RateLimit-Remaining: 0`
- 验证: `queryStatus=rate_limited`
- 并确认: no retry / no Step4 API / no HTML
- 提取 SKILL-v1.8.md Step 2 的状态机 catch 块和 `Get-ResponseHeaderValue` 函数原样执行
- **证据**: stdout.txt / stderr.txt / test-report.md / HTTP status / header metadata / request count

#### T05-PS7 — PS7 forbidden（报告格式名: T05-PS7）

- HTTP listener 返回 403 + `X-RateLimit-Remaining: 50`
- 验证: `queryStatus=forbidden`
- **证据**: stdout.txt / stderr.txt / test-report.md / HTTP status / header metadata / request count

#### T08-PS7 — network_error（报告格式名: T08-PS7）

- PS7 中实际命中无 HTTP response 路径（连接不存在的端口或域名）
- 不得仅依赖 PS5.1 proxy 行为推理
- 验证: `queryStatus=network_error`
- **证据**: stdout.txt / stderr.txt / test-report.md

#### T18-v18 — 状态保留

- 6 种 error 状态:
  ```
  auth_error
  forbidden
  rate_limited
  server_error
  network_error
  http_error
  ```
- 验证: 每种状态下 `gitVer` / `gitDate` / `flag` 不变
- 404 专用规则: `gitVer=""` / `gitDate=""` / `flag=prevFlag`
- **证据**: stdout.txt / stderr.txt / test-report.md（每种状态独立记录）

#### T26-v18 — 严格小写 flag

- 有效: `yes` / `no`
- 无效: `YES` / `Yes` / `yEs` / `NO` / `No` → 必须输出 `PARSE_ERROR|`
- 使用 fixture 文件测试解析器
- **证据**: stdout.txt / stderr.txt / test-report.md

---

### Phase 4: Schema / 原子性 / 锁回归 (T20-T23, T30-T36)

**子 agent 任务**: 执行 10 项原子性/锁回归测试

| 测试 | 验证内容 | 方法 | 额外证据 |
|---|---|---|---|
| T20 | result.json 原子性 | 临时文件 → JSON 校验 → 原子替换 | result-before.json / result-after.json / SHA256 before-after |
| T21 | review 原子性 | result.review.tmp → JSON 校验 → 原子替换 | result-before.json / result-after.json / SHA256 before-after |
| T22 | md 临时文件失败 | 临时文件创建失败 → 主 md 不变 | md-before.md / md-after.md / SHA256 before-after |
| T23 | md 替换失败 | Move-Item 失败 → 主 md 不变 + 临时文件清理 | md-before.md / md-after.md / SHA256 before-after |
| T30 | 并发 | 两进程争锁，一胜一 `LOCKED\|` 退出 | lock-before.txt / lock-after.txt |
| T31 | heartbeat | 锁 heartbeat 刷新（step=2/3/4/5） | lock-before.txt / lock-after.txt |
| T33 | 陈锁 + PID 活 | heartbeat 超 30min + PID 活 → `LOCKED\|` | lock-before.txt / lock-after.txt |
| T34 | 陈锁 + PID 死 | heartbeat 超 30min + PID 死 → 接管成功 | lock-before.txt / lock-after.txt |
| T35 | ownership 不匹配 | 锁 PID ≠ 当前 PID → `RUNTIME_ERROR\|` | lock-before.txt / lock-after.txt |
| T36 | 进程中断 | 进程被 kill → 锁残留 → 下轮处理 | lock-before.txt / lock-after.txt |

**原则**（prompt 第 7 节）: 历史 PASS 可以指导测试选择，但不能在本轮作为唯一 PASS 证据。

每项均需: stdout.txt / stderr.txt / test-report.md

---

### Phase 5: 全管线 + 路径契约 (T43/T46)

**子 agent 任务**: 执行全管线 + 路径验证

#### T43-v18 — 6 场景全管线

Fixture 场景（除 404 外 repo 必须真实存在）:
```
normal upgrade      — 真实仓库，localVer 低于最新 release
synced              — 真实仓库，localVer 等于最新 release
uninstalled         — 真实仓库，localVer=未安装
unsupported version — 真实仓库，版本格式不可比较
404                 — 不存在的仓库（如 test/nonexistent-repo-12345）
versionJump         — 真实仓库，版本跨越大
```

- PS7 完整 Step 1→6
- 验证:
  ```
  BACKUP_OK|
  FETCH_COMPLETE|
  SUMMARY|
  COMMIT_OK|
  RUN_STATUS|success|
  ```
- 验证主状态文件实际位于 `.output/GitHub更新监测列表.md`（而非仓库根目录）
- **证据**: stdout.txt / stderr.txt / test-report.md / md-before.md / md-after.md / result-before.json / result-after.json

#### T46-v18 — `.output` 路径契约

- 建立 `.output/GitHub更新监测列表.md`
- 不要在根目录创建同名状态文件
- 运行完整 Step 1 / Step 2（仅此两步，prompt 第 5 节）
- 验证:
  ```
  读取 .output/GitHub更新监测列表.md
  写回 .output/GitHub更新监测列表.md
  ```
- 根目录 `GitHub更新监测列表.md` 不得被创建
- 如果根目录出现同名状态文件: **FAIL + P1**
- **证据**: stdout.txt / stderr.txt / test-report.md / md-before.md / md-after.md / 目录列表

---

### Phase 6: PS5.1 兼容性

**子 agent 任务**: 在 PS5.1 中执行 2 项兼容性测试

#### T04-PS5.1

- 403 + remaining=0 → rate_limited
- 使用与 Phase 3 相同的 HTTP listener 方法
- 在 PS5.1 (`C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe`) 中执行
- 验证 header 处理在 PS5.1 下正确
- **证据**: stdout.txt / stderr.txt / test-report.md / HTTP status / header metadata

#### T05-PS5.1

- 403 + remaining>0 → forbidden
- 同上 PS5.1 环境
- **证据**: stdout.txt / stderr.txt / test-report.md / HTTP status / header metadata

**判定规则**（prompt 第 8 节）:
- PS5.1 不存在 → BLOCKED（不影响 PS7 production gate）
- PS5.1 存在但失败 → 记录 compatibility FAIL，不得隐瞒
- 兼容性 FAIL 不自动升级为 PS7 production P1（除非另有明确生产要求）

---

### Phase 7: 最终报告 + 提交推送（主 agent 执行）

**工作内容**:

1. 汇总 Phase 1-6 全部证据
2. 生成 `production-validation-report-v18-final.md`（章节 A-N，prompt 第 12 节）:
   ```
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
3. 报告中必须明确（prompt 第 12 节格式）:
   ```
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
4. 末尾严格输出（prompt 第 12 节）:
   ```
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
   （或 PRODUCTION_NOT_READY / PRODUCTION_BLOCKED）
5. 计算 PASS/FAIL/BLOCKED + P0/P1/P2 计数
6. 判定 PRODUCTION_GATE (OPEN/CLOSED) + FINAL_VERDICT
7. Git commit（message 包含: verdict / PASS-FAIL-BLOCKED 计数 / P0-P1-P2 计数 / 关键发现 / 证据目录路径）
8. Git push

---

## 4. 子 agent 执行模型

```
Phase 1 (sub-agent) → 主 agent 审查 → Phase 2 (sub-agent) → 主 agent 审查 → ...
```

- 每个 phase 完成后，主 agent 核验证据完整性
- 禁止并行: 下一 phase 仅在上一 phase 的主 agent 审查通过后启动
- 每个 sub-agent 接收: 任务规范 + SKILL-v1.8.md 路径 + 测试目录 + 证据要求
- 每个 sub-agent 产出: 测试证据文件 + 结构化结果摘要

---

## 5. 硬约束（违反即本轮无效）

1. 不得修改 `SKILL-v1.8.md` — 发现问题只记录，不修复
2. 不得修改生产 `.output/GitHub更新监测列表.md` — 用 fixture 副本测试
3. 不得把修复写入 extracted production script 后再报告 PASS（prompt 第 10 节）
4. 不得复用 v1.7 历史测试证据作为本轮 PASS 证据（prompt 第 1 节）
5. 不得修改 `.GPT/` 下的 prompt 文件
6. 不得输出 `GITHUB_TOKEN` / `Authorization` / `Cookie` / 完整 secret（prompt 第 9 节）
7. 如果为了让测试通过而修改了被测代码: 该测试结果无效，重新测试，并在报告中披露（prompt 第 10 节）
8. Verdict 必须由实际证据决定，禁止按预期结果填写（prompt 第 12 节）

---

## 6. 最终 Verdict 判定逻辑（prompt 第 11 节）

### PRODUCTION_READY

同时满足:
```
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

非生产关键兼容测试（PS5.1）BLOCKED 时: 不得隐藏，但应明确其范围；不影响 PS7 production gate。

### PRODUCTION_NOT_READY

任意:
```
P0 > 0
P1 > 0
FAIL > 0
```

尤其:
```
正常提交仍 RUN_STATUS|failed|
.output 路径错误
rate_limited 分类错误
lock 错误
atomicity 错误
```

### PRODUCTION_BLOCKED

仅当:
```
P0=0
P1=0
FAIL=0
但关键生产测试存在 BLOCKED
```

### 非生产关键 BLOCKED 的处理

- PS5.1 兼容测试 BLOCKED: 显式列出，不影响 PRODUCTION_READY 判定
- 任何生产关键项 BLOCKED: Production Gate = CLOSED

---

## 7. 推送说明规范（handoff 第 11 节）

### Commit message 格式

```
<type>: <一句话概括变更>

<正文：列出具体变更项>
- 变更了什么文件
- 为什么变更（用户要求 / 验证发现 / 修复）
- 影响范围（是否影响生产行为、是否需重新验证）
```

### 本轮验证的推送要求

commit message 必须包含:
```
1. 最终 Verdict（PRODUCTION_READY / NOT_READY / BLOCKED）
2. PASS / FAIL / BLOCKED 计数
3. P0 / P1 / P2 计数
4. 本轮新增或发现的关键问题（若有）
5. 新增的证据目录与报告路径
```

### 禁止事项

```
- 禁止静默推送（无 commit message 正文）
- 禁止把验证结论只写在报告里而不在 commit message 中体现
- 禁止推送包含 secret / token / Authorization 的内容
```

---

## 8. 测试清单总览

| Phase | 测试 | 重点 | 优先级 |
|---|---|---|---|
| 1 | Diff integrity | v16-v17 + v17-v18 diff，15 项能力保留，4 项允许变更，9 项禁止项 | 基础 |
| 2 | T37-v18 | 正常提交 → COMMIT_OK + RUN_STATUS\|success\| | **硬门槛** |
| 2 | T38-v18 | review 写回失败 → REVIEW_WRITE_ERROR | 高 |
| 2 | T39-v18 | 提交成功 + 锁释放失败 → 绝不 success | 高 |
| 3 | T04-PS7 | 403 + remaining=0 → rate_limited | 高 |
| 3 | T05-PS7 | 403 + remaining>0 → forbidden | 高 |
| 3 | T08-PS7 | network_error，PS7 实际无 HTTP response | 高 |
| 3 | T18-v18 | 6 种 error 状态保留 + 404 专用规则 | 中 |
| 3 | T26-v18 | 严格小写 flag，YES/Yes/yEs/NO/No → PARSE_ERROR | 中 |
| 4 | T20-T23 | result/review/md 原子性 | 中 |
| 4 | T30-T36 | 并发/heartbeat/stale/ownership/process kill | 中 |
| 5 | T43-v18 | 6 场景全管线 Step 1→6 | **关键** |
| 5 | T46-v18 | .output 路径契约，根目录不得出现同名文件 | **关键** |
| 6 | T04-PS5.1 | PS5.1 403 + remaining=0 → rate_limited | 兼容 |
| 6 | T05-PS5.1 | PS5.1 403 + remaining>0 → forbidden | 兼容 |
| 7 | Final Report | 报告 A-N + verdict + commit + push | 收尾 |

---

## 9. 修正记录

本计划相对于初版的修正项（基于与 `.GPT/v1.8-targeted-validation-prompt.md` 的逐节复核）:

| # | 类型 | 内容 | 修正位置 |
|---|---|---|---|
| 1 | 必须修正 | 增加 `v16-v17.diff` 生成（prompt 第 2 节要求两个 diff） | Phase 1 第 3 步 |
| 2 | 必须修正 | 增加 `result-before.json` / `result-after.json` 证据要求（prompt 第 9 节） | 证据规则 + T37/T38/T39/T20/T21/T43 |
| 3 | 建议补充 | 报告格式中测试命名对齐 prompt 第 12 节（T04-PS7 等） | Phase 3 标题 + Phase 7 报告格式 |
| 4 | 建议补充 | T30-T36 锁测试增加 `lock-before.txt` / `lock-after.txt` 证据 | Phase 4 证据列 |
| 5 | 建议补充 | Phase 1 显式列出 15 项能力清单 | Phase 1 第 4 步 |
| 6 | 建议补充 | Phase 1 显式列出 4 项允许变更 + 确认仅这些 | Phase 1 第 4 步 |
| 7 | 建议补充 | 非生产关键 BLOCKED 不阻止 PRODUCTION_READY 的判定逻辑 | 第 6 节判定逻辑 |
