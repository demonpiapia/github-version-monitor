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
| result.review.tmp 未创建 | - | 见下方 |
| ACL 还原成功 | - | 见下方 |

## 关键 stdout 行
`
REVIEW_WRITE_ERROR|review 临时文件写入失败：Access to the path 'D:\AI\Workspace\automatic\github-version-monitor\.production-validation-v110-final\T38-A\.monitor\result.review.tmp' is denied.
RUN_STATUS|failed|review 写入失败，整轮终止。
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
result.json: BE450218805F6C0426ECED588FDE3205096BD20F1204B1371C3FF042535D330C
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