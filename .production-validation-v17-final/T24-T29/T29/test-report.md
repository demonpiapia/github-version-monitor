# Test Report: T29

## Test ID
T29

## Description
Four fixtures, each missing one of the required write-back anchor sections: `## 结论`, `## 更新摘要`, `## 备注`, `## 核对方法`. Each must produce PARSE_ERROR.

## Fixture Files
| Fixture | Missing Section | Expected | Actual |
|---|---|---|---|
| `fixture_no_conclusion.md` | `## 结论` | PARSE_ERROR | PARSE_ERROR — "缺少写回锚点：## 结论" |
| `fixture_no_update_summary.md` | `## 更新摘要` | PARSE_ERROR | PARSE_ERROR — "缺少写回锚点：## 更新摘要" |
| `fixture_no_remarks.md` | `## 备注` | PARSE_ERROR | PARSE_ERROR — "缺少写回锚点：## 备注" |
| `fixture_no_verify_method.md` | `## 核对方法` | PARSE_ERROR | PARSE_ERROR — "缺少写回锚点：## 核对方法" |

## Expected Result
Each fixture missing an anchor section should produce PARSE_ERROR with the corresponding "缺少写回锚点" message.

## Actual Result
All 4 fixtures produced PARSE_ERROR with the correct missing-anchor message:
```
=== fixture_no_conclusion ===
PARSE_ERROR|状态文件 schema 校验失败，本轮终止，不写回主 md。
  问题：缺少写回锚点：## 结论

=== fixture_no_update_summary ===
PARSE_ERROR|状态文件 schema 校验失败，本轮终止，不写回主 md。
  问题：缺少写回锚点：## 更新摘要

=== fixture_no_remarks ===
PARSE_ERROR|状态文件 schema 校验失败，本轮终止，不写回主 md。
  问题：缺少写回锚点：## 备注

=== fixture_no_verify_method ===
PARSE_ERROR|状态文件 schema 校验失败，本轮终止，不写回主 md。
  问题：缺少写回锚点：## 核对方法
```

## Verdict
**PASS** — All 4 sub-tests passed. Each missing anchor section was correctly detected and produced PARSE_ERROR with the appropriate message.
