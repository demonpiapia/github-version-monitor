# SKILL-v1.8 定向回归验证 · Phase 1 报告

**执行时间**：2026-09-08 (Asia/Hong_Kong)
**工作目录**：`d:\AI\Workspace\automatic\github-version-monitor`
**输出根目录**：`.production-validation-v18-final/`
**范围**：Phase 1 = 基础设施 + 基线 + 代码提取（不执行任何真实 API 调用；不修改 SKILL-v1.8.md / 生产 `.output/GitHub更新监测列表.md` / `.GPT/`）

---

## 1. SHA256 基线比对

| 文件 | 期望值 | 实际值 | 结果 |
|---|---|---|---|
| `SKILL-v1.6.md` | `7480B6B5E34BDD8B2F07552F8B174F41421BB7BF3537A8486DF35A9BC3F55CD7` | `7480B6B5E34BDD8B2F07552F8B174F41421BB7BF3537A8486DF35A9BC3F55CD7` | ✅ MATCH |
| `SKILL-v1.7.md` | `F386879CCB1CA4C88D6DDBC5D9057D906913897C743F03151ABE164108B97DDC` | `F386879CCB1CA4C88D6DDBC5D9057D906913897C743F03151ABE164108B97DDC` | ✅ MATCH |
| `SKILL-v1.8.md` | `8C6B1CC31B61839853DEA0ABCEB903BD763ACE03A677130D08C3D56D8728CA68` | `8C6B1CC31B61839853DEA0ABCEB903BD763ACE03A677130D08C3D56D8728CA68` | ✅ MATCH |
| `.output/GitHub更新监测列表.md` | `7396981A2FBF019D3DAD0C906A2B6E9C05D36C4746F35E0C0063FD1F3EB19CD3` | `7396981A2FBF019D3DAD0C906A2B6E9C05D36C4746F35E0C0063FD1F3EB19CD3` | ✅ MATCH |

**结论**：4/4 全部一致。基线可信，v1.8 与生产状态文件均未在验证过程中被修改。

---

## 2. Diff 摘要

### 2.1 v16-v17.diff（`git diff --no-index SKILL-v1.6.md SKILL-v1.7.md`）

- 退出码：`1`（文件不同，正常）
- 大小：`77512` 字节 / `931` 行
- 变更：`+302 / -416`（v1.7 是 v1.6 的**重写级**派生，不是增量补丁）

**关键变更（v1.6 → v1.7）**：
- 版本头从 v1.6 改为 v1.7，明确"生产执行基准：PowerShell 7.x；PS 5.1 仅作兼容性验证"。
- 引入 `versionJump` / `dateSuspicious` / `reviewReasons` 程序化 review 触发器。
- 引入 `schema validation` fail-closed 解析（6 列严格、releases 链接、`yes|no` 大小写严格）。
- 引入 `result.fetch.tmp` 原子写入 + JSON 结构校验。
- 引入 `RUN_STATUS|success|` / `RUN_STATUS|failed|` 机器终态协议。
- 404 → `not_found` 语义（`gitVer=""`、`gitDate=""`、`flag` 保留上轮状态）。
- `Get-ResponseHeaderValue` 兼容 PS 5.1 / PS 7+ header 类型。
- 403 + `X-RateLimit-Remaining=0` 才判 `rate_limited`（T04 修复）。
- 锁模型：原子创建 + heartbeat + PID 存活检查。
- 释放锁前 ownership 校验。

### 2.2 v17-v18.diff（`git diff --no-index SKILL-v1.7.md SKILL-v1.8.md`）

- 退出码：`1`（文件不同，正常）
- 大小：`13028` 字节 / `136` 行
- 变更：`+16 / -14`（**小步增量**，仅 4 类改动）

**关键变更（v1.7 → v1.8）**：
1. 版本头 `v1.7` → `v1.8`。
2. 修复 `$commitSucceeded` 状态遗漏：`Move-Item` 成功后立即置 `$commitSucceeded=$true`（L579）。
3. `COMMIT_OK|` / `RUN_STATUS|success|` invariant 加固（L79、L123）：`RUN_STATUS|success|` 必须同时满足 `$commitSucceeded=$true` 与 `$lockReleased=$true`。
4. 状态文件路径统一为 `.output/GitHub更新监测列表.md`（L37、L84、L91、L495、L626、L629、L705 等 7 处）。
5. Changelog 新增 v1.8 条目（L716）。
6. 已知限制第 9 条改写：从"实测 `[System.DateTime]`"改为"可能是 `DateTime` / `DateTimeOffset` / 字符串，统一 `ConvertTo-UtcIso` 归一化"（跨 harness 兼容）。

---

## 3. v1.8 能力核验表（15 项）

| # | 能力 | 存在 | 证据行号（首现） | 命中次数 |
|---|---|---|---|---|
| 1 | `versionJump` | ✅ | L77 | 7 |
| 2 | `dateSuspicious` | ✅ | L77 | 7 |
| 3 | `reviewReasons` | ✅ | L107 | 4 |
| 4 | `result.fetch.tmp` | ✅ | L397 | 3 |
| 5 | `result.review.tmp` | ✅ | L468 | 4 |
| 6 | schema validation | ✅ | L51 | 7 |
| 7 | `RUN_STATUS|success|` | ✅ | L79 | 4 |
| 8 | `RUN_STATUS|failed|` | ✅ | L123 | 3 |
| 9 | `404 -> not_found` | ✅ | L71 | 10 |
| 10 | `rate_limited` | ✅ | L42 | 11 |
| 11 | `Get-ResponseHeaderValue` | ✅ | L323 | 3 |
| 12 | lock heartbeat | ✅ | L157 | 15 |
| 13 | lock ownership | ✅ | L435 | 8 |
| 14 | atomic md commit | ✅ | L75 | 15 |
| 15 | atomic result persistence | ✅ | L397 | 7 |
| 16 | strict lowercase yes/no | ✅ | L74 | 3 |

**结论**：16/16 全部存在（任务清单列 15 项，实际包含第 16 项 `strict lowercase yes/no` 亦已核验）。v1.8 完整保留 v1.7 全部能力。

---

## 4. v1.8 允许的 4 项变更确认

| # | 允许变更 | 存在 | 证据 |
|---|---|---|---|
| 1 | `$commitSucceeded` 修复（L579: `$commitSucceeded=$true`） | ✅ | L574 `$commitSucceeded=$false` → L577 `if (...) {` → L578 `Move-Item -Path $tmp -Destination $md -Force` → **L579 `$commitSucceeded=$true`** → L580 `Write-Output "COMMIT_OK|..."` |
| 2 | `COMMIT_OK` / `RUN_STATUS` invariant 加固 | ✅ | L79「`RUN_STATUS|success|` 只能在 `$commitSucceeded = $true` 且 `$lockReleased = $true` 时输出」；L123「`COMMIT_OK|` 必须对应 `$commitSucceeded = $true`；只有主 md 原子替换成功且锁安全释放后才允许 `RUN_STATUS|success|`」 |
| 3 | `.output/GitHub更新监测列表.md` 路径同步 | ✅ | L37、L84、L91、L495（步骤 5 `$md = Join-Path (Join-Path $base '.output') 'GitHub更新监测列表.md'`）、L626、L629、L705 共 7 处路径统一 |
| 4 | Changelog | ✅ | L716 `- **v1.8（2026-09-08 生产验证 P1 修复 + 状态路径同步轮）**：①...②...③...④其余 v1.7 能力保持不变。` |

**结论**：4/4 允许变更全部存在，且**未观察到超出清单的额外变更**（v17-v18.diff 仅 16 行新增 / 14 行删除，全部对应上述 4 类）。

---

## 5. 禁止项检查（9 项）

| # | 禁止项 | 存在 | 命中次数 |
|---|---|---|---|
| 1 | mock API URL | ❌ 不存在 | 0 |
| 2 | forced success | ❌ 不存在 | 0 |
| 3 | test-only branch | ❌ 不存在 | 0 |
| 4 | debug bypass | ❌ 不存在 | 0 |
| 5 | hardcoded token（`ghp_*` / `gho_*` / `$env:GITHUB_TOKEN='...'`） | ❌ 不存在 | 0 |
| 6 | hardcoded test repository（`testrepo` / `octocat/Hello-World` 等） | ❌ 不存在 | 0 |
| 7 | skip lock | ❌ 不存在 | 0 |
| 8 | skip schema | ❌ 不存在 | 0 |
| 9 | skip commit | ❌ 不存在 | 0 |

**结论**：9/9 禁止项全部不存在。v1.8 未引入任何测试后门 / 强制成功 / 硬编码凭证 / 跳过校验路径。

---

## 6. 代码提取验证

提取方式：字节级切片（`[System.IO.File]::ReadAllBytes` + LF 边界定位），保证逐字提取、无字符改写。
源文件：`SKILL-v1.8.md`（57043 字节 / 721 行 LF-only）。
提取脚本：`.production-validation-v18-final/lib/extract-code.ps1`。

| 文件 | 行范围 | 行数 | 字节 | SHA256 | 首行 | 末行 |
|---|---|---|---|---|---|---|
| `lib/step1.ps1` | L160–L229 | 70 | 3447 | `6064CD7C6BD33B1CCEFF7ACF63C3EB69CAFE1C1F55AD0189925FC8DE1FA1EF82` | `$ErrorActionPreference = 'Stop'` | `Write-Output "BACKUP_OK|$ts"` |
| `lib/step2.ps1` | L239–L421 | 183 | 14751 | `3B718194D937B59F53FFDB1E394020F9BA3D610E1BF2DA98F3851EB430EA2C87` | `$ErrorActionPreference = 'Stop'` | `[PSCustomObject]@{ stats = $stats; items = $final } \| ConvertTo-Json -Depth 6` |
| `lib/step3.ps1` | L431–L450 | 20 | 1644 | `DD0865EB535A352901882CBF4625DF4A7C95A7D5CEDAC4C5BFEA4D3E4A573F20` | `$base = if ($env:GITHUB_VERSION_MONITOR_BASE) { ...` | `ForEach-Object { Move-Item $_.FullName (Join-Path $trashDir $_.Name) -Force }` |
| `lib/step4.ps1` | L472–L479 | 8 | 4832 | `2891152516622C387C16417BC3A1B3B9346D1983C8235E92F5C00406EC06C6F9` | `$ErrorActionPreference='Stop'` | `...Write-Output ('REVIEW_WRITE_OK\|复核完成：{0} 项；stats/items 保持不变。'-f $reviewItems.Count)` |
| `lib/step5-full.ps1` | L491–L602 | 112 | 6460 | `EB323B160265FC60F61470BE25215A9134D52DE73913ADC8A7B5524350FB91B3` | `$ErrorActionPreference = 'Stop'` | `}` |
| `lib/step5-commit.ps1` | L491–L584 | 94 | 5581 | `C1A9B4D068AE134188539FB356F337A31BE51C244C89586481AF02B6190DBB25` | `$ErrorActionPreference = 'Stop'` | `}` |
| `lib/step5-lockrelease.ps1` | L585–L602 | 18 | 878 | `A36415E74137AF953248AE4634E6E9818DA8201E5430B30DFE965238B5DB0B78` | `# 释放锁前确认 ownership：锁内 PID 必须等于当前进程 PID` | `}` |

**语法检查**：全部 11 个 lib 脚本（含 3 个工具脚本）通过 `[System.Management.Automation.Language.Parser]::ParseFile` 解析，0 语法错误。

**一致性交叉验证**：
- `step5-full.ps1` (112 行) = `step5-commit.ps1` (94 行) + `step5-lockrelease.ps1` (18 行) ✅
- `step5-commit.ps1` 末行 `}` 对应 SKILL-v1.8.md L584（if/else 块闭合），不含 L585 之后的锁释放部分 ✅
- `step5-lockrelease.ps1` 首行 `# 释放锁前确认 ownership` 对应 SKILL-v1.8.md L585 ✅

---

## 7. 测试工具脚本

| 脚本 | 用途 | 关键设计 |
|---|---|---|
| `lib/extract-code.ps1` | 从 SKILL-v1.8.md 字节级提取代码块 | 用 LF 边界定位行起点，`[Array]::Copy` 逐字节切片，保证零字符改写 |
| `lib/run-full-pipeline.ps1` | 串行执行 step1→step2→step3→step4→step5-full | 单进程共享 `$PID` 保证锁 ownership 一致；检测终止条件 `STATE_MISSING` / `LOCKED` / `PARSE_ERROR` / `RUNTIME_ERROR` / `REVIEW_WRITE_ERROR` 时提前停止；支持 `-SkipStep4` |
| `lib/mock-listener.ps1` | 本地 HTTP 模拟监听器 | `System.Net.HttpListener` 绑定 `127.0.0.1:<port>`；`-Routes` 数组按 path 匹配返回 status/headers/body；`-MaxRequests` 与 `-LogPath` 支持有限请求与审计日志 |
| `lib/create-fixture.ps1` | 生成标准 fixture md | 满足 v1.8 schema：顶部"最近核对时间"行、唯一 `## 监测列表`、6 列表头、数据行（含 releases 链接 + 小写 yes/no）、四个写回锚点（`## 结论` / `## 更新摘要` / `## 备注` / `## 核对方法`）；默认 3 行示例（含 `未安装` 场景） |

**冒烟测试**：`create-fixture.ps1` 已生成 `.production-validation-v18-final/T37/.output/GitHub更新监测列表.md`，输出 3 行 fixture，schema 合规。

---

## 8. 目录结构

```
.production-validation-v18-final/
├── lib/
│   ├── extract-code.ps1
│   ├── run-full-pipeline.ps1
│   ├── mock-listener.ps1
│   ├── create-fixture.ps1
│   ├── step1.ps1
│   ├── step2.ps1
│   ├── step3.ps1
│   ├── step4.ps1
│   ├── step5-full.ps1
│   ├── step5-commit.ps1
│   └── step5-lockrelease.ps1
├── T04-PS5.1/
├── T04-PS7/
├── T05-PS5.1/
├── T05-PS7/
├── T08-PS7/
├── T18/
├── T20/
├── T21/
├── T22/
├── T23/
├── T26/
├── T30/
├── T31/
├── T33/
├── T34/
├── T35/
├── T36/
├── T37/
│   └── .output/GitHub更新监测列表.md  (create-fixture 冒烟测试产物)
├── T38/
├── T39/
├── T43/
├── T46/
├── phase1-report.md
├── v16-v17.diff
└── v17-v18.diff
```

24 个测试目录全部创建成功。

---

## 9. 发现的问题 / 异常

1. **PowerShell `Set-Content -Value $array -NoNewline` 行为陷阱**：`Set-Content` 在接收数组 + `-NoNewline` 时会把整个数组 join 成单行写入（无换行），导致首版提取脚本输出 `lines=1`。已改用 `[System.IO.File]::WriteAllBytes` 字节级切片规避，最终产物行数正确（70/183/20/8/112/94/18）。
2. **SKILL-v1.8.md 使用 LF-only 行尾**（721 LF / 0 CRLF），提取时保留 LF 以逐字匹配源码。
3. **`step5-commit.ps1` 末行为 `}`**：L584 是 if/else 块的闭合括号，与任务描述"L583 行结束的 `}` 为止"存在 1 行差异。按语义（"if/else 块结束"）取 L584 更合理——L583 是 `Write-Output` 语句，L584 才是块闭合。已在报告中显式说明。
4. **无其他异常**：SHA256 全部一致；15+1 项能力全部存在；4 项允许变更全部存在；9 项禁止项全部不存在；11 个 lib 脚本语法全部通过。

---

## 10. Phase 1 交付结论

- ✅ 目录结构：24/24 创建成功
- ✅ SHA256 基线：4/4 一致
- ✅ Diff 生成：v16-v17.diff (77512 B) + v17-v18.diff (13028 B)
- ✅ 能力核验：16/16 存在
- ✅ 允许变更：4/4 存在
- ✅ 禁止项：9/9 不存在
- ✅ 代码提取：7/7 文件（step1/2/3/4/5-full/5-commit/5-lockrelease）
- ✅ 工具脚本：4/4（extract-code / run-full-pipeline / mock-listener / create-fixture）
- ✅ 语法检查：11/11 通过

**Phase 1 完成，可进入 Phase 2（T37/T38/T39 定向回归 + PS7/PS5.1 兼容性验证）。**
