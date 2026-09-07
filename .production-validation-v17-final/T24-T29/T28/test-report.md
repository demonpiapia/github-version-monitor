# Test Report: T28

## Test ID
T28

## Description
Fixture with non-integer index in column 1 — uses "abc" instead of a numeric value like "1".

## Fixture File
`T28/fixture.md` — data row: `| abc | [test-repo](https://github.com/octocat/Hello-World/releases) | v1.0.0 | 2026-01-01 | 1.0.0 | no |`

## Expected Result
PARSE_ERROR — parser should detect non-integer index (column 1 must match `^\d+$`)

## Actual Result
PARSE_ERROR produced:
```
PARSE_ERROR|状态文件 schema 校验失败，本轮终止，不写回主 md。
  问题：第 1 列序号非法：| abc | [test-repo](https://github.com/octocat/Hello-World/releases) | v1.0.0 | 2026-01-01 | 1.0.0 | no |
```

## Verdict
**PASS** — Parser correctly detected non-integer index "abc" and produced PARSE_ERROR with descriptive message "第 1 列序号非法".
