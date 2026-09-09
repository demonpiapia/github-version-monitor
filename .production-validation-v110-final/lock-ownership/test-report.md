# lock-ownership Test Report

> **测试目标**: 外来 PID 持有锁文件时，Step 5 拒绝释放（Prompt §17 / exec-plan-v1.10-d.md §2 Phase 9.1）
> **构造方法**: Step 1-4 正常执行后篡改锁文件 PID 为 999999，再执行 Step 5
> **执行时间**: 2026-09-09 09:08:39
> **执行环境**: Windows + PowerShell 7.x
> **隔离目录**: `.production-validation-v110-final/lock-ownership/`

## 构造方法详情

1. 通过 `GITHUB_VERSION_MONITOR_BASE` 隔离到本测试子目录
2. 生成 fixture（`create-fixture.ps1 -Scenario normal`）
3. 采集 before 状态
4. 同进程 dot-source 执行 Step 1→4（正常完成，锁文件 PID = 当前进程）
5. 篡改锁文件 PID 为 999999（外来值）
6. 执行 Step 5（`step5-full.ps1`）— 应在 ownership 校验处失败
7. 采集 after 状态

## 验证项

| 验证项 | 期望 | 结果 |
|---|---|---|
| OWNERSHIP_INJECTED\|pid=999999 | 存在（注入确认） | **PASS** |
| RUNTIME_ERROR\|释放锁前 ownership 校验失败 | 存在 | **PASS** |
| RUN_STATUS\|failed\|主 md 提交状态不可否认 | 存在 | **PASS** |
| RUN_STATUS\|success\| | 不存在 | **PASS** |
| 外来锁保留（lock-after.txt 含 pid=999999） | 存在 | **PASS** |

## 关键 stdout 行

```
BACKUP_OK|20260909-090838594
FETCH_COMPLETE|apiOk=1 apiErr=0 total=1
REVIEW_WRITE_OK|...
OWNERSHIP_INJECTED|pid=999999
COMMIT_OK|已原子替换主 md（数据行 1，yes/no 校验通过，repo 集合一致）。
RUNTIME_ERROR|释放锁前 ownership 校验失败（锁内 PID 与当前进程不一致或锁不可读），未删除锁文件。
RUN_STATUS|failed|主 md 提交状态不可否认，但运行锁未安全释放。
```

## Lock 状态

### Before
```
LOCK_FILE_NOT_EXISTS
```

### After
```
pid=999999;start=2026-09-09T01:08:39.7445564+00:00;step=4;beat=2026-09-09T01:08:39.7445564+00:00
```

**外来锁保留** ✓（pid=999999 未被删除）

## 判定

**PASS**

Step 5 ownership 校验（SKILL L637-L644）正确识别锁内 PID (999999) ≠ 当前进程 PID，拒绝删除锁文件，输出 `RUNTIME_ERROR|释放锁前 ownership 校验失败` + `RUN_STATUS|failed|主 md 提交状态不可否认`。绝不输出 `RUN_STATUS|success|`。

核心 invariant 验证：
```
commitSucceeded = True  (COMMIT_OK| 存在)
lockReleased    = False (RUNTIME_ERROR| + RUN_STATUS|failed|)
        ↓
RUN_STATUS|failed| = True
RUN_STATUS|success| = False
```

## 附加证据

- `ownership-wrapper.ps1`：同进程注入 harness
- `stdout.txt` / `stderr.txt`：完整 stdout/stderr
- `lock-before.txt` / `lock-after.txt`：锁状态演变
- `sha256-before.txt` / `sha256-after.txt`：SHA256 指纹演变
- `md-before.md` / `md-after.md`：主 md 演变
- `result-before.json` / `result-after.json`：result.json 演变
