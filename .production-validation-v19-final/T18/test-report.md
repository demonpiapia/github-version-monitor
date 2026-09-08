# T18 Test Report: 9 Non-OK State Tests

## Purpose
验证 SKILL-v1.9 状态机 9 种非 ok 状态（SKILL L132-140）下：
- queryStatus 正确分类
- gitVer/gitDate/flag 保留上轮状态（not_found 特例：gitVer/gitDate 清空）
- review=true

## Pre-state
- prevGitVer: v1.0.0
- prevGitDate: 2026-01-01
- prevFlag: no

## Results

| Scenario | Expected | Actual queryStatus | gitVer | gitDate | flag | review | lockReleased | Verdict |
|---|---|---|---|---|---|---|---|---|
| not_found | not_found | not_found |  |  | no | True | False | PASS |
| rate_limited_429 | rate_limited | rate_limited | v1.0.0 | 2026-01-01 | no | True | False | PASS |
| server_error | server_error | server_error | v1.0.0 | 2026-01-01 | no | True | False | PASS |
| network_error | network_error | network_error | v1.0.0 | 2026-01-01 | no | True | False | PASS |
| invalid_response | invalid_response | invalid_response | v1.0.0 | 2026-01-01 | no | True | False | PASS |
| metadata_incomplete | metadata_incomplete | metadata_incomplete | v1.0.0 | 2026-01-01 | no | True | False | PASS |
| auth_error | auth_error | auth_error | v1.0.0 | 2026-01-01 | no | True | False | PASS |
| forbidden_403 | forbidden | forbidden | v1.0.0 | 2026-01-01 | no | True | False | PASS |
| http_error | http_error | http_error | v1.0.0 | 2026-01-01 | no | True | False | PASS |
## Summary
- PASS: 9 / 9
- FAIL: 0 / 9

## Notes
- not_found 特例：gitVer/gitDate 清空（SKILL L131），flag 保留
- 其他 8 种状态：gitVer/gitDate/flag 全部保留上轮状态
- review=true 对所有 9 种状态强制
