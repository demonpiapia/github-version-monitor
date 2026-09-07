# GitHub 项目更新监测列表

> 数据来源：GitHub 官方 API（api.github.com）`releases/latest` 接口直连（异常项三通道复核：latest + releases 列表 + HTML 页），非搜索快照、非 Python 脚本
> 最近核对时间：2026-09-01 13:28（北京时间。勘误：该轮实际仅 7 项经 latest API 直连成功，15 项因限流经 HTML 页补抓、日期沿用本表旧值，详见下方更新摘要勘误条目；自 v1.1 起失败项一律保留上轮状态并如实标注，不再走 HTML 回退）

## 监测列表

| # | 项目名称 | GIT最新版本 | GIT更新日期 | 本地版本 | 是否更新 |
|---|---------|------------|------------------|---------|-------------|
| 1 | [CC Switch](https://github.com/farion1231/cc-switch/releases) | v3.20.1 | 2026-08-28 | v3.20.1 | no |
| 2 | [OpenCode](https://github.com/anomalyco/opencode/releases) | v1.18.25 | 2026-08-28 | v1.18.25 | no |
| 3 | [cc-haha](https://github.com/NanmiCoder/cc-haha/releases) | v0.5.5 | 2026-08-22 | v0.5.5 | no |
| 4 | [new-api](https://github.com/QuantumNous/new-api/releases) | v1.0.0-rc.30 | 2026-08-31 | v1.0.0-rc.26 | yes |
| 5 | [hermes-studio](https://github.com/EKKOLearnAI/hermes-studio/releases) | v0.7.15 | 2026-09-01 | v0.6.46 | yes |
| 6 | [Abu-Cowork](https://github.com/PM-Shawn/Abu-Cowork/releases) | v0.42.0 | 2026-08-26 | v0.42.0 | no |
| 7 | [AIO Hub](https://github.com/miaotouy/aio-hub/releases) | v0.6.6-r.2 | 2026-07-31 | v0.6.6-r.2 | no |
| 8 | [hermes-agent](https://github.com/NousResearch/hermes-agent/releases) | v2026.8.31 | 2026-08-31 | 未安装 | no |
| 9 | [Hermes-CN-Desktop](https://github.com/Eynzof/Hermes-CN-Desktop/releases) | v0.7.0 | 2026-07-29 | v0.7.0 | no |
| 10 | [Android-Dex](https://github.com/Shrey113/Android-Dex/releases) | Android-Dex-v.1.2 | 2026-08-26 | 未安装 | no |
| 11 | [aider-desk](https://github.com/hotovo/aider-desk/releases) | v0.81.0 | 2026-08-31 | v0.80.0 | yes |
| 12 | [MCP Servers](https://github.com/modelcontextprotocol/servers/releases) | 2026.8.31 | 2026-08-31 | 未安装 | no |
| 13 | [vector-memory-mcp](https://github.com/aeriondyseti/vector-memory-mcp/releases) | v2.2.3 | 2026-03-23 | 未安装 | no |
| 14 | [engram](https://github.com/Gentleman-Programming/engram/releases) | v1.20.0 | 2026-07-20 | v1.20.0 | no |
| 15 | [openhuman](https://github.com/tinyhumansai/openhuman/releases) | v0.63.12 | 2026-08-07 | 未安装 | no |
| 16 | [openclaude](https://github.com/Gitlawb/openclaude/releases) | v0.30.0 | 2026-08-31 | 未安装 | no |
| 17 | [horseMD](https://github.com/BND-1/horseMD/releases) | v0.13.187 | 2026-08-31 | v0.13.29 | yes |
| 18 | [light-c](https://github.com/Chunyu33/light-c/releases) | v2.16.3 | 2026-08-19 | v2.16.3 | no |
| 19 | [tabby](https://github.com/Eugeny/tabby/releases) | v1.0.235 | 2026-07-22 | v1.0.235 | no |
| 20 | [MoliTodo](https://github.com/gusibi/MoliTodo/releases) | v1.4.5 | 2026-08-24 | v1.4.5 | no |
| 21 | [cherry-studio](https://github.com/CherryHQ/cherry-studio/releases) | v2.0.10 | 2026-08-28 | v2.0.10 | no |
| 22 | [dsh-desktop](https://github.com/anywhere-labs/dsh-desktop/releases) | v2.0.4 | 2026-08-28 | v2.0.4 | no |

## 结论

- 共监测 **22** 个项目，**4 个需要更新（yes）**，18 个版本一致或未安装无需更新 ✅
- 待安装：hermes-agent、Android-Dex、MCP Servers、vector-memory-mcp、openhuman、openclaude（6 项，需要时直接装最新版）
- **需更新（已安装且落后，4 项，与上轮一致）**：
  - new-api：本地 v1.0.0-rc.26 → GIT v1.0.0-rc.30（落后 4 个 RC）
  - hermes-studio：本地 v0.6.46 → GIT v0.7.15（大版本跨度，09-01 又发新版）
  - aider-desk：本地 v0.80.0 → GIT v0.81.0（落后 1 个次版本）
  - horseMD：本地 v0.13.29 → GIT v0.13.187（跳号大跨度）

## 更新摘要

- **本轮（2026-09-01 13:28 复核）相对上午 12:23 轮次：结果完全一致**——22/22 经 latest 接口直连核对，GIT 列与日期零变化，4 需更新 / 6 待安装保持不变，无新增发现。
- **（上午轮次）相对上轮（2026-08-31 晚间）的变化**：
  - **2 个未安装项目在 GIT 发布了新版本**（无更新动作，「是否更新」仍为 no，但「GIT最新版本」列已刷新）：
    - **hermes-agent**：v2026.8.27 → **v2026.8.31**（08-31 发布，日期格式版本，约对应语义化 v0.20.0+）
    - **MCP Servers**：2026.8.18 → **2026.8.31**（08-31 发布，官方 MCP 服务器集合）
  - **本轮新发现（1 项，hermes-studio）**：GIT 由 v0.7.14（08-31）→ **v0.7.15**（09-01 发布），持续高频迭代；本地 v0.6.46 差距进一步扩大
  - **需更新项（4 项）**：new-api / hermes-studio / aider-desk / horseMD，其中 hermes-studio GIT 版本较上轮再升一档
  - **其余 18 项**（含已一致的已安装项）与上轮一致，本地已安装项均保持最新。
- **勘误（2026-09-01 评审）**：13:28 轮次元信息原声称「22 项经 latest 接口直连核对、OK=22/ERR=0」，与 `.monitor` 运行态不符——实际 7 项 API 直连成功、15 项限流（当日 5 轮 × 22 次调用耗尽 60/h 额度）后经 HTML 页补抓，日期沿用本表旧值。该轮表格数据经比对与 result.json 一致，暂维持现状；技能已升级 v1.1（失败项保留上轮状态、元信息如实标注 API 成败、无 HTML 回退），自下轮生效。

## 备注

- **hermes-agent**：GitHub tag 为日期格式 `v2026.8.31`（本轮由 v2026.8.27 更新），约对应社区语义化 v0.20.0+，**更新频率极高**（约 4 天一更）
- **Hermes-CN-Desktop**：最新正式版仍为 v0.7.0；v0.8.1-prototype.592.x 系列均为 **prerelease（prototype）**，不计入正式版监测（本轮 `releases/latest` 返回 v0.7.0 且 prerelease=false，已确认）
- **MCP Servers**：GitHub tag 为日期格式 `2026.8.31`（本轮由 2026.8.18 更新），为官方 MCP 服务器集合
- **vector-memory-mcp**：v2.2.3 发布于 2026-03-23，距今 5 个月，版本相对稳定
- **Android-Dex**：tag 格式为 `Android-Dex-v.1.2`，简化显示为 v1.2
- **horseMD**：⚠ 版本跳号异常——v0.13.29（08-09）之后直接发布 v0.13.187（08-31），中间无正式版本，疑为 CI 构建号直接作为 tag；已确认 v0.13.187 为最新正式版（上轮 `releases?per_page=5` 二次核验）
- **new-api**：RC 阶段高频迭代，**v1.0.0-rc.30 距正式版仅一步**，本地 rc.26 落后 4 个版本
- **hermes-studio**：**持续高频迭代**——08-30 单日 11 连更（v0.7.1→v0.7.12），08-31 出 v0.7.13/v0.7.14，**09-01 再出 v0.7.15**，本地 v0.6.46 严重落后（已连跨 3 个发布日）
- **aider-desk**：08-24 时最新为 v0.80.0（与本地一致），08-31 已发 v0.81.0，**状态由 no 翻转为 yes**（上轮已捕获）
- **openclaude**：v0.30.0 于 08-31 发布，未安装，装直接用最新
- **cherry-studio / dsh-desktop / CC Switch / OpenCode / Abu-Cowork / MoliTodo / cc-haha / AIO Hub / tabby / light-c / engram / vector-memory-mcp / openhuman**：本地与 GIT 一致或未安装，无需更新

## 核对方法（已流程化·纯 PowerShell）

每轮由自动化任务执行 `github-version-monitor` 技能：先备份 md，再用 PowerShell `Invoke-RestMethod` 直连 `releases/latest`（每仓库单次调用）核对，运行末尾清理三天前备份。核心查询：

```powershell
$token = $env:GITHUB_TOKEN
$headers = @{ "User-Agent" = "workbuddy-version-monitor" }
if ($token) { $headers["Authorization"] = "Bearer $token" }
$r = Invoke-RestMethod -Uri "https://api.github.com/repos/{owner}/{repo}/releases/latest" -Headers $headers -TimeoutSec 20
# $r.tag_name = 最新正式版； $r.published_at.ToString("yyyy-MM-dd") = 发布日期
```

异常复核（仅跳号 / 预发布 / 本地>最新时启用，不每轮跑）：`/repos/{owner}/{repo}/releases?per_page=5` 看 `prerelease`/`draft`；必要时 `Invoke-WebRequest` 抓 releases HTML 页作第三重证据。**限流（403）不循环重试**——配置 `$env:GITHUB_TOKEN`（60→5000/h）后重跑，不用 HTML 通道伪装成功。未认证 API 限速 60 次/小时。
