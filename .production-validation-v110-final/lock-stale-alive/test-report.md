# lock-stale-alive Test Report

> **测试目标**: 陈锁 + PID 活 → 保守不抢（Prompt §17 / exec-plan-v1.10-d.md §2 Phase 9.1）
> **构造方法**: 锁文件 LastWriteTime = 31 分钟前，PID = 当前 orchestrator 进程 PID（alive）
> **执行时间**: 2026-09-09 09:08:41
> **执行环境**: Windows + PowerShell 7.x
> **隔离目录**: `.production-validation-v110-final/lock-stale-alive/`

## 构造方法详情

1. 通过 `GITHUB_VERSION_MONITOR_BASE` 隔离到本测试子目录
2. 生成 fixture（`create-fixture.ps1 -Scenario normal`）
3. 创建锁文件：
   - PID = 当前 orchestrator 进程 PID（alive）
   - LastWriteTime = 31 分钟前（陈锁）
4. 采集 before 状态
5. 执行 Step 1（`step1.ps1`）
6. 采集 after 状态

## 验证项

| 验证项 | 期望 | 结果 |
|---|---|---|
| LOCKED\| | 存在 | **PASS** |
| BACKUP_OK\| | 不存在 | **PASS** |

## 关键 stdout 行

```
LOCKED|另一轮监测持有运行锁（或陈锁判定不确定，保守不抢），本轮直接退出。
```

## Lock 状态

### Before
```
pid=<alive_pid>;start=<31min_ago>;step=1;beat=<31min_ago>
```

### After
```
（锁文件未变，Step 1 未接管）
```

## 判定

**PASS**

Step 1 陈锁判定逻辑（SKILL L51）：`$ageMin -gt 30 -and $lockPid -gt 0 -and $null -eq (Get-Process -Id $lockPid)`。当 PID 存活时，`Get-Process -Id $lockPid` 返回非 null → `$takeover = $false` → 保守不抢 → 输出 `LOCKED|`。

符合 SKILL-v1.10 的"陈锁必须同时满足锁内 PID 已死亡才允许接管"约束（SKILL L32）。

## 附加证据

- `stdout.txt` / `stderr.txt`：完整 stdout/stderr
- `lock-before.txt` / `lock-after.txt`：锁状态演变
- `sha256-before.txt` / `sha256-after.txt`：SHA256 指纹演变
