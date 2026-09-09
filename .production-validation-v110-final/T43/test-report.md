# T43 Test Report — Full Extended Pipeline Regression

> **测试目标**: SKILL-v1.10 完整管线（Step 1→5 代码 + Step 6 汇报模板）在 6 场景 fixture 下的成功链验证
> **构造方法**: 6 个不同真实仓库 + 1 个 404 不存在仓库（共 6 场景）
>   - normal upgrade: microsoft/vscode localVer=0.0.1
>   - synced: nodejs/node localVer=<latest>（动态查询）
>   - uninstalled: facebook/react localVer=未安装
>   - unsupported: microsoft/TypeScript localVer=abc-invalid-format
>   - 404: test/nonexistent-repo-12345 localVer=1.0.0
>   - versionJump: angular/angular localVer=<lowVscode>（major 差 ≥2）
> **执行方式**: run-full-pipeline.ps1 单次执行 + 捕获 stdout（依据 Phase 1 lib/stdout-verification.txt 决策 PIPELINE_OK）
> **执行时间**: 2026-09-09 08:01:28
> **执行耗时**: 0.0 秒
> **执行环境**: Windows + PowerShell 7.x

## 构造方法详情

1. 通过 GITHUB_VERSION_MONITOR_BASE 隔离到 T43/ 子目录
2. 生成 fixture（create-fixture.ps1 -Scenario T43）：6 场景
3. 采集 before 状态
4. 执行 run-full-pipeline.ps1 -BaseDir <testDir> 单次执行，捕获 stdout
5. 采集 after 状态
6. 判定完整成功链 + 数据一致性

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
| result.json valid (stats/items/review + stats.total==items.count) | 结构完整 | **PASS** |
| .output/...md 表格行与 result.json items 一致 | 一致 | **PASS** |
| backup 目录存在且含时间戳备份 | 存在 | **PASS** |
| fetch_run.log 存在 | 存在 | **PASS** |
| lock released (run.lock 不存在) | 已释放 | **PASS** |
| 硬门槛 (COMMIT_OK + RUN_STATUS\|failed\|) | 不违反 | **PASS** |

## 关键 stdout 行

~~~
BACKUP_OK|20260909-080131893
FETCH_COMPLETE|apiOk=5 apiErr=1 total=6
SUMMARY|total=6 apiOK=5 apiErr=1 synced=1 yes=2 uninstalled=1 pendingReview=3 newReleases=5 flips=2 token=set
REVIEW_WRITE_OK|复核完成：3 项；stats/items 保持不变。
COMMIT_OK|已原子替换主 md（数据行 6，yes/no 校验通过，repo 集合一致）。
RUN_STATUS|success|fetch + 必要 review + commit + lock release 完成。
~~~

## 数据一致性详情

- result.json: stats=True items=True(6) review=True stats.total=6 items.count=6 consistent=True
- md 表格行数: 6, items 数: 6, 一致: True
- backup 目录: True, backup 文件数: 1
- fetch_run.log: True, 行数: 1
- lock released: True

## SHA256 对比

### Before
~~~
main_md: 71FDCB368625E98C3ADFAFBA32CF1DBF306761C2D3C47EB7FF9582F4E803A04F
result.json: FILE_NOT_EXISTS
result.fetch.tmp: FILE_NOT_EXISTS
result.review.tmp: FILE_NOT_EXISTS
run.lock: FILE_NOT_EXISTS

~~~

### After
~~~
main_md: 2EF4EFCE9EE354BE7C832C720ECC0CC9554B0FE0105D718EA54B89D5D6AFA7F8
result.json: 34D518BA6C86F454139BE2E380035E4DBF56F5C20907DA634780F581881DD3B7
result.fetch.tmp: FILE_NOT_EXISTS
result.review.tmp: FILE_NOT_EXISTS
run.lock: FILE_NOT_EXISTS

~~~

## Lock 状态

### Before
~~~
LOCK_FILE_NOT_EXISTS

~~~

### After
~~~
LOCK_FILE_NOT_EXISTS

~~~

## 判定

**PASS**

T43 完整成功链验证通过：BACKUP_OK → FETCH_COMPLETE → SUMMARY → REVIEW_WRITE_OK → COMMIT_OK → RUN_STATUS|success| 全部存在。6 场景 fixture 覆盖 normal upgrade / synced / uninstalled / unsupported / 404 / versionJump。数据一致性（result.json / md 表格 / backup / fetch_run.log / lock）全部通过。