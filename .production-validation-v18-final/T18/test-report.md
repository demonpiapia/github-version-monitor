# T18-v18 测试报告

**测试 ID**：T18-v18
**执行时间**：2026-09-08 (Asia/Hong_Kong)
**PowerShell**：7.6.4
**测试方法**：方法 B（完整状态机合流测试，构造 `$out` 数组输入）
**目标**：验证 `queryStatus != ok` 时保留上轮 `gitVer/gitDate/flag`；`not_found` 为唯一数据字段特例（清空 `gitVer/gitDate`，保留 `flag`）

## 结论

**PASS** ✅（7/7 场景全部通过）

## 详细结果

| # | 场景 | queryStatus | gitVer | gitDate | flag | prevFlag | review | reasons | 期望 | 结果 |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | auth_error | `auth_error` | `v2.0.0` | `2026-08-01` | `yes` | `yes` | true | `api_failure` | 保留 | PASS |
| 2 | forbidden | `forbidden` | `v2.0.0` | `2026-08-01` | `yes` | `yes` | true | `api_failure` | 保留 | PASS |
| 3 | rate_limited | `rate_limited` | `v2.0.0` | `2026-08-01` | `yes` | `yes` | true | `api_failure` | 保留 | PASS |
| 4 | server_error | `server_error` | `v2.0.0` | `2026-08-01` | `yes` | `yes` | true | `api_failure` | 保留 | PASS |
| 5 | network_error | `network_error` | `v2.0.0` | `2026-08-01` | `yes` | `yes` | true | `api_failure` | 保留 | PASS |
| 6 | http_error | `http_error` | `v2.0.0` | `2026-08-01` | `yes` | `yes` | true | `api_failure` | 保留 | PASS |
| 7 | not_found | `not_found` | (empty) | (empty) | `yes` | `yes` | true | `not_found` | 清空 gitVer/gitDate，保留 flag | PASS |

## 证据

- `stdout.txt`：完整测试输出（7 条 SCENARIO 行 + SUMMARY）
- `stderr.txt`：空
- `test-t18.ps1`：测试脚本（逐字提取 `ConvertTo-NormVer` / `Compare-Ver` / 状态机合流 foreach 循环）

## 函数提取来源

- `ConvertTo-NormVer`：`lib/step2.ps1` L36-50（逐字）
- `Compare-Ver`：`lib/step2.ps1` L51-67（逐字）
- 状态机合流逻辑：`lib/step2.ps1` L141-142（逐字，整段一行）

## 关键验证点

1. **场景 1-6**（`auth_error` / `forbidden` / `rate_limited` / `server_error` / `network_error` / `http_error`）：`gitVer` / `gitDate` / `flag` 全部保留上轮值，`review=true`，`reviewReasons=['api_failure']`
2. **场景 7**（`not_found`）：`gitVer=''` / `gitDate=''` / `flag=prevFlag`（保留），`review=true`，`reviewReasons=['not_found']`
3. 所有 7 种场景均触发 `review=true`（fail-closed 语义）
4. 状态机合流逻辑正确区分 `not_found`（唯一数据字段特例）与其他错误状态（默认保留）

## 备注

- 测试输入构造：`prevGitVer='v2.0.0'` / `prevGitDate='2026-08-01'` / `localVer='v1.0.0'` / `prevFlag='yes'`
- `localVer='v1.0.0'` 与 `latest=''` 的比较在错误状态下不会执行（因为 `queryStatus != 'ok'`），所以 `flag` 保持 `prevFlag`
- `not_found` 场景下 `flag` 也保持 `prevFlag`（因为 `not_found` 分支不修改 `flag`）
