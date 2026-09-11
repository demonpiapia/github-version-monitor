# apps-Release-Monitor-Actions — 框架设计 v0.1

> GitHub Release Monitor — Actions 框架版
> 来源：GPT 设计稿（`D:\AI\addon.txt` L551–1363），Owner 要求「先抄一个框架版设计思路，保存参考」。
> 定位：**非生产实现**，是「够抄、够简单、保留未来扩展空间」的设计稿。
> 核心目的：固定职责边界 —— **GitHub Actions 只采集事实，Local Agent 负责理解 Release Note**。

---

## 元数据

| 项 | 值 |
|---|---|
| 项目名 | `apps-Release-Monitor-Actions` |
| 版本 | v0.1（设计稿） |
| 驱动 | GitHub Actions（schedule + workflow_dispatch） |
| 第一版 provider | 仅 GitHub |
| 事实源 | 单一：`output/output.md` |
| 命名说明 | `apps` = 桌面/工具类应用（非通用依赖）；`Release-Monitor` = 发现上游发布信息；`Actions` = GitHub Actions 驱动的远端采集模块。**刻意不加 `GitHub-` 前缀** —— GitHub 只是第一个 provider，不应成为架构边界 |

---

## TOC

1. [目标](#1-目标)
2. [核心职责边界](#2-核心职责边界)
3. [Checklist](#3-checklist)
4. [Workflow](#4-workflow)
5. [Release 获取](#5-release-获取)
6. [「正式版本」的基本定义](#6-正式版本的基本定义)
7. [output.md](#7-outputmd)
8. [Status](#8-status)
9. [Snapshot 的基本语义](#9-snapshot-的基本语义)
10. [Git 提交策略](#10-git-提交策略)
11. [本地 Agent 消费方式](#11-本地-agent-消费方式)
12. [Local Agent 的分析输入](#12-local-agent-的分析输入)
13. [Release Note 分析重点](#13-release-note-分析重点)
14. [未来扩展：多 Provider](#14-未来扩展多-provider)
15. [推荐的未来数据模型](#15-推荐的未来数据模型)
16. [第一版不要做的事情](#16-第一版不要做的事情)
17. [最终目标](#17-最终目标)
18. [实施原则](#18-实施原则)
19. [仓库结构](#19-仓库结构)

---

## 1. 目标

建立一个极简的 GitHub Actions 定时监测器：

```text
Checklist
    ↓
GitHub Actions
    ↓
GitHub Release API
    ↓
采集版本 + Release Note + 元数据
    ↓
生成 output.md
    ↓
commit / push
```

本模块**只负责远端事实采集**。

不负责：

```text
本地软件版本判断
是否应该升级
Release Note 风险分析
下载安装
升级验证
```

这些交给 Local Agent / Future Updater。

---

## 2. 核心职责边界

### Remote GitHub Actions

负责：

```text
读取 checklist
获取最新正式 Release
记录版本
记录发布时间
记录 Release URL
记录 Release Name
记录 Release Body
记录 draft / prerelease
记录查询状态
生成统一 snapshot
提交 snapshot
```

### Local Agent

负责：

```text
读取 output.md
读取本机实际软件版本
识别新版本
阅读 Release Note
判断：
  - 是否值得升级
  - 是否存在生产环境警告
  - 是否存在 breaking changes
  - 是否存在 known issues
  - 是否属于 beta / preview / experimental
生成日报
```

### Future Updater

负责：

```text
接受已批准的升级候选
    ↓
下载
    ↓
安装
    ↓
验证
    ↓
回滚 / 报错
```

---

## 3. Checklist

建议单独配置：

```text
config/checklist.yml
```

示例：

```yaml
projects:
  - id: vscode
    name: Visual Studio Code
    repo: microsoft/vscode

  - id: git
    name: Git
    repo: git/git

  - id: 7zip
    name: 7-Zip
    repo: ip7z/7zip
```

要求：

```text
id   必须唯一
repo 必须唯一
name 用于展示
repo 用于 API 查询
```

未来可以增加：

```yaml
  - id: xxx
    name: XXX
    repo: owner/repo
    enabled: true
```

但**不要在第一版加入复杂配置**。

---

## 4. Workflow

文件：

```text
.github/workflows/release-monitor.yml
```

推荐结构：

```yaml
name: Release Monitor

on:
  schedule:
    - cron: "0 2 * * *"

  workflow_dispatch:

permissions:
  contents: write

jobs:
  monitor:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Collect Releases
        ...

      - name: Generate output.md
        ...

      - name: Commit changes
        ...
```

核心要求：

```text
schedule
+
workflow_dispatch
+
contents: write
```

其中：

- `schedule`：每日自动运行
- `workflow_dispatch`：允许人工立即运行
- `contents: write`：只有确实需要自动提交时才开启

---

## 5. Release 获取

第一版优先使用：

```text
GET /repos/{owner}/{repo}/releases/latest
```

或者使用成熟 GitHub Action：

```text
step-security/github-action-get-latest-release
```

> 该 Action 输出 `release` / `id` / `description`（= Release body），支持 `excludes: prerelease, draft` 与 `GITHUB_TOKEN`。
> 注意：其清单文件名为 **`action.yaml`**（非 `action.yml`）；且含 subscription check，私有仓库需确认是否受限。

目标字段至少包括：

```text
tag_name
name
published_at
html_url
body
draft
prerelease
```

建议最终转换为：

```yaml
repo:
version:
name:
published_at:
url:
draft:
prerelease:
body:
status:
```

---

## 6. 「正式版本」的基本定义

第一版建议：

```text
draft = false
prerelease = false
```

才进入：

```text
latest stable release
```

**不要自行按照 tag 名称重新排序。**

不要把：

```text
beta
alpha
rc
nightly
preview
canary
```

自动当成正式版本。

---

## 7. output.md

建议第一阶段只生成一个文件：

```text
output/output.md
```

示例：

```markdown
# GitHub Release Snapshot

Generated: 2026-09-11T02:00:00Z

---

## Visual Studio Code

- Repository: `microsoft/vscode`
- Version: `1.105.0`
- Release Name: `August 2026 (version 1.105)`
- Published: `2026-09-10T12:30:00Z`
- Status: `ok`
- Prerelease: `false`
- Draft: `false`
- URL: https://github.com/microsoft/vscode/releases/tag/1.105.0

### Release Notes

<GitHub Release Body 原文>

---

## Git

- Repository: `git/git`
- Version: `2.51.0`
- Release Name: `Git 2.51.0`
- Published: `2026-09-09T...`
- Status: `ok`
- Prerelease: `false`
- Draft: `false`
- URL: ...

### Release Notes

<GitHub Release Body 原文>
```

原则：

> `output.md` 中的 Release Note 尽量保持 GitHub 原文，**不在远端进行 AI 摘要**。

可选的分离存储形态（若 release note 过长）：

```text
output/
├─ output.md
└─ releases/
   ├─ vscode.md
   ├─ git.md
   └─ 7zip.md
```

---

## 8. Status

每个项目必须有：

```text
ok
not_found
rate_limited
forbidden
server_error
network_error
invalid_response
metadata_incomplete
```

不要求第一版实现特别复杂的错误恢复。

重要的是：

```text
查询失败
    ↓
明确记录 status
    ↓
不要伪造 version
```

例如：

```yaml
repo: owner/repo
version: ""
status: rate_limited
```

而不是：

```yaml
version: old-version
status: ok
```

---

## 9. Snapshot 的基本语义

`output.md` 是：

```text
当前远端状态快照
```

不是：

```text
升级建议
```

因此不要在这里写：

```text
推荐升级
不推荐升级
存在风险
建议等待
```

这些判断由 Local Agent 完成。

---

## 10. Git 提交策略

每次运行：

```text
生成 output.md
    ↓
git diff
```

如果：

```text
无变化
```

则：

```text
不提交
```

如果：

```text
有变化
```

则：

```text
git add output.md
git commit
git push
```

建议 commit message：

```text
chore: update release snapshot
```

**不要让 Action 每天生成无变化 commit。**

---

## 11. 本地 Agent 消费方式

本地 Agent 每天只需要获取：

```text
output.md
```

获取方式可以是：

```text
GitHub raw URL
```

或者：

```text
git pull
```

**优先考虑直接获取单文件**，因为本地 Agent 实际不需要整个仓库。

---

## 12. Local Agent 的分析输入

建议：

```text
Remote Snapshot
+
Local Installed Software
```

其中：

```text
Remote Snapshot
    ↓
version
published_at
release note
status
URL

Local
    ↓
software
installed version
install path
```

然后 Agent 输出：

```text
UPDATE
SYNCED
NOT INSTALLED
HOLD
REVIEW
REMOTE ERROR
```

---

## 13. Release Note 分析重点

Local Agent 阅读 Release Note 时，重点寻找：

```text
Production warning
Not recommended for production
Beta
Preview
Experimental
Breaking change
Known issue
Regression
Security fix
Critical bug fix
Deprecated
Migration required
```

尤其：

```text
「最新版本」
```

与：

```text
「推荐升级版本」
```

**必须分开。**

例如：

```text
Latest:
1.8.0

Release Note:
Not recommended for production use
```

则：

```text
Version changed          = YES
Upgrade recommendation   = HOLD
```

---

## 14. 未来扩展：多 Provider

第一阶段只实现：

```text
GitHub
```

以后再增加：

```text
Provider
├─ GitHub
├─ GitLab
├─ Docker Hub
├─ PyPI
├─ npm
├─ vendor website
└─ other
```

统一输出：

```yaml
source:
project:
version:
published_at:
url:
status:
release_name:
release_note:
metadata:
```

于是 **Local Agent 不需要知道数据来自哪里**。

---

## 15. 推荐的未来数据模型

如果以后从 `output.md` 扩展到 `output.json`，统一结构：

```json
{
  "generatedAt": "2026-09-11T02:00:00Z",
  "source": "github",
  "items": [
    {
      "id": "vscode",
      "name": "Visual Studio Code",
      "repo": "microsoft/vscode",
      "version": "1.105.0",
      "releaseName": "August 2026",
      "publishedAt": "2026-09-10T12:30:00Z",
      "url": "https://github.com/microsoft/vscode/releases/tag/1.105.0",
      "draft": false,
      "prerelease": false,
      "status": "ok",
      "releaseNote": "..."
    }
  ]
}
```

但：

> **第一版不要求同时维护 md + json 两套事实源。**

先用一个即可。

---

## 16. 第一版不要做的事情

不要加入：

```text
AI summary
本地版本
复杂 SemVer
自动升级
下载
安装
回滚
多 provider
数据库
Web UI
通知平台集成
复杂 retry
复杂历史数据库
```

第一版只有：

```text
checklist
→ GitHub
→ version + release note
→ output.md
→ commit
```

---

## 17. 最终目标

第一阶段：

```text
GitHub Actions
    ↓
每日生成可靠 Release Snapshot
```

第二阶段：

```text
Snapshot
    ↓
Local Agent
    ↓
Version + Release Note Analysis
    ↓
Daily Upgrade Report
```

第三阶段：

```text
Approved Update
    ↓
Updater
    ↓
Install
    ↓
Verify
```

最终形成：

```text
Monitor
   ↓
Understand
   ↓
Decide
   ↓
Upgrade
   ↓
Verify
```

其中每层保持独立。

---

## 18. 实施原则

实现优先级：

```text
简单
>
可维护
>
可替换
>
可扩展
```

而不是：

```text
功能数量
>
架构复杂度
>
测试数量
```

> 远端 Monitor 的代码应该尽可能短。
> 真正的智能留在 Local Agent。

成熟项目可以直接替换 Remote Monitor，只要能够提供等价的：

```text
version
published_at
url
status
release_note
```

即可。

---

## 19. 仓库结构

```text
apps-Release-Monitor-Actions/
├─ .github/
│  └─ workflows/
│     └─ release-monitor.yml
├─ config/
│  └─ checklist.yml
├─ output/
│  └─ output.md
└─ README.md
```

后续扩展多 provider 时，名称仍然成立：

```text
apps-Release-Monitor-Actions
    ├─ GitHub
    ├─ GitLab
    ├─ Docker Hub
    ├─ 官方网站
    └─ 其他来源
```
