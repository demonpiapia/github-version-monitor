# T05-PS5.1 测试报告

**测试 ID**：T05-PS5.1
**执行时间**：2026-09-08 (Asia/Hong_Kong)
**PowerShell**：5.1.22621.963（`C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe`）
**测试方法**：方法 A（状态机单元测试 + mock-listener.ps1 via Start-Job）
**目标**：403 + `X-RateLimit-Remaining=50` → `queryStatus=forbidden`（与 T04 形成对照，PS5.1 兼容性验证）

## 结论

**PASS** ✅

## 详细结果

| 字段 | 值 |
|---|---|
| queryStatus | `forbidden` |
| rateRemaining | `50` |
| latest | (empty) |
| error | `远程服务器返回错误: (403) 已禁止。` |
| HTTP status | 403 |
| X-RateLimit-Remaining header sent | `50` |
| Response.Headers 类型 | `System.Net.WebHeaderCollection` |
| request count (latest) | 1 |
| HTML requests | 0 |
| Step4 API requests | 0 |
| retry count | 0 |

## 证据

- `stdout.txt`：完整测试输出
- `stderr.txt`：空
- `listener.log`：mock listener 请求日志（1 条 GET 请求）
- `test-t05.ps1`：测试脚本（逐字提取 `Get-ResponseHeaderValue` / `ConvertTo-UtcIso` / 状态机 try/catch，PS5.1 多行语法）

## 函数提取来源

- `Get-ResponseHeaderValue`：`lib/step2.ps1` L85-91（逐字，展开为多行以适配 PS5.1 解析）
- `ConvertTo-UtcIso`：`lib/step2.ps1` L69-75（逐字）
- 状态机 try/catch：`lib/step2.ps1` L99-139（foreach 循环体，URL 从 `https://api.github.com` 改为 `http://localhost:18346`）

## PS5.1 兼容性关键验证点

1. **403 + `X-RateLimit-Remaining=50`（>0）被正确分类为 `forbidden`**（与 PS7 结果一致，与 T04 形成对照）
2. **`Get-ResponseHeaderValue` 在 PS5.1 下走 `WebHeaderCollection` 分支**：`Response.Headers.GetType().FullName` = `System.Net.WebHeaderCollection`，函数第一个 try 分支被命中并正确读取 `X-RateLimit-Remaining=50`
3. **`rl -eq '0'` 分支判断正确**：`50 ≠ 0` → 走 `else { 'forbidden' }`
4. **`mock-listener.ps1` 在 PS5.1 下正常**：`$resp.Headers.Add($k, $v)` 对 WebHeaderCollection 有效
5. **无重试、无 HTML 回退、无 Step4 API 调用**
6. **`Start-Job` 在 PS5.1 下可用**

## 与 T05-PS7 对照

| 字段 | T05-PS7 | T05-PS5.1 |
|---|---|---|
| queryStatus | `forbidden` | `forbidden` |
| rateRemaining | `50` | `50` |
| Header 类型 | `System.Net.Http.Headers.HttpResponseHeaders` | `System.Net.WebHeaderCollection` |
| 命中分支 | `TryGetValues` | `WebHeaderCollection.Get` |
| HTTP status | 403 | 403 |

结果一致，PS5.1 兼容性通过。
