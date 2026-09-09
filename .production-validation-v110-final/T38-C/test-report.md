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
| tmp cleaned | - | 见下方 |
| lock released | - | 见下方 |

## 关键 stdout 行
`
REVIEW_WRITE_ERROR|review 原子替换失败：当文件已存在时，无法创建该文件。
RUN_STATUS|failed|review 原子替换失败，整轮终止。
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
result.json: F5A3230ADE96FBB367E573CBE4BEC6CEF3522510869C3B5F48BA02C8BD5804A2
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
**PASS**