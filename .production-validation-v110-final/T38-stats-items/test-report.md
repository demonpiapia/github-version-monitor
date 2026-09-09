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
| $pat 不存在 | 不存在 | PASS |
| RUN_STATUS|failed| count = 2 (constraint #13 VIOLATION) | - | 见下方 |

## 关键 stdout 行
`
REVIEW_WRITE_ERROR|review 修改了 stats/items，拒绝覆盖 result.json。
RUN_STATUS|failed|review 程序事实完整性校验失败，整轮终止。
REVIEW_WRITE_ERROR|review 临时 JSON 校验失败，不替换 result.json。
RUNTIME_ERROR|review 失败后锁释放失败，保留锁供陈锁机制接管。
RUN_STATUS|failed|review 临时 JSON 校验失败，整轮终止。
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
result.json: 3DFD914DA259A0AB4100FF1C31D9C1D74183EE8F9C5F5566EFC93FD4AA6903CC
result.review.tmp: FILE_NOT_EXISTS
run.lock: FILE_NOT_EXISTS
`

## Lock 状态
### Before
`
LOCK_FILE_NOT_EXISTS
`

### After
`
LOCK_FILE_NOT_EXISTS
`

## 判定
**FAIL**