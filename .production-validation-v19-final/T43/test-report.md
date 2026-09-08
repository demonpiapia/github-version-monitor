# T43-v19 Test Report: 全场景全管线

## Fixture 场景（6 个 repo，每行独立参数）

| # | 场景 | repo | prevGitVer | localVer | 期望行为 |
|---|---|---|---|---|---|
| 1 | normal upgrade | microsoft/vscode | 1.136.0 | 1.0.0 | latest=1.136.1, cmp=lt → flag=yes, isFlip=true |
| 2 | synced | kubernetes/kubernetes | v1.37.0 | v1.37.0 | latest=v1.37.0, cmp=eq → flag=no |
| 3 | uninstalled | nodejs/node | v26.0.0 | 未安装 | 未安装强制 flag=no |
| 4 | unsupported version | rust-lang/rust | 1.97.0 | v1.2.3a | cmp=incomparable → 保留 prevFlag + review=true |
| 5 | 404 | test/nonexistent-repo-12345 | v1.0.0 | 1.0.0 | status=not_found → review=true |
| 6 | versionJump | vercel/next.js | v14.0.0 | v10.0.0 | latest=v16.3.4, major+2 → versionJump=true, review=true |

## 关键标记核验（stdout.txt）

| 标记 | 期望 | 实际 | 结果 |
|---|---|---|---|
| `BACKUP_OK\|` | 存在 | `BACKUP_OK\|20260908-145948290` | PASS |
| `FETCH_COMPLETE\|` | 存在 | `FETCH_COMPLETE\|apiOk=5 apiErr=1 total=6` | PASS |
| `SUMMARY\|` | 存在 | `SUMMARY\|total=6 apiOK=5 apiErr=1 synced=1 yes=2 uninstalled=1 pendingReview=3 newReleases=4 flips=2 token=set` | PASS |
| `REVIEW_WRITE_OK\|` | 存在（有 review 项） | `REVIEW_WRITE_OK\|复核完成：3 项；stats/items 保持不变。` | PASS |
| `COMMIT_OK\|` | 存在 | `COMMIT_OK\|已原子替换主 md（数据行 6，yes/no 校验通过，repo 集合一致）。` | PASS |
| `RUN_STATUS\|success\|` | 存在 | `RUN_STATUS\|success\|fetch + 必要 review + commit + lock release 完成。` | PASS |

## 6 场景 queryStatus 分布（result.json items）

| repo | status | cmp | flag | review | reviewReasons |
|---|---|---|---|---|---|
| microsoft/vscode | ok | lt | yes | false | [] |
| kubernetes/kubernetes | ok | eq | no | false | [] |
| nodejs/node | ok | (empty) | no | false | [] |
| rust-lang/rust | ok | incomparable | no | true | [incomparable_version] |
| test/nonexistent-repo-12345 | not_found | (empty) | no | true | [not_found] |
| vercel/next.js | ok | lt | yes | true | [version_jump] |

**queryStatus 分布**：`ok=5 / not_found=1`
**flag 分布**：`yes=2 / no=4`
**review 分布**：`true=3 / false=3`

## 数据一致性验证

| 检查项 | 期望 | 实际 | 结果 |
|---|---|---|---|
| result.json 结构完整（stats + items + review） | yes | 有 stats/items/review 三段 | PASS |
| stats.total == items.Count | 6 == 6 | 6 == 6 | PASS |
| stats.apiOk == items where status=ok | 5 | 5 | PASS |
| stats.apiErr == items where status!=ok | 1 | 1 | PASS |
| stats.yes == items where flag=yes | 2 | 2 | PASS |
| stats.uninstalled == items where localVer=未安装 | 1 | 1 | PASS |
| stats.pendingReview == items where review=true | 3 | 3 | PASS |
| stats.newReleases == items where isNew=true | 4 | 4 | PASS |
| stats.flips == items where isFlip=true | 2 | 2 | PASS |
| md 表格行数 == items.Count | 6 | 6 | PASS |
| md repo 集合 == json repo 集合 | 一致 | 一致（COMMIT_OK 已验证） | PASS |
| backup 目录存在且含时间戳备份 | yes | `.monitor/backups/GitHub更新监测列表.backup.20260908-145948290.md`（1031 字节） | PASS |
| fetch_run.log 存在且统计一致 | yes | `items=6 apiOK=5 apiErr=1 yes=2 uninstalled=1 pendingReview=3 newReleases=4 flips=2 token=set` | PASS |
| 锁已释放 | yes | `lockExists=False` | PASS |

## 最终判定

**PASS**

## 备注

- 执行方式：`run-full-pipeline.ps1 -Base <T43>` 单次执行（dot-source 模式，Phase 1 已验证 stdout 透传正常）。
- stdout 与 stderr 通过 `*>` 合并到 stdout.txt（stderr.txt 保留说明性占位）。
- 全部 6 场景 API 直连 GitHub REST（token=set），无 mock。
- 404 场景（test/nonexistent-repo-12345）符合预期触发 `not_found` + review。
- versionJump 场景（vercel/next.js，prevGitVer=v14.0.0 → latest=v16.3.4，major 差 2）触发 `version_jump` review 原因。
- unsupported version 场景（rust-lang/rust，localVer=v1.2.3a）触发 `incomparable_version` review 原因。
- 3 个 review 项全部完成复核（REVIEW_WRITE_OK 3 项），stats/items 保持不变。
