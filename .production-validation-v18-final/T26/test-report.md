# T26-v18 测试报告

**测试 ID**：T26-v18
**执行时间**：2026-09-08 (Asia/Hong_Kong)
**PowerShell**：7.6.4
**测试方法**：方法 C（解析器单元测试，逐字提取解析器代码）
**目标**：验证 flag 列严格小写匹配（`yes` / `no`），大小写变体（`YES` / `Yes` / `yEs` / `NO` / `No`）触发 PARSE_ERROR

## 结论

**PASS** ✅（7/7 fixture 全部通过）

## 详细结果

| # | Fixture 文件 | flag 值 | 期望 | parseErrors | repos | verdict |
|---|---|---|---|---|---|---|
| 1 | `fixture_valid_yes.md` | `yes` | PASS | 0 | 1 | PASS |
| 2 | `fixture_valid_no.md` | `no` | PASS | 0 | 1 | PASS |
| 3 | `fixture_invalid_flag_UPPER.md` | `YES` | PARSE_ERROR | 1 | 0 | PASS |
| 4 | `fixture_invalid_flag_CAP.md` | `Yes` | PARSE_ERROR | 1 | 0 | PASS |
| 5 | `fixture_invalid_flag_MIXED.md` | `yEs` | PARSE_ERROR | 1 | 0 | PASS |
| 6 | `fixture_invalid_flag_UPPER2.md` | `NO` | PARSE_ERROR | 1 | 0 | PASS |
| 7 | `fixture_invalid_flag_CAP2.md` | `No` | PARSE_ERROR | 1 | 0 | PASS |

## 错误消息验证

无效 fixture 的 `parseErrors` 均包含 `第 6 列 flag 非法：` 前缀，例如：
```
第 6 列 flag 非法：| 1 | [Test](https://github.com/test/repo/releases) | v1.0.0 | 2026-08-01 | v1.0.0 | YES |
```

## 证据

- `stdout.txt`：完整测试输出（7 条 FIXTURE 行 + SUMMARY）
- `stderr.txt`：空
- `test-t26.ps1`：测试脚本（逐字提取解析器代码）
- 7 个 fixture 文件（见上表）

## 函数提取来源

- 解析器代码：`lib/step2.ps1` L78-81（逐字，4 行）
  - L78：`$sections` / `$monitorSections` / `$parseErrors` / `$repos` 初始化
  - L79：`## 监测列表` 节数量校验
  - L80：表头 / 数据行 / 写回锚点 / releases 链接 / flag 大小写校验
  - L81：PARSE_ERROR 输出 + 释放锁

## 关键验证点

1. **有效 fixture**（`yes` / `no`）：解析成功，`parseErrors.Count=0`，`repos.Count=1`，`prevFlag` 正确读取
2. **无效 fixture**（`YES` / `Yes` / `yEs` / `NO` / `No`）：解析失败，`parseErrors.Count=1`，`repos.Count=0`，错误消息包含 `第 6 列 flag 非法：`
3. 大小写敏感性验证：`-cnotmatch '^(yes|no)$'` 使用 `-c` 前缀强制大小写敏感匹配
4. fail-closed 语义：任何 flag 非法 → 整轮终止，不写回主 md

## 备注

- **Windows 文件系统大小写不敏感**：原计划用 `fixture_invalid_YES.md` / `fixture_invalid_Yes.md` / `fixture_invalid_yEs.md` 区分大小写变体，但 NTFS 默认大小写不敏感，三个文件会冲突。改用后缀区分（`_UPPER` / `_CAP` / `_MIXED` / `_UPPER2` / `_CAP2`），flag 值仍为原始大小写变体。
- fixture 格式严格遵循 v1.8 schema：顶部"最近核对时间"行、唯一 `## 监测列表`、6 列表头、数据行（含 releases 链接 + flag）、四个写回锚点（`## 结论` / `## 更新摘要` / `## 备注` / `## 核对方法`）
- 仅修改 flag 列的值，其他字段保持一致，确保测试变量单一
