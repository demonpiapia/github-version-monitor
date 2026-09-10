# Test 2 — 正常成功路径验证报告

- Test ID: **T2-success**
- Test 目录: `D:\AI\Workspace\automatic\github-version-monitor\.production-validation-v112-final\T2-success`
- Fixture repos: `microsoft/vscode`, `PowerShell/PowerShell`（F12 修订：替换 `torvalds/linux`）
- 执行日期: 2026-09-10 (Asia/Hong_Kong)
- 执行器: `lib/p3-run-T.ps1 -TestId T2-success`

## 环境前提（T14 修订）

| 项 | 值 |
|---|---|
| `token_available` | True（Phase 0 ENV_CHECK 确认） |
| `GITHUB_TOKEN_SET` | True（pipeline stdout 行 `GITHUB_TOKEN_SET=True`） |
| `network_github` | ok（Phase 0 ENV_CHECK） |
| result.json `token` 字段 | `"set"` |
| `network_github` 本轮实测 | apiOk=2 / apiErr=0（`FETCH_COMPLETE|apiOk=2 apiErr=0 total=2`） |
| 执行模式 | Start-Process -RedirectStandardOutput/-RedirectStandardError（详见 T1-PS7/test-report.md 差异说明） |

## 完整成功链（原文摘引自 `T2-success/stdout.txt`）

```
BACKUP_OK|20260910-225927848
FETCH_COMPLETE|apiOk=2 apiErr=0 total=2
SUMMARY|total=2 apiOK=2 apiErr=0 synced=0 yes=1 uninstalled=1 pendingReview=2 newReleases=2 flips=1 token=set
REVIEW_WRITE_OK|复核完成：2 项；stats/items 保持不变。
COMMIT_OK|已原子替换主 md（数据行 2，yes/no 校验通过，repo 集合一致）。
RUN_STATUS|success|fetch + 必要 review + commit + lock release 完成。
```

## 验证项

| 验证项 | 期望 | 实际 | 结果 |
|---|---|---|---|
| `BACKUP_OK\|` 存在 | count ≥ 1 | count=1 | ✅ PASS |
| `FETCH_COMPLETE\|` 存在 | count ≥ 1 | count=1 | ✅ PASS |
| `SUMMARY\|` 存在 | count ≥ 1 | count=1 | ✅ PASS |
| `REVIEW_WRITE_OK\|` 存在 | 条件化期望：本轮触发 review 时出现；本轮 `pendingReview=2 > 0` → 期望存在 | count=1 | ✅ PASS |
| `COMMIT_OK\|` 存在 | count ≥ 1 | count=1 | ✅ PASS |
| `RUN_STATUS\|success\|` count | = 1 | = 1 | ✅ PASS |
| `RUN_STATUS\|failed\|` count | = 0 | = 0 | ✅ PASS |
| lock released | run.lock 不存在 | `lock_after.txt` = `LOCK_EXISTS=False` | ✅ PASS |
| md updated | md-after ≠ md-before | sha256_before=`20710075...` / sha256_after=`4D258443...` / `md_changed=True` | ✅ PASS |
| result.json valid | JSON 结构完整 | `result_json_ok=True` | ✅ PASS |
| result.json `token` 字段 | 非空 | `result_token_field=set` | ✅ PASS |
| 主 md 未损坏：表格行数 | = 2 | before=2 / after=2 | ✅ PASS |
| 主 md 未损坏：repo 集合 | = fixture 集合 | `microsoft/vscode,PowerShell/PowerShell` (both before & after) | ✅ PASS |
| 主 md 未损坏：flag 合法 | 无非法 flag | `md_bad_flag_rows=0` | ✅ PASS |
| `RUNTIME_ERROR\|` count | 0 | 0 | ✅ PASS |
| `PARSE_ERROR\|` count | 0 | 0 | ✅ PASS |
| `LOCKED\|` count | 0 | 0 | ✅ PASS |

## md diff 摘要

| 字段 | before | after |
|---|---|---|
| 表格数据行 | 2 | 2 |
| repo 1 | microsoft/vscode (v1.0.0, no) | microsoft/vscode (1.137.0, yes) |
| repo 2 | PowerShell/PowerShell (v1.0.0, no, 未安装) | PowerShell/PowerShell (v7.6.6, no, 未安装) |
| 最近核对时间 | fixture 生成时间 | 本轮 API 时间（含 apiOk/apiErr/pendingReview 计数） |
| 结论 / 更新摘要 / 备注 段 | fixture 占位 | 由 step5 根据 result.json 重写 |

## result.json 结构

```json
{
  "stats": {
    "total": 2, "apiOk": 2, "apiErr": 0,
    "synced": 0, "yes": 1, "uninstalled": 1, "pendingReview": 2,
    "newReleases": 2, "flips": 1,
    "token": "set"
  },
  "items": [
    { "repo": "microsoft/vscode", "gitVer": "1.137.0", "flag": "yes", "review": true, ... },
    { "repo": "PowerShell/PowerShell", "gitVer": "v7.6.6", "flag": "no", "review": true, ... }
  ]
}
```

- JSON 可解析：`ConvertFrom-Json` 成功
- `stats` 与 `SUMMARY|` 行完全一致（apiOk=2 / apiErr=0 / yes=1 / uninstalled=1 / pendingReview=2 / total=2）
- `items[].repo` 与 md 表格 releases 链接一致
- 完整文件见 `T2-success/result-after.json`

## Verdict: **PASS**

## 证据索引

| 文件 | 内容 |
|---|---|
| `T2-success/stdout.txt` | 完整 pipeline stdout（含 `PS_VERSION\|7.6.4` marker 行） |
| `T2-success/stderr.txt` | pipeline stderr（空，0 bytes） |
| `T2-success/fixture-stdout.txt` | fixture 生成日志 |
| `T2-success/before/` / `after/` | 状态文件快照 |
| `T2-success/md-before.md` / `md-after.md` | 主 md 副本 |
| `T2-success/result-before.json`（空） / `result-after.json` | result.json 副本 |
| `T2-success/sha256-before.txt` / `sha256-after.txt` | 主 md SHA256 |
| `T2-success/lock-before.txt` / `lock-after.txt` | 锁存在性记录 |
| `T2-success/validation.json` | 结构化验证指标 |
| `T2-success/test-report.md` | 本报告 |
