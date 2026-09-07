# T46-v18 · `.output` 路径契约 · 测试报告

**结论：PASS**

- 测试目录：`d:\AI\Workspace\automatic\github-version-monitor\.production-validation-v18-final\T46`
- 执行器：`run-t46.ps1`（in-process，共享 PID，仅 Step 1 + Step 2）
- 时间：2026-09-08 07:02 (UTC+08:00)
- PowerShell：7.6.4；GITHUB_TOKEN：已设置

## 1. 路径契约验证

| 检查项 | 结果 |
|---|---|
| Step 1 输出 `BACKUP_OK|...`（证明读取 `.output/GitHub更新监测列表.md` 成功） | ✅ |
| Step 2 输出 `FETCH_COMPLETE|apiOk=3 apiErr=0 total=3`（证明解析成功） | ✅ |
| Step 2 输出 `SUMMARY|total=3 apiOK=3 apiErr=0 synced=1 yes=1 uninstalled=1 pendingReview=0 newReleases=2 flips=1 token=set` | ✅ |
| `.output/GitHub更新监测列表.md` 存在 | ✅ |
| 根目录 `T46/GitHub更新监测列表.md` **不存在**（before 与 after 均 False） | ✅ |
| `.monitor/run.lock` 存在（Step 1 创建，Step 2 未释放，符合"仅 Step 1+2"的预期） | ✅ |

## 2. 关键 stdout 标记

- ✅ `BACKUP_OK|20260908-070222206`
- ✅ `FETCH_COMPLETE|apiOk=3 apiErr=0 total=3`
- ✅ `SUMMARY|total=3 apiOK=3 apiErr=0 synced=1 yes=1 uninstalled=1 pendingReview=0 newReleases=2 flips=1 token=set`

## 3. 3 场景 fixture 验证

| # | repo | localVer | 预期 | 实际 flag | 实际 cmp |
|---|---|---|---|---|---|
| 1 | nodejs/node | v26.6.0 | yes | yes | lt |
| 2 | kubernetes/kubernetes | v1.37.0 | no | no | eq |
| 3 | grafana/grafana | 未安装 | no | no | (empty) |

## 4. SHA256

- md-before：`352291BBC4000E56CCF88F42E44C9228790FEDA82F9C7C3863304ACC06EE7ADE`
- md-after ：`352291BBC4000E56CCF88F42E44C9228790FEDA82F9C7C3863304ACC06EE7ADE`
- 说明：Step 1+2 不写回主 md（写回发生在 Step 5），故 SHA256 一致是预期结果，证明 Step 1+2 只做读取+解析+查询，不产生副作用。

## 5. 证据文件清单

- `run-t46.ps1` — 测试执行器
- `stdout.txt` — Step 1 + Step 2 stdout
- `stderr.txt` — 空
- `md-before.md` / `md-after.md` — 主 md 前后快照（内容一致）
- `sha256-before.txt` / `sha256-after.txt` — 主 md SHA256（一致）
- `root-md-check.txt` — `PASS: no root md after test`
- `directory-listing.txt` — 完整目录结构
- `result-after.json` — Step 2 生成的 result.json
- `.output/GitHub更新监测列表.md` — 主状态文件
- `.monitor/run.lock` — 运行锁（Step 1 创建）
- `.monitor/backups/` — 备份文件
- `.monitor/result.json` — 完整结果 JSON

## 6. 结论

- SKILL-v1.8 严格在 `.output/GitHub更新监测列表.md` 路径下读写，根目录未产生同名文件。
- 路径契约符合 v1.8 规范。
