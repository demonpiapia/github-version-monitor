# process-kill Test Report

> **测试目标**: Stop-Process 中途终止完整管线，验证重运行后无损坏（Prompt §18 / exec-plan-v1.10-d.md §2 Phase 9.2）
> **构造方法**: 启动完整管线（mock + Step 1→5），在 Step 1 完成后、Step 2 执行前 3 秒延迟窗口内 Stop-Process 终止
> **执行时间**: 2026-09-09 09:08:43 - 09:08:49
> **执行环境**: Windows + PowerShell 7.x
> **隔离目录**: `.production-validation-v110-final/process-kill/`

## 构造方法详情

1. 通过 `GITHUB_VERSION_MONITOR_BASE` 隔离到本测试子目录
2. 生成 fixture（`create-fixture.ps1 -Scenario T37`）：2 个真实仓库（microsoft/vscode + torvalds/linux）
3. 采集 before 状态
4. 创建 `kill-wrapper.ps1`：加载 mock + Step 1 + 3 秒延迟 + Step 2-5
5. 使用 `Start-Process -WindowStyle Hidden -PassThru` 启动后台 pwsh 进程执行管线
6. 等待 2 秒后 `Stop-Process -Force` 终止（此时应处于 Step 1 后、Step 2 前的 3 秒延迟窗口）
7. 采集 kill 后状态（lock / backup / result.json / main md）
8. 将锁文件 LastWriteTime 回退 31 分钟（模拟真实陈锁场景，让重运行触发陈锁接管）
9. 重运行完整管线（`rerun-wrapper.ps1`），验证恢复能力
10. 采集 after 状态

## 验证项

| 验证项 | 期望 | 结果 |
|---|---|---|
| Stop-Process 真实执行 | stop_result=STOPPED | **PASS** |
| step_reached | Step2-delay（在 Step 1 后、Step 2 前的延迟窗口） | **PASS** |
| 重运行成功 | stdout-attempt2 含 RUN_STATUS\|success\| 或 BACKUP_OK\| | **PASS** |
| result.json 未损坏 | result-after.json 存在且 JSON 有效 | **PASS** |
| main md 未错误提交 | md-after.md 存在且有效 | **PASS** |
| lock 已释放 | lock-after.txt = LOCK_FILE_NOT_EXISTS | **PASS** |
| backup 未损坏 | backup_count ≥ 1（Step 1 提前备份） | **PASS** (count=1) |

## 关键 stdout 行

### Attempt 1（被 kill 的进程）
```
BACKUP_OK|20260909-090843739
KILL_WRAPPER_STEP2_DELAY_START
```
（进程在 Step 1 完成后、Step 2 前的 3 秒延迟窗口被 Stop-Process 终止）

### Attempt 2（重运行）
```
BACKUP_OK|20260909-090845985
FETCH_COMPLETE|apiOk=0 apiErr=2 total=2
SUMMARY|total=2 apiOK=0 apiErr=2 ...
REVIEW_WRITE_OK|复核完成：2 项；stats/items 保持不变。
COMMIT_OK|已原子替换主 md（数据行 2，yes/no 校验通过，repo 集合一致）。
RUN_STATUS|success|fetch + 必要 review + commit + lock release 完成。
```

## Kill 后状态

```
kill_time: 2026-09-09T09:08:45.2766876+08:00
pipeline_pid: 61024
stop_result: STOPPED
step_reached: Step2-delay
lock_state: HELD pid=61024 alive=False ageMin=0.0
backup_count: 1
result_exists: False
result_valid_json: False
md_exists: True
md_valid: True
trash_count: 0
```

**关键观察**：
- `stop_result=STOPPED` ✓（Stop-Process 真实执行）
- `step_reached=Step2-delay` ✓（在 Step 1 完成后、Step 2 前的延迟窗口被终止）
- `lock_state=HELD pid=61024 alive=False ageMin=0.0`（锁文件仍存在，PID 已死，但未达陈锁阈值 30 分钟）
- `backup_count=1` ✓（Step 1 提前备份成功，未损坏）
- `result_exists=False` ✓（Step 2 未执行，result.json 未创建，无损坏）
- `md_exists=True, md_valid=True` ✓（主 md 未被错误提交，保持原状）

## 重运行验证

重运行前，将锁文件 LastWriteTime 回退 31 分钟（模拟真实陈锁场景），让 Step 1 的陈锁接管机制触发（PID 死 + ageMin>30 → takeover 成功）。

重运行结果：
- `BACKUP_OK|` ✓（Step 1 陈锁接管成功，新备份创建）
- `FETCH_COMPLETE|` ✓（Step 2 完成，result.json 生成）
- `REVIEW_WRITE_OK|` ✓（Step 4 完成，review 写入）
- `COMMIT_OK|` ✓（Step 5 提交成功）
- `RUN_STATUS|success|` ✓（最终成功）
- `lock-after.txt = LOCK_FILE_NOT_EXISTS` ✓（锁已释放）

## 判定

**PASS**

Process Kill 回归验证通过：
1. `Stop-Process -Force` 真实执行（stop_result=STOPPED）
2. 管线在 Step 1 完成后、Step 2 前的延迟窗口被终止
3. Kill 后无损坏：
   - lock：锁文件存在但 PID 死（陈锁机制可接管）
   - backup：1 个有效备份（Step 1 提前备份）
   - result.json：未创建（Step 2 未执行）
   - main md：保持原状（未错误提交）
4. 重运行后完全恢复：
   - 陈锁接管成功（Step 1）
   - 完整管线执行成功（Step 2→5）
   - 最终输出 `RUN_STATUS|success|`
   - 锁已释放

符合 SKILL-v1.10 的"不得出现错误提交"约束（Prompt §18）。

## 附加证据

- `kill-wrapper.ps1` / `rerun-wrapper.ps1`：测试 harness
- `stdout-attempt1.txt` / `stderr-attempt1.txt`：被 kill 的进程 stdout/stderr
- `stdout-attempt2.txt` / `stderr-attempt2.txt`：重运行进程 stdout/stderr
- `stdout.txt` / `stderr.txt`：合并后的完整 stdout/stderr
- `kill-state.txt`：kill 后状态快照
- `lock-before.txt` / `lock-kill.txt` / `lock-after.txt`：锁状态演变
- `sha256-before.txt` / `sha256-kill.txt` / `sha256-after.txt`：SHA256 指纹演变
- `md-before.md` / `md-kill.md` / `md-after.md`：主 md 演变
- `result-before.json` / `result-kill.json` / `result-after.json`：result.json 演变
