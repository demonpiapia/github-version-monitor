# T43-v18 · 6 场景全管线回归 · 测试报告

**结论：PASS**

- 测试目录：`d:\AI\Workspace\automatic\github-version-monitor\.production-validation-v18-final\T43`
- 执行器：`run-t43.ps1`（in-process，共享 PID，走 lib\step1→step5-full）
- 时间：2026-09-08 07:01 (UTC+08:00)
- PowerShell：7.6.4；GITHUB_TOKEN：已设置（长度 93）

## 1. 6 场景 fixture 设计

| # | Repo | prevGitVer | LocalVer | 场景 | 预期 |
|---|---|---|---|---|---|
| 1 | nodejs/node | v26.7.0 | v26.6.0 | normal upgrade | flag=yes |
| 2 | kubernetes/kubernetes | v1.37.0 | v1.37.0 | synced | flag=no, cmp=eq |
| 3 | grafana/grafana | v13.0.0 | 未安装 | uninstalled | flag=no |
| 4 | hashicorp/terraform | v1.15.0 | N/A | unsupported version | flag=prevFlag, review=true, reviewReasons 含 incomparable_version |
| 5 | demonpiapia/nonexistent-repo-xyz | v0.1.0 | v0.1.0 | 404 | status=not_found, gitVer='', gitDate='', flag=prevFlag, review=true |
| 6 | microsoft/typescript | v5.0.0 | v6.0.0 | versionJump | isNew=true, versionJump=true, review=true |

## 2. 关键 stdout 标记（全部命中）

- ✅ `BACKUP_OK|20260908-070124787`
- ✅ `FETCH_COMPLETE|apiOk=5 apiErr=1 total=6`
- ✅ `SUMMARY|total=6 apiOK=5 apiErr=1 synced=1 yes=3 uninstalled=1 pendingReview=3 newReleases=4 flips=2 token=set`
- ✅ `REVIEW_WRITE_OK|复核完成：3 项；stats/items 保持不变。`
- ✅ `COMMIT_OK|已原子替换主 md（数据行 6，yes/no 校验通过，repo 集合一致）。`
- ✅ `RUN_STATUS|success|fetch + 必要 review + commit + lock release 完成。`

## 3. 6 场景验证结果（来自 result-after.json）

| # | repo | status | gitVer | gitDate | flag | cmp | isNew | versionJump | review | reviewReasons | 结果 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | nodejs/node | ok | v26.8.1 | 2026-08-27 | yes | lt | true | false | false | [] | ✅ |
| 2 | kubernetes/kubernetes | ok | v1.37.0 | 2026-08-26 | no | eq | false | false | false | [] | ✅ |
| 3 | grafana/grafana | ok | v13.2.1 | 2026-09-02 | no | (empty) | true | false | false | [] | ✅ |
| 4 | hashicorp/terraform | ok | v1.16.1 | 2026-09-02 | yes | incomparable | true | false | true | [incomparable_version] | ✅ |
| 5 | demonpiapia/nonexistent-repo-xyz | not_found | (empty) | (empty) | no | (empty) | false | false | true | [not_found] | ✅ |
| 6 | microsoft/typescript | ok | v7.0.2 | 2026-08-21 | yes | lt | true | true | true | [version_jump] | ✅ |

## 4. 路径契约验证

- 主状态文件位置：`T43/.output/GitHub更新监测列表.md` ✅
- 根目录 `T43/GitHub更新监测列表.md`：不存在 ✅
- `.monitor/run.lock`：已释放（`lock-released.txt = YES_LOCK_RELEASED`）✅
- `.monitor/backups/GitHub更新监测列表.backup.20260908-070124787.md`：存在 ✅

## 5. SHA256

- md-before：`34AAF001420801F87595B2FE3BA6FA71D82F75FF95909C2208A3322680B7028D`
- md-after ：`AAE7DF17F6A298727406DC5175CF43E31AF5089D54CFC484A4416C37DC2B99F5`
- 差异符合预期（表格行 gitVer/gitDate/flag 更新 + 元信息行更新 + 三节正文替换）

## 6. 证据文件清单

- `run-t43.ps1` — 测试执行器
- `stdout.txt` — 全管线 stdout（含所有关键标记）
- `stderr.txt` — 空（无异常）
- `md-before.md` / `md-after.md` — 主 md 前后快照
- `sha256-before.txt` / `sha256-after.txt` — 主 md SHA256
- `result-after.json` — 6 个 item 完整数据 + review 复核结果
- `lock-released.txt` — 锁释放状态
- `exit-code.txt` — 退出码 0
- `.monitor/backups/` — 备份文件
- `.monitor/fetch_run.log` — 运行日志
- `.output/GitHub更新监测列表.md` — 主状态文件（写回后）

## 7. 备注

- 6 个场景全部按预期分类，无回归。
- 场景 3（uninstalled）的 cmp 字段为空字符串是设计行为：`未安装` 走 `newFlag='no'` 分支，不进入 `Compare-Ver`。
- 场景 5（404）的 `gitVer=''` / `gitDate=''` 是设计行为：`not_found` 特例清空数据字段，flag 保留 prevFlag。
- 场景 6（versionJump）的 `flag=yes` 是 `cmp=lt` 的独立结果，versionJump 只影响 review 与 reviewReasons。
