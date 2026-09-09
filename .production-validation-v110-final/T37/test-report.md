# T37 Test Report — 正常提交 → RUN_STATUS|success|

> **测试目标**: SKILL-v1.10 完整管线（Step 1→5 代码 + Step 6 汇报模板）在正常路径下的成功链验证
> **构造方法**: 2 个真实仓库（microsoft/vscode + torvalds/linux），localVer 低于最新 release，触发 versionJump → review=true
> **执行方式**: run-full-pipeline.ps1 单次执行 + 捕获 stdout（依据 Phase 1 lib/stdout-verification.txt 决策 PIPELINE_OK）
> **执行时间**: 2026-09-09 07:42:00
> **执行耗时**: 5.0 秒
> **执行环境**: Windows + PowerShell 7.x

## 构造方法详情

1. 通过 GITHUB_VERSION_MONITOR_BASE 隔离到 T37/ 子目录
2. 生成 fixture（create-fixture.ps1 -Scenario T37）：2 个真实仓库
   - microsoft/vscode localVer=1.0.0（预期触发 versionJump，minor 差 ≥ 10）
   - torvalds/linux localVer=6.5.0（预期触发 versionJump，minor 差 ≥ 10）
3. 采集 before 状态（md / result.json / run.lock / SHA256 / 目录清单）
4. 执行 run-full-pipeline.ps1 -BaseDir <testDir> 单次执行，捕获 stdout
5. 采集 after 状态
6. 判定完整成功链 + lock released + md updated + result.json valid

## 验证项

| 验证项 | 期望 | 结果 |
|---|---|---|
| BACKUP_OK\| | 存在 | **PASS** |
| FETCH_COMPLETE\| | 存在 | **PASS** |
| SUMMARY\| | 存在 | **PASS** |
| REVIEW_WRITE_OK\| | 存在（fixture 触发 review） | **PASS** |
| COMMIT_OK\| | 存在 | **PASS** |
| RUN_STATUS\|success\| | 存在 | **PASS** |
| RUN_STATUS\|failed\| | 不存在 | **PASS** |
| lock released (run.lock 不存在) | 已释放 | **PASS** |
| md updated (SHA256 before ≠ after) | 已更新 | **PASS** |
| result.json valid (stats/items/review) | 结构完整 | **PASS** |
| 硬门槛 (COMMIT_OK + RUN_STATUS\|failed\|) | 不违反 | **PASS** |

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

**main_md SHA256 before ≠ after** ✓（版本号已刷新）
**run.lock FILE_NOT_EXISTS after** ✓（锁已释放）
**result.json 由 Step 2 生成、Step 4 更新**（review 段被填充）

## Lock 状态

### Before
~~~
LOCK_FILE_NOT_EXISTS

~~~

### After
~~~
LOCK_FILE_NOT_EXISTS

~~~

## result.json 结构

~~~
stats=True items=True(2) review=True stats.total=2
~~~

## 判定

**PASS**

T37 完整成功链验证通过：BACKUP_OK → FETCH_COMPLETE → SUMMARY → REVIEW_WRITE_OK → COMMIT_OK → RUN_STATUS|success| 全部存在，且 RUN_STATUS|failed| 不存在。锁已释放，md 已更新，result.json 结构完整。符合 SKILL-v1.10 contract。