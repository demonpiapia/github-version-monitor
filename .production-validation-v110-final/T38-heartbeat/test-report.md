# System.Collections.Hashtable.Name: System.Collections.Hashtable.Title

## 测试目标
System.Collections.Hashtable.Target

## 构造方法
System.Collections.Hashtable.Method

## 验证项

| 验证项 | 期望 | 结果 |
|---|---|---|| $pat 存在 | 存在 | PASS |
| $pat 存在 | 存在 | PASS |
| $pat 不存在 | 不存在 | PASS |
| lock retained（heartbeat 失败后 return，未调用 Release-LockSafely） | - | 见下方 |

## 关键 stdout 行
`
RUNTIME_ERROR|步骤4 heartbeat 失败：The process cannot access the file 'D:\AI\Workspace\automatic\github-version-monitor\.production-validation-v110-final\T38-heartbeat\.monitor\run.lock' because it is being used by another process.
RUN_STATUS|failed|步骤4 heartbeat 失败，整轮终止。
`

## SHA256 对比
### Before
`
main_md: AEAEAF44851D62375D8DF7D6E21CAF1A05DC3C64ED9B5AE894141331B3143C81
result.json: FILE_NOT_EXISTS
result.review.tmp: FILE_NOT_EXISTS
run.lock: FILE_NOT_EXISTS
`

### After
`
main_md: AEAEAF44851D62375D8DF7D6E21CAF1A05DC3C64ED9B5AE894141331B3143C81
result.json: D425B76189D0CA9C15C901D17B397390FDE4F93D9221678EC7031571DC9B1073
result.review.tmp: FILE_NOT_EXISTS
run.lock: 84249B94F6B7F0C847C110B1D560C198FD2ACF05944D4E2A0FB88DD5DEAE4525
`

## Lock 状态
### Before
`
LOCK_FILE_NOT_EXISTS
`

### After
`
pid=61692;start=2026-09-08T23:09:35.3827321+00:00;step=3;beat=2026-09-08T23:09:36.2109372+00:00
`

## 判定
**PASS**