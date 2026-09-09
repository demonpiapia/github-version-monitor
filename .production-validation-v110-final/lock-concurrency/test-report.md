# lock-concurrency Test Report

> **测试目标**: 两进程争锁（Prompt §17 / exec-plan-v1.10-d.md §2 Phase 9.1）
> **构造方法**: 两个 PS7 进程同时执行 `step1.ps1`
> **执行时间**: 2026-09-09 09:08:37
> **执行环境**: Windows + PowerShell 7.x
> **隔离目录**: `.production-validation-v110-final/lock-concurrency/`

## 构造方法详情

1. 通过 `GITHUB_VERSION_MONITOR_BASE` 隔离到本测试子目录
2. 生成 fixture（`create-fixture.ps1 -Scenario normal`）
3. 采集 before 状态（md / result.json / run.lock / SHA256）
4. 使用 `Start-Process -WindowStyle Hidden -PassThru` 同时启动两个 pwsh 进程
5. 两个进程同时执行 `step1.ps1`（内含 `FileMode::CreateNew` 原子互斥）
6. 合并两进程 stdout 到 `stdout.txt`

## 验证项

| 验证项 | 期望 | 结果 |
|---|---|---|
| BACKUP_OK\| 出现次数 | = 1（一个 owner） | **PASS** (count=1) |
| LOCKED\| 出现次数 | = 1（一个失败者） | **PASS** (count=1) |
| 一 owner + 一 LOCKED | 成立 | **PASS** |

## 关键 stdout 行

```
--- stdout-proc1.txt ---
BACKUP_OK|20260909-090837241

--- stdout-proc2.txt ---
LOCKED|另一轮监测持有运行锁（或陈锁判定不确定，保守不抢），本轮直接退出。
```

## 判定

**PASS**

两进程争锁时，`FileMode::CreateNew` 原子互斥确保只有一个进程成功创建锁文件并继续（输出 `BACKUP_OK|`），另一个进程捕获 `IOException` 后进入陈锁判定分支，因锁文件新鲜（ageMin < 30）→ 保守不抢 → 输出 `LOCKED|` 并退出。符合 SKILL-v1.10 的互斥模型（SKILL L30-33）。

## 附加证据

- `stdout-proc1.txt` / `stdout-proc2.txt`：各进程独立 stdout
- `stderr-proc1.txt` / `stderr-proc2.txt`：各进程独立 stderr
- `stdout.txt` / `stderr.txt`：合并后的完整 stdout/stderr
- `lock-before.txt` / `lock-after.txt`：锁状态演变
- `sha256-before.txt` / `sha256-after.txt`：SHA256 指纹演变
