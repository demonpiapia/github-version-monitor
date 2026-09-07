# Test Report: T25

## Test ID
T25

## Description
Fixture with 7 columns in data row (one extra column added to the valid 6-column format). An "extra" column was appended, making 7 cells.

## Fixture File
`T25/fixture.md` — data row: `| 1 | [test-repo](https://github.com/octocat/Hello-World/releases) | v1.0.0 | 2026-01-01 | 1.0.0 | no | extra |`

## Expected Result
PARSE_ERROR — parser should detect column count mismatch (7 != 6)

## Actual Result
PARSE_ERROR produced:
```
PARSE_ERROR|状态文件 schema 校验失败，本轮终止，不写回主 md。
  问题：列数 7（应为 6）：| 1 | [test-repo](https://github.com/octocat/Hello-World/releases) | v1.0.0 | 2026-01-01 | 1.0.0 | no | extra |
```

## Verdict
**PASS** — Parser correctly detected 7-column row and produced PARSE_ERROR with descriptive message "列数 7（应为 6）".
