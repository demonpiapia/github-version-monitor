# Phase 6 Report — T43 + T46

> **Phase**: 6
> **模块**: T43 Full Extended Pipeline Regression + T46 .output State Path Regression
> **优先级**: 关键
> **执行时间**: 2026-09-09 08:01:43
> **执行耗时**: 14.6 秒
> **判定**: T43=**PASS**, T46=**PASS**

## 执行摘要

- T43: 6 场景 fixture + 完整 Step 1→5 管线
- T46: T46 测试目录 + Step 1 + Step 2（不执行 Step 5）
- 隔离: GITHUB_VERSION_MONITOR_BASE = <test dir>
- 生产根目录 .output/GitHub更新监测列表.md: 未触碰

## T43 验证项结果

| 验证项 | 结果 |
|---|---|
| BACKUP_OK\| 存在 | PASS |
| FETCH_COMPLETE\| 存在 | PASS |
| SUMMARY\| 存在 | PASS |
| REVIEW_WRITE_OK\| 存在（条件性） | PASS |
| COMMIT_OK\| 存在 | PASS |
| RUN_STATUS\|success\| 存在 | PASS |
| RUN_STATUS\|failed\| 不存在 | PASS |
| result.json valid | PASS |
| .output/...md 表格行与 result.json items 一致 | PASS |
| backup 目录存在且含时间戳备份 | PASS |
| fetch_run.log 存在 | PASS |
| lock released | PASS |
| 硬门槛 (COMMIT_OK + RUN_STATUS\|failed\|) 不违反 | PASS |

## T46 验证项结果

| 验证项 | 结果 |
|---|---|
| .output/GitHub更新监测列表.md 存在 | PASS |
| 根目录不存在 GitHub更新监测列表.md | PASS |
| 读取 .output/ 写回 .output/ | N/A（由 T43 覆盖） |
| backup 基于 .output 状态文件 | N/A（由 T43 覆盖） |

## 关键 stdout 行

### T43
~~~
BACKUP_OK|20260909-080131893
FETCH_COMPLETE|apiOk=5 apiErr=1 total=6
SUMMARY|total=6 apiOK=5 apiErr=1 synced=1 yes=2 uninstalled=1 pendingReview=3 newReleases=5 flips=2 token=set
REVIEW_WRITE_OK|复核完成：3 项；stats/items 保持不变。
COMMIT_OK|已原子替换主 md（数据行 6，yes/no 校验通过，repo 集合一致）。
RUN_STATUS|success|fetch + 必要 review + commit + lock release 完成。
~~~

### T46
~~~
BACKUP_OK|20260909-080141532

FETCH_COMPLETE|apiOk=1 apiErr=0 total=1
SUMMARY|total=1 apiOK=1 apiErr=0 synced=0 yes=1 uninstalled=0 pendingReview=0 newReleases=1 flips=1 token=set
{
  "stats": {
    "total": 1,
    "apiOk": 1,
    "apiErr": 0,
    "synced": 0,
    "yes": 1,
    "uninstalled": 0,
    "pendingReview": 0,
    "newReleases": 1,
    "flips": 1,
    "token": "set"
  },
  "items": [
    {
      "repo": "microsoft/vscode",
      "name": "VS Code",
      "gitVer": "1.136.2",
      "gitDate": "2026-09-09",
      "localVer": "0.0.1",
      "flag": "yes",
      "prevFlag": "no",
      "latest": "1.136.2",
      "publishedUtc": "2026-09-08T17:54:34Z",
      "status": "ok",
      "cmp": "lt",
      "isNew": true,
      "isFlip": true,
      "versionJump": false,
      "dateSuspicious": false,
      "review": false,
      "reviewReasons": [],
      "error": ""
    }
  ]
}

~~~

## 产出文件

- T43/before/ — 目录清单
- T43/after/ — 目录清单
- T43/stdout.txt — 完整 stdout（单次执行）
- T43/stderr.txt — stderr 占位
- T43/test-report.md — 详细测试报告
- T43/md-before.md / T43/md-after.md
- T43/result-before.json / T43/result-after.json
- T43/sha256-before.txt / T43/sha256-after.txt
- T43/lock-before.txt / T43/lock-after.txt
- T43/fixture-stdout.txt
- T46/before/ — 目录清单
- T46/after/ — 目录清单
- T46/stdout.txt — 完整 stdout（Step 1 + Step 2 拼接）
- T46/stdout-step1.txt / T46/stdout-step2.txt — 各 step 独立 stdout
- T46/stderr.txt — stderr 占位
- T46/test-report.md — 详细测试报告
- T46/md-before.md / T46/md-after.md
- T46/result-before.json / T46/result-after.json
- T46/sha256-before.txt / T46/sha256-after.txt
- T46/lock-before.txt / T46/lock-after.txt
- T46/directory-listing.txt — 测试目录清单
- T46/root-md-check.txt — 根目录 MD 检查
- T46/fixture-stdout.txt
- phase6-stdout.txt / phase6-stderr.txt
- phase6-report.md
- phase-progress.json

## 判定

- T43: **PASS**
- T46: **PASS**

Phase 6 关键优先级通过。T43 完整管线成功链 + 数据一致性全部通过；T46 路径契约验证通过。