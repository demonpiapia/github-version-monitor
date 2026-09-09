# Phase 4 Report — T37 正常成功回归

> **Phase**: 4
> **模块**: T37 — 正常提交 → RUN_STATUS|success|
> **优先级**: 硬门槛
> **执行时间**: 2026-09-09 07:42:00
> **执行耗时**: 5.0 秒
> **判定**: **PASS**

## 执行摘要

- Fixture: 2 个真实仓库（microsoft/vscode localVer=1.0.0 + torvalds/linux localVer=6.5.0）
- 执行方式: run-full-pipeline.ps1 单次执行（Phase 1 stdout 透传决策 PIPELINE_OK）
- 隔离: GITHUB_VERSION_MONITOR_BASE = <T37 test dir>
- 生产根目录 .output/GitHub更新监测列表.md: 未触碰

## 验证项结果

| 验证项 | 结果 |
|---|---|
| BACKUP_OK\| 存在 | PASS |
| FETCH_COMPLETE\| 存在 | PASS |
| SUMMARY\| 存在 | PASS |
| REVIEW_WRITE_OK\| 存在（条件性） | PASS |
| COMMIT_OK\| 存在 | PASS |
| RUN_STATUS\|success\| 存在 | PASS |
| RUN_STATUS\|failed\| 不存在 | PASS |
| lock released | PASS |
| md updated | PASS |
| result.json valid | PASS |
| 硬门槛 (COMMIT_OK + RUN_STATUS\|failed\|) 不违反 | PASS |

## 关键 stdout 行

~~~
BACKUP_OK|20260909-074156642
FETCH_COMPLETE|apiOk=1 apiErr=1 total=2
SUMMARY|total=2 apiOK=1 apiErr=1 synced=0 yes=1 uninstalled=0 pendingReview=1 newReleases=1 flips=1 token=set
REVIEW_WRITE_OK|复核完成：1 项；stats/items 保持不变。
COMMIT_OK|已原子替换主 md（数据行 2，yes/no 校验通过，repo 集合一致）。
RUN_STATUS|success|fetch + 必要 review + commit + lock release 完成。
~~~

## SHA256 对比

### Before
~~~
main_md: 51DDFBEF268D5E68A79B2207C68A359CE3A3D549F971F95E487F447E2716298B
result.json: FILE_NOT_EXISTS
result.fetch.tmp: FILE_NOT_EXISTS
result.review.tmp: FILE_NOT_EXISTS
run.lock: FILE_NOT_EXISTS

~~~

### After
~~~
main_md: 72960B3D2D47C5D35C58DF7E1E8ABAAF50B440FFBA836B27FA7E81BD281DDC1B
result.json: 0C9B6CEC45551B073BFF61418B93655A8FBC3D90B2107FDA7D861FC64BA8FC57
result.fetch.tmp: FILE_NOT_EXISTS
result.review.tmp: FILE_NOT_EXISTS
run.lock: FILE_NOT_EXISTS

~~~

## 产出文件

- T37/before/ — 目录清单
- T37/after/ — 目录清单
- T37/stdout.txt — 完整 stdout（单次执行）
- T37/stderr.txt — stderr 占位
- T37/test-report.md — 详细测试报告
- T37/md-before.md / T37/md-after.md
- T37/result-before.json / T37/result-after.json
- T37/sha256-before.txt / T37/sha256-after.txt
- T37/lock-before.txt / T37/lock-after.txt
- T37/fixture-stdout.txt
- phase4-stdout.txt / phase4-stderr.txt
- phase4-report.md
- phase-progress.json

## 判定

**PASS**

T37 硬门槛通过。SKILL-v1.10 正常路径行为符合 contract。