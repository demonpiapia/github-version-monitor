# T04-PS7 测试报告

**测试 ID**：T04-PS7
**执行时间**：2026-09-08 (Asia/Hong_Kong)
**PowerShell**：7.6.4
**测试方法**：方法 A（状态机单元测试 + mock-listener.ps1）
**目标**：403 + `X-RateLimit-Remaining=0` → `queryStatus=rate_limited`（无重试、无 HTML 回退、无 Step4 API）

## 结论

**PASS** ✅

## 详细结果

| 字段 | 值 |
|---|---|
| queryStatus | `rate_limited` |
| rateRemaining | `0` |
| latest | (empty) |
| error | `Response status code does not indicate success: 403 (Forbidden).` |
| HTTP status | 403 |
| X-RateLimit-Remaining header sent | `0` |
| request count (latest) | 1 |
| HTML requests | 0 |
| Step4 API requests | 0 |
| retry count | 0 |

## 证据

- `stdout.txt`：完整测试输出
- `stderr.txt`：空
- `listener.log`：mock listener 请求日志（1 条 GET 请求）
- `test-t04.ps1`：测试脚本（逐字提取 `Get-ResponseHeaderValue` / `ConvertTo-UtcIso` / 状态机 try/catch）

## 函数提取来源

- `Get-ResponseHeaderValue`：`lib/step2.ps1` L85-91（逐字）
- `ConvertTo-UtcIso`：`lib/step2.ps1` L69-75（逐字）
- 状态机 try/catch：`lib/step2.ps1` L99-139（foreach 循环体，URL 从 `https://api.github.com` 改为 `http://localhost:18345`）

## 关键验证点

1. 403 + `X-RateLimit-Remaining=0` 被正确分类为 `rate_limited`（而非 `forbidden`）
2. `Get-ResponseHeaderValue` 在 PS 7.6.4 下正确读取 response header（`$Headers` 类型为 `System.Net.Http.Headers.HttpResponseHeaders`，走 `TryGetValues` 分支）
3. 无重试（请求次数 = 1）
4. 无 HTML 回退（listener 日志中无 `github.com` / `.html` 路径）
5. 无 Step4 API 调用（状态机 catch 块直接分类，不触发下游 review API）
