# Test Report: T24

## Test ID
T24

## Description
Fixture with 5 columns in data row (one column removed from the valid 6-column format). The last column (是否更新 / flag) was omitted, leaving 5 cells.

## Fixture File
`T24/fixture.md` — data row: `| 1 | [test-repo](https://github.com/octocat/Hello-World/releases) | v1.0.0 | 2026-01-01 | 1.0.0 |`

## Expected Result
PARSE_ERROR — parser should detect column count mismatch (5 != 6)

## Actual Result
PARSE_ERROR produced:
```
PARSE_ERROR|状态文件 schema 校验失败，本轮终止，不写回主 md。
  问题：列数 5（应为 6）：| 1 | [test-repo](https://github.com/octocat/Hello-World/releases) | v1.0.0 | 2026-01-01 | 1.0.0 |
```

## Verdict
**PASS** — Parser correctly detected 5-column row and produced PARSE_ERROR with descriptive message "列数 5（应为 6）".
