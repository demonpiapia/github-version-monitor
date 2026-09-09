# Phase 7 Report — T04 + T05-PS7 + T26 + T18

**Phase**: Phase 7（exec-plan-v1.10-d.md §2 Phase 7）
**Priority**: 中（记录并继续，不阻断后续 Phase）
**Environment**: Windows + PowerShell 7.x
**Start**: 2026-09-09T08:13:12.484+08:00
**End**: 2026-09-09T08:13:28.014+08:00
**Duration**: 15.5s
**Overall Verdict**: **PASS**（4/4 测试全部 PASS）

## 1. Executive Summary

| 测试 | 场景 | 判定 |
|---|---|---|
| T04-PS7 | 403 + `X-RateLimit-Remaining=0` → `rate_limited` | **PASS** |
| T05-PS7 | 403 + `X-RateLimit-Remaining=50` → `forbidden` | **PASS** |
| T26 | Strict Flag Regression（9 项输入） | **PASS** |
| T18 | State Preservation Regression（9 种非 ok 状态） | **PASS** |

## 2. Test Details

### 2.1 T04-PS7 — rate_limited Regression

- **Mock 场景**: `rate_limited_403`（403 + `X-RateLimit-Remaining='0'`）
- **期望**: `rate_limited` + latest=1 + review=0 + HTML=0 + retry=0
- **实际**:
  - `items[0].status = rate_limited` ✅
  - latest request count = 1 ✅
  - review API count = 0 ✅
  - HTML fallback count = 0 ✅
  - retry count = 0 ✅
  - total mock calls = 1 ✅
- **Verdict**: **PASS**
- **证据**: `T04-PS7/stdout.txt` / `stderr.txt` / `test-report.md` / `result-after.json` / `sha256-before.txt` / `sha256-after.txt`

### 2.2 T05-PS7 — forbidden Regression

- **Mock 场景**: `forbidden`（403 + `X-RateLimit-Remaining='50'`）
- **期望**: `forbidden`
- **实际**:
  - `items[0].status = forbidden` ✅
  - total mock calls = 1 ✅
- **Verdict**: **PASS**
- **证据**: `T05-PS7/stdout.txt` / `stderr.txt` / `test-report.md` / `result-after.json`

> **注**: T05-PS7 与 T18 的 `forbidden` 状态测试共享 mock 场景（403+remaining>0），但 T05-PS7 侧重状态机判定输出，T18 侧重状态保留（gitVer/gitDate/flag 不变）。两者证据独立采集。

### 2.3 T26 — Strict Flag Regression（9 项输入）

| # | 输入 | 期望 | 实际 `PARSE_ERROR|` | 主 md unchanged | 锁释放 | 结果 |
|---|---|---|---|---|---|---|
| 1 | `yes` | VALID | False | True | False | ✅ |
| 2 | `no` | VALID | False | True | False | ✅ |
| 3 | `YES` | PARSE_ERROR | True | True | True | ✅ |
| 4 | `Yes` | PARSE_ERROR | True | True | True | ✅ |
| 5 | `yEs` | PARSE_ERROR | True | True | True | ✅ |
| 6 | `NO` | PARSE_ERROR | True | True | True | ✅ |
| 7 | `No` | PARSE_ERROR | True | True | True | ✅ |
| 8 | `pending` | PARSE_ERROR | True | True | True | ✅ |
| 9 | `true` | PARSE_ERROR | True | True | True | ✅ |

- **Verdict**: **PASS**（9/9 项符合期望）
- **证据**: `T26/flag_<input>_<NN>/stdout.txt` × 9 + `T26/test-report.md`

**目录命名说明**：Windows 文件系统大小写不敏感（`flag_yes` 与 `flag_YES` 会冲突），故使用带序号后缀的目录名确保 9 个 case 目录物理独立。

### 2.4 T18 — State Preservation Regression（9 种非 ok 状态）

Fixture 统一使用：`prevGitVer=1.0.0`、`prevGitDate=2025-01-01`、`prevFlag=no`、`localVer=0.0.1`。

| # | 状态 | Mock 场景 | 期望 gitVer | 期望 gitDate | 期望 flag | 期望 review | 实际 status | 实际 gitVer | 实际 gitDate | 实际 flag | 实际 review | 结果 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | `not_found` | 404 | `''` | `''` | `no` | `true` | `not_found` | `''` | `''` | `no` | `true` | ✅ |
| 2 | `rate_limited` | 403+rl=0 | `1.0.0` | `2025-01-01` | `no` | `true` | `rate_limited` | `1.0.0` | `2025-01-01` | `no` | `true` | ✅ |
| 3 | `server_error` | 500 | `1.0.0` | `2025-01-01` | `no` | `true` | `server_error` | `1.0.0` | `2025-01-01` | `no` | `true` | ✅ |
| 4 | `network_error` | 无 Response | `1.0.0` | `2025-01-01` | `no` | `true` | `network_error` | `1.0.0` | `2025-01-01` | `no` | `true` | ✅ |
| 5 | `invalid_response` | 200+空 tag_name | `1.0.0` | `2025-01-01` | `no` | `true` | `invalid_response` | `1.0.0` | `2025-01-01` | `no` | `true` | ✅ |
| 6 | `metadata_incomplete` | 200+无 published_at | `1.0.0` | `2025-01-01` | `no` | `true` | `metadata_incomplete` | `1.0.0` | `2025-01-01` | `no` | `true` | ✅ |
| 7 | `auth_error` | 401 | `1.0.0` | `2025-01-01` | `no` | `true` | `auth_error` | `1.0.0` | `2025-01-01` | `no` | `true` | ✅ |
| 8 | `forbidden` | 403+rl=50 | `1.0.0` | `2025-01-01` | `no` | `true` | `forbidden` | `1.0.0` | `2025-01-01` | `no` | `true` | ✅ |
| 9 | `http_error` | 302 | `1.0.0` | `2025-01-01` | `no` | `true` | `http_error` | `1.0.0` | `2025-01-01` | `no` | `true` | ✅ |

- **Verdict**: **PASS**（9/9 状态符合期望）
- **证据**: `T18/state_<status>/stdout.txt` × 9 + `T18/test-report.md`

## 3. Main Agent Review Checkpoints

- [x] 核验 T04-PS7 stdout 中 `rate_limited` 存在
  - 证据：`T04-PS7/stdout.txt` L27 `"status": "rate_limited"`
- [x] 核验 T05-PS7 stdout 中 `forbidden` 存在
  - 证据：`T05-PS7/stdout.txt` L27 `"status": "forbidden"`
- [x] 核验 T26 的 9 项输入测试结果（2 合法 + 7 非法）
  - 证据：9 个 `T26/flag_*/stdout.txt`，VALID 无 `PARSE_ERROR`，非法输入均有 `PARSE_ERROR|` + 主 md unchanged + 锁释放
- [x] 核验 T18 的 9 种状态保留测试结果
  - 证据：9 个 `T18/state_*/result-after.json`，`not_found` 特例（gitVer/gitDate 清空）+ 其他 8 种保留 prev 值

## 4. Mock Contract Alignment

- **Mock 库**: `lib/mock-invoke-restmethod.ps1`（Phase 1 已对齐自检）
- **Headers 类型**: `System.Net.WebHeaderCollection`（覆盖 SKILL L326/L327 分支，L328 通过 catch 兜底）
- **StatusCode 类型**: `System.Net.HttpStatusCode` 枚举实例（SKILL L355 以 `[int]` 转换后比较）
- **`X-RateLimit-Remaining`**: 字符串 `'0'` / `'50'`（SKILL L364 以字符串比较）
- **network_error**: 异常无 `.Response` 属性（进入 SKILL L367 else 分支）

## 5. Errors / Warnings

- **无错误**。
- **无警告**。
- **无 BLOCKED**。
- **无 FAIL**。

## 6. Final Counting（Phase 7 内部）

```
EXECUTED = 4  (T04-PS7, T05-PS7, T26, T18)
PASS     = 4
FAIL     = 0
BLOCKED  = 0
```

守恒式：`PASS + FAIL + BLOCKED = 4 + 0 + 0 = 4 = EXECUTED` ✅

## 7. Evidence Files Index

### Phase 7 顶层
- `phase7-orchestrator.ps1` — 测试编排脚本
- `phase7-stdout.txt` — 编排器 stdout
- `phase7-stderr.txt` — 编排器 stderr（空）
- `phase7-report.md` — 本文件
- `phase7-summary.json` — 结构化结果 JSON
- `phase-progress.json` — 更新为 Phase7

### T04-PS7
- `T04-PS7/stdout.txt` / `stderr.txt`
- `T04-PS7/md-before.md` / `md-after.md`
- `T04-PS7/sha256-before.txt` / `sha256-after.txt`
- `T04-PS7/lock-before.txt` / `lock-after.txt`
- `T04-PS7/result-before.json` / `result-after.json`
- `T04-PS7/test-report.md`

### T05-PS7
- `T05-PS7/stdout.txt` / `stderr.txt`
- `T05-PS7/md-before.md` / `md-after.md`
- `T05-PS7/sha256-before.txt` / `sha256-after.txt`
- `T05-PS7/lock-before.txt` / `lock-after.txt`
- `T05-PS7/result-before.json` / `result-after.json`
- `T05-PS7/test-report.md`

### T26（9 个 case 子目录）
- `T26/flag_yes_01/` — VALID `yes`
- `T26/flag_no_02/` — VALID `no`
- `T26/flag_YES_03/` — PARSE_ERROR `YES`
- `T26/flag_Yes_04/` — PARSE_ERROR `Yes`
- `T26/flag_yEs_05/` — PARSE_ERROR `yEs`
- `T26/flag_NO_06/` — PARSE_ERROR `NO`
- `T26/flag_No_07/` — PARSE_ERROR `No`
- `T26/flag_pending_08/` — PARSE_ERROR `pending`
- `T26/flag_true_09/` — PARSE_ERROR `true`
- 每个 case 子目录含：`stdout.txt` / `stderr.txt` / `md-before.md` / `md-after.md` / `sha256-before.txt` / `sha256-after.txt` / `lock-before.txt` / `lock-after.txt` / `result-before.json` / `result-after.json`
- `T26/test-report.md`

### T18（9 个 case 子目录）
- `T18/state_not_found/` — 404 特例
- `T18/state_rate_limited/` — 403+rl=0
- `T18/state_server_error/` — 500
- `T18/state_network_error/` — 无 Response
- `T18/state_invalid_response/` — 200+空 tag_name
- `T18/state_metadata_incomplete/` — 200+无 published_at
- `T18/state_auth_error/` — 401
- `T18/state_forbidden/` — 403+rl=50
- `T18/state_http_error/` — 302
- 每个 case 子目录含：`stdout.txt` / `stderr.txt` / `md-before.md` / `md-after.md` / `sha256-before.txt` / `sha256-after.txt` / `lock-before.txt` / `lock-after.txt` / `result-before.json` / `result-after.json`
- `T18/test-report.md`

## 8. Verdict

**Phase 7 Overall Verdict: PASS**

- T04-PS7 = PASS
- T05-PS7 = PASS
- T26 = PASS
- T18 = PASS

Phase 7 为中优先级，PASS 结果不阻断后续 Phase 8。
