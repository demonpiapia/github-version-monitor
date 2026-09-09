# T23 Test Report — md 原子替换失败

> **测试目标**: SKILL Step 5 `Move-Item $tmp -> $md` 真实失败
> **构造方法**: 文件锁方案（后台进程以 `FileShare::Read` 打开主 md，允许读但阻止替换）
> **执行时间**: 2026-09-09 07:25:04
> **执行环境**: Windows + PowerShell 7.x

## 构造方法详情

1. 通过 `GITHUB_VERSION_MONITOR_BASE` 隔离到 `T23/` 子目录
2. 生成 fixture（`create-fixture.ps1 -Scenario normal`）
3. 同进程内执行 Step 1→4（正常完成，产生 result.json + 更新 md 状态）
4. 启动 `lock-holder.ps1` 后台进程（`Start-Process -WindowStyle Hidden -PassThru`），以 `FileShare::Read` 打开主 md 文件
5. 等待 3 秒确保锁已建立（lock holder 输出 `LOCK_HELD|...|share=Read`）
6. 执行 Step 5（`step5-full.ps1`）— `Move-Item $tmp -> $md` 应因目标文件被独占而失败
7. 测试后 `Stop-Process` 终止 lock holder

## 验证项

| 验证项 | 期望 | 结果 |
|---|---|---|
| RUNTIME_ERROR\|主 md 原子替换失败 | 存在 | **PASS** |
| RUN_STATUS\|failed\|主 md 未提交 | 存在 | **PASS** |
| COMMIT_OK\| | 不存在 | **PASS** |
| RUN_STATUS\|success\| | 不存在 | **PASS** |
| 主 md unchanged (SHA256 before == after) | 一致 | **PASS** |
| md.tmp cleaned | 不存在 | **PASS** |
| lock released (run.lock 不存在) | 已释放 | **PASS** |

## 关键 stdout 行

```
REVIEW_WRITE_OK|复核完成：0 项；stats/items 保持不变。
T23_LOCKHOLDER_STARTED|pid=54108
RUNTIME_ERROR|主 md 原子替换失败：当文件已存在时，无法创建该文件。
RUN_STATUS|failed|主 md 未提交。
T23_LOCKHOLDER_STOPPED
```

## SHA256 对比

### Before
```
main_md: AEAEAF44851D62375D8DF7D6E21CAF1A05DC3C64ED9B5AE894141331B3143C81
result.json: FILE_NOT_EXISTS
md.tmp: FILE_NOT_EXISTS
run.lock: FILE_NOT_EXISTS
```

### After
```
main_md: AEAEAF44851D62375D8DF7D6E21CAF1A05DC3C64ED9B5AE894141331B3143C81
result.json: 880B6B2588FA755AE686B98A82F82939BBDC23CAB4F380B78AFB66A98A177531
md.tmp: FILE_NOT_EXISTS
run.lock: FILE_NOT_EXISTS
```

**main_md SHA256 before == after** ✓（主 md 未被修改，原子替换失败）
**md.tmp FILE_NOT_EXISTS** ✓（Step 5 catch 块执行 `Remove-Item $tmp` 清理了 tmp）
**result.json 由 Step 2 生成**（Step 5 未修改，符合预期）
**run.lock 已释放** ✓（Step 5 末尾的 ownership 校验 + 锁释放逻辑正常执行）

## Lock 状态

### Before
```
LOCK_FILE_NOT_EXISTS
```

### After
```
LOCK_FILE_NOT_EXISTS
```

## Lock Holder 证据

- `lock-holder-stdout.txt`: `LOCK_HELD|...|pid=54108|share=Read`（确认锁已建立）
- `lock-holder-stderr.txt`: 空（无错误）

## 判定

**PASS**

Step 5 md 原子替换失败路径行为符合 SKILL-v1.10 contract：
- 异常被 catch 捕获并输出 `RUNTIME_ERROR|主 md 原子替换失败：...`
- tmp 被清理（`Remove-Item $tmp -Force -ErrorAction SilentlyContinue`）
- 锁被正确释放（run.lock 已删除）
- 输出 `RUN_STATUS|failed|主 md 未提交。` 作为终态
- 不输出 `COMMIT_OK|` 或 `RUN_STATUS|success|`

## 附加证据

- `tmp-existence.txt`: `md.tmp_exists_after: False`
