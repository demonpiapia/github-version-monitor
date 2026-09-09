# T39 Test Report — Commit 成功 + 锁释放失败 → RUN_STATUS|failed|

> **测试目标**: 验证 SKILL-v1.10 在 commitSucceeded=true + lockReleased=false 时输出 RUN_STATUS|failed|，绝不输出 RUN_STATUS|success|
> **构造方法**: 同进程 dot-source Step 1-4 → Step 5 harness（内部注入 pid=999999）
> **执行时间**: 2026-09-09 07:52:15
> **执行耗时**: 5.1 秒
> **执行环境**: Windows + PowerShell 7.x

## 构造方法详情

1. 通过 GITHUB_VERSION_MONITOR_BASE 隔离到 T39/ 子目录
2. 生成 fixture（create-fixture.ps1 -Scenario T37）：2 个真实仓库
   - microsoft/vscode localVer=1.0.0（触发 versionJump → review=true）
   - torvalds/linux localVer=6.5.0（404 → review=true）
3. 采集 before 状态（md / result.json / run.lock / SHA256 / 目录清单）
4. 执行 t39-wrapper.ps1（dot-source Step 1-4 同进程），确保 result.json 就绪、锁存在且 PID=当前进程
5. 执行 step5-t39-harness.ps1（dot-source Step 5 同进程，harness 内部在 L636/L637 之间注入 pid=999999）
6. 采集 after 状态 + lock-after-modify.txt（harness 注入后、锁释放尝试前的锁状态）
7. 判定核心 invariant：commitSucceeded=true + lockReleased=false → RUN_STATUS|failed|

## 验证项

| 验证项 | 期望 | 结果 |
|---|---|---|
| COMMIT_OK\| | 存在（提交本身成功） | **PASS** |
| RUNTIME_ERROR\| | 存在（锁释放失败） | **PASS** |
| RUN_STATUS\|failed\| | 存在 | **PASS** |
| RUN_STATUS\|success\| | 不存在 | **PASS** |
| lock-after-modify.txt PID=999999 | 存在 | **PASS** |
| lock-after.txt 锁仍存在（未释放） | 存在 | **PASS** |
| 核心 invariant (commitSucceeded=true + lockReleased=false → RUN_STATUS\|failed\|) | 成立 | **PASS** |

## 核心 invariant 验证

`
commitSucceeded = True
lockReleased = False
        ↓
RUN_STATUS|failed| = True
RUN_STATUS|success| = False
`

**invariant 成立 = True**

即：commit 成功但锁未释放时，绝不输出 RUN_STATUS|success|。

## 关键 stdout 行

~~~
COMMIT_OK|已原子替换主 md（数据行 2，yes/no 校验通过，repo 集合一致）。
RUNTIME_ERROR|释放锁前 ownership 校验失败（锁内 PID 与当前进程不一致或锁不可读），未删除锁文件。
RUN_STATUS|failed|主 md 提交状态不可否认，但运行锁未安全释放。

~~~

## SHA256 对比

### Before
~~~
main_md: 51DDFBEF268D5E68A79B2207C68A359CE3A3D549F971F95E487F447E2716298B
result.json: FILE_NOT_EXISTS
run.lock: FILE_NOT_EXISTS

~~~

### After
~~~
main_md: 5EDF292E1D28BC8CCF8ABFEEBA9B026610EDF87A5F23118DF423F2649FEE03E6
result.json: A092E94B9074CACAFEB0E56609504A79EB39A334F4EDE38822B3AC1C85C33234
run.lock: 200DABB593E52C7AB1AF8E6683E5ABB2E05B465CD1117AE9940CE87813CC8C71

~~~

## Lock 状态

### Before (Step 1 创建后，PID=当前进程)
~~~
pid=30168;start=2026-09-08T23:52:11.3951715+00:00;step=1;beat=2026-09-08T23:52:11.3951715+00:00


~~~

### After Step 1-4 (锁仍存在，PID=当前进程)
~~~
pid=999999;ts=2026-09-09T07:52:15.0345115+08:00


~~~

### After Harness (PID=999999，ownership 校验失败，锁未释放)
~~~
pid=999999;ts=2026-09-09T07:52:15.0345115+08:00


~~~

## 判定

**PASS**

T39 核心 invariant 验证通过：commitSucceeded=true + lockReleased=false → RUN_STATUS|failed|。COMMIT_OK| 存在（提交本身成功），RUNTIME_ERROR| 存在（锁释放失败），RUN_STATUS|failed| 存在，RUN_STATUS|success| 不存在。lock-after-modify.txt 中 PID=999999，lock-after.txt 确认锁仍存在（未释放）。符合 SKILL-v1.10 contract，未破坏上一版本已经正确的 invariant。