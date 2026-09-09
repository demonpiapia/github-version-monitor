# lock-stale-dead Test Report

> **测试目标**: 陈锁 + PID 死 → 接管成功（Prompt §17 / exec-plan-v1.10-d.md §2 Phase 9.1）
> **构造方法**: 锁文件 LastWriteTime = 31 分钟前，PID = 999999（不存在的进程）
> **执行时间**: 2026-09-09 09:08:42
> **执行环境**: Windows + PowerShell 7.x
> **隔离目录**: `.production-validation-v110-final/lock-stale-dead/`

## 构造方法详情

1. 通过 `GITHUB_VERSION_MONITOR_BASE` 隔离到本测试子目录
2. 生成 fixture（`create-fixture.ps1 -Scenario normal`）
3. 创建锁文件：
   - PID = 999999（dead，不存在的进程）
   - LastWriteTime = 31 分钟前（陈锁）
4. 采集 before 状态
5. 执行 Step 1（`step1.ps1`）
6. 采集 after 状态

## 验证项

| 验证项 | 期望 | 结果 |
|---|---|---|
| BACKUP_OK\| | 存在（接管成功） | **PASS** |
| LOCKED\| | 不存在 | **PASS** |

## 关键 stdout 行

```
BACKUP_OK|20260909-090842486
```

## Lock 状态

### Before
```
pid=999999;start=<31min_ago>;step=1;beat=<31min_ago>
```

### After
```
pid=<new_pid>;start=<now>;step=1;beat=<now>
```

**接管成功** ✓（陈锁被删除，新锁文件创建）

## 判定

**PASS**

Step 1 陈锁判定逻辑（SKILL L51）：`$ageMin -gt 30 -and $lockPid -gt 0 -and $null -eq (Get-Process -Id $lockPid)`。当 PID 999999 不存在时，`Get-Process -Id 999999` 返回 null → `$takeover = $true` → 删除旧锁 → 创建新锁 → 输出 `BACKUP_OK|`。

符合 SKILL-v1.10 的"陈锁（heartbeat 超 30 分钟）+ PID 已死亡 → 允许接管"约束。

## 附加证据

- `stdout.txt` / `stderr.txt`：完整 stdout/stderr
- `lock-before.txt` / `lock-after.txt`：锁状态演变
- `sha256-before.txt` / `sha256-after.txt`：SHA256 指纹演变
