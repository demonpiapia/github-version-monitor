# Teamwork Guideline Spec — General Template

## Agent Engineering 工作流分层 / Agent Engineering Workflow Layering

> 定位：本文件是**协作契约通用模板**，不是操作手册。  
> 作用：让参与项目的**每一个环节【GPT（anthropic） / 本地 Agent / Git / 运行时】**&#x90FD;能回答两个问题——
>
> 1. 我在整个流程里的**位置**是哪里？
> 2. 我**该做什么**、**不该做什么**？
>
> 使用方式：**复制本模板到具体项目**，按项目实际填入目录名与 Git 策略，形成该项目的 `Teamwork-Guideline-spec-"项目名".md`。

---

## 元数据 Metadata

| 字段 Field      | 值 Value                                    |
| ------------- | ------------------------------------------ |
| 文档名 Document  | Teamwork Guideline Spec — General Template |
| 主题 Subject    | Agent Engineering 工作流分层（通用模板）              |
| 版本 Version    | v1.4                                       |
| 日期 Date       | 2026-09-09                                 |
| 状态 Status     | 通用模板 General template                      |
| 适用范围 Scope    | 各类 Agent 工程协作项目                            |
| 存放位置 Location | `.Teamwork-Guideline/`                     |

---

## 目录 TOC

1. 目的与定位 Purpose
2. 最高原则：Git = Single Source of Truth
3. 角色分工 Role Boundary
   - 远端顾问角色
   - 本地 Agent 角色清单
4. 六层工作流分层 The 6-Layer Workflow
   - L1 `.GPT/（.anthropic/）`
   - L2 `.exec-plan/`
   - L3 `.handoff/`
   - L4 `.selfreview/`
   - L5 `.output/`
   - L6 `.runtime/`
5. Handoff 文件标准字段
6. 文件命名约定
   - 执行计划文件
   - 审计报告
   - 自审报告
7. 待议层：`.contract/`
8. Git 仓库结构（推荐）
9. 非流程资产目录
   - `.Template/`
   - `.Teamwork-Guideline/`
10. 全景流程图
11. 模板落地清单

---

## 1. 目的与定位 Purpose

本模板解决一个具体问题：**多环境协作时，事实来源与职责边界不清，导致版本回滚与功能丢失。**

用**分层 + 单向事实来源**消除该问题。

三条硬规则 Hard rules：

| #  | 规则 Rule                                  |
| -- | ---------------------------------------- |
| R1 | Git 仓库 = 唯一事实同步层（single source of truth） |
| R2 | 聊天上下文**不再**作为版本事实来源                      |
| R3 | 每类职责只归属一个层，不混放（同层并列目录名视为同一层）             |

---

## 2. 最高原则：Git = Single Source of Truth

> **Git repository = single source of truth**

含义：项目内**需要跨环境共享与留痕**的内容，一律以 Git 为唯一事实层。

```text
Git（远端同步层）
├─ 项目本体文件
├─ readme.md
├─ .exec-plan/
├─ .handoff/
├─ .selfreview/
├─ .GPT/（.anthropic/）
├─ .Template/
└─ .Teamwork-Guideline/
```

配套工作原则：

| 角色 Role        | 职责 Responsibility                                     |
| -------------- | ----------------------------------------------------- |
| GPT（anthropic） | 架构 / **独立审计（Independent Audit）** / 判断 / Prompt / 版本设计 |
| 本地 Agent       | 执行 / 修改 / 测试 / Git 操作 / 现实环境验证                        |
| Git            | 唯一事实同步层                                               |
| 聊天上下文          | **非**事实来源，仅用于讨论与决策                                    |

---

## 3. 角色分工 Role Boundary

```text
GPT（anthropic） → 决策与设计：架构、独立审计（Independent Audit）、判断、Prompt、版本设计
本地 Agent        → 执行与验证：执行、修改、测试、Git 操作、现实环境验证
Git               → 同步：唯一事实层
聊天上下文         → 讨论：不作为版本事实
```

审计定性 Audit definition：

> GPT（anthropic）的审计是**独立审计（Independent Audit）**：  
> 独立复核仓库状态与执行产物，**不采信、不依赖**本地 Agent 的自审结论作为依据。

边界要点 Boundary notes：

- GPT（anthropic）**不下场改文件**；本地 Agent **不擅自变更架构决策**。
- 独立审计的对象是**仓库中的实际产物**——本地 agent 报告或项目主体文件（`.exec-plan/` / `.handoff/` / `.selfreview/` 等过程文件作为远端顾问审计本地 agent 执行过程的参考）。
- 版本事实以仓库为准；聊天中的描述若与仓库冲突，**以仓库为准**。
- 本地 Agent 完成执行后须 **Git 同步**，同步完成才算交付闭环。

### 远端顾问角色 GPT（anthropic）

> 远端顾问角色为 **GPT（anthropic）**，承担决策与设计职责。  
> 全文表述统一写作 `GPT（anthropic）`；目录层统一写作 `.GPT/（.anthropic/）`。

### 本地 Agent 角色清单 Local Agent Roster

| harness 名称       | 角色 Roles                           | 说明 Notes                          |
| ---------------- | ---------------------------------- | --------------------------------- |
| TRAE IDE         | coding-agent / exec-plan-maker     | 执行agent                           |
| Codebuddy        | governance-agent / test-agent      | TRAE IDE内扩展agent；本地审计、测试agent     |
| Zoo              | limited-API-rate-governance-agent  | TRAE IDE内扩展agent；本地API限流审计        |
| Cherry           | general-claude-agent               | 日常助理 /记忆管理 / 数据库管理 / 文档管理 / 自动化任务 |
| Workbuddy        | coding-assistant-agent / doc-agent | 助理执行agent                         |
| codexCLI         | audit-sub-agent                    | 本地代码审计专用CLI agent                 |
| others IDE / CLI | support-agent/sub-coding-agent     |                                   |

---


## 4. 六层工作流分层 The 6-Layer Workflow

> 以下 6 层为**流程层**（执行链路）。  
> 仓库内另有**非流程资产目录** `.Template/` 与 `.Teamwork-Guideline/`，不参与执行数据流，定义见 §9。

分层总览 Overview：

| 层 Layer | 目录 Directory         | 定位 Positioning          | Git 策略 Git Policy（默认）   |
| ------- | -------------------- | ----------------------- | ----------------------- |
| L1      | `.GPT/（.anthropic/）` | 人类 ↔ GPT（anthropic）决策输入 | 进 Git                   |
| L2      | `.exec-plan/`        | Agent → 执行规划            | 进 Git                   |
| L3      | `.handoff/`          | Agent → Agent 上下文传递     | 进 Git                   |
| L4      | `.selfreview/`       | Agent → 自我审查            | 进 Git                   |
| L5      | `.output/`           | 生产状态（Production State）  | **不上传远端，仅本地持久化**        |
| L6      | `.runtime/`          | 运行时状态（Runtime State）    | `.gitignore`，**不进 Git** |

数据流向 Flow：

```text
.GPT/（.anthropic/） → .exec-plan/ → .handoff/ → .selfreview/ → 〔Git 同步〕→ .output/

.runtime/ = 临时运行时，不进入同步链
```

Git 策略为**默认建议**，具体项目可在自身 spec 中显式改写（改写必须在 spec 中写明，不得靠约定俗成）。

---

### L1 `.GPT/（.anthropic/）` — 决策输入层 Decision Input

| 项      | 内容                                                                           |
| ------ | ---------------------------------------------------------------------------- |
| 定位     | 人类 ↔ GPT（anthropic）的决策输入                                                     |
| 内容     | validation prompt / revision prompt / research notes / GPT（anthropic）生成的工作指令 |
| Git 策略 | 进 Git                                                                        |
| 示例     | `.GPT/<task>-prompt.md`                                                      |

说明：任务 Prompt 及 GPT（anthropic）侧所需上下文由本层文件提供；纳入 Git 后，决策输入具备版本事实。

目录命名 Note：本层目录名为 `.GPT/`；如并列 `.anthropic/` 目录，与本层同层同职责，规范描述统一写作 `.GPT/（.anthropic/）`。

---

### L2 `.exec-plan/` — 执行规划层 Execution Plan

| 项      | 内容                                          |
| ------ | ------------------------------------------- |
| 定位     | 本地 Agent 对 GPT（anthropic）下达任务的**执行规划**      |
| 回答     | 做什么 / 先做什么 / 后做什么 / 使用什么工具 / 测试哪些项 / 如何组织结果 |
| Git 策略 | 进 Git                                       |

价值 Value：

> 让 GPT（anthropic）不只看到"最终报告"，还能理解 **Agent 准备怎么做**。

---

### L3 `.handoff/` — 上下文传递层 Context Handoff

| 项      | 内容                                |
| ------ | --------------------------------- |
| 定位     | 执行上下文在多个 Agent / 多个执行阶段之间的**传递层** |
| 目标     | 换 Agent 也不重新解释上下文                 |
| Git 策略 | 进 Git                             |

推荐字段结构见 §5。

---

### L4 `.selfreview/` — 自我审查层 Self Audit

| 项      | 内容                                                       |
| ------ | -------------------------------------------------------- |
| 定位     | Agent → Self Audit（执行完成后的自我检查）                           |
| Git 策略 | 进 Git                                                    |
| 性质     | 轻量 second-pass QA                                        |
| 边界     | 属**执行侧自审**，**不等同于** GPT（anthropic）的**独立审计**；自审结论须经独立审计复核 |

流程改变 Process change：

```text
旧：执行 → 直接说"完成"
新：执行 → 自我审查 → 交付
```

---

### L5 `.output/` — 生产状态层 Production State

| 项      | 内容                                                 |
| ------ | -------------------------------------------------- |
| 定位     | **Production State Artifact**（持久化生产状态，不是普通 output） |
| 性质     | Input + Persistent State + Output 三合一              |
| Git 策略 | **不上传远端，仅本地持久化**（默认）                               |
| 示例     | `.output/<项目主状态文件>.md`                             |

不上传远端的原因：本层为实时生产状态，多环境各自演进，上传易产生冲突、复用价值低；需留历史应由项目自定义归档策略。

重要 Important：

> `.output/` 明确称为 **Production State Artifact**。  
> 它不是"输出目录"，而是**持久化生产状态**——比一般 output 文件更重要。

例外 Exception：若项目要求状态跨环境共享，可在项目 spec 中**显式**将本层改为进 Git，并说明冲突处理策略。

---

### L6 `.runtime/` — 运行时状态层 Runtime State

| 项      | 内容                                                               |
| ------ | ---------------------------------------------------------------- |
| 定位     | Runtime State（临时运行时）                                             |
| 内容     | `run.lock` / `result.json` / `tmp` / `backup` / `trash` / `logs` |
| Git 策略 | `.gitignore`，**不进 Git**                                          |

定性：全部属于 **ephemeral runtime**，不参与版本事实，可随时丢弃。

与 L5 的区分 Distinction from L5：

| 层           | 持久性 | 可否丢弃 | 典型内容      |
| ----------- | --- | ---- | --------- |
| `.output/`  | 持久  | 否    | 项目主状态文件   |
| `.runtime/` | 临时  | 是    | 锁、临时文件、日志 |

---

## 5. Handoff 文件标准字段 Handoff Schema

`.handoff/` 下的文件**建议**采用以下字段顺序（冻结建议 Frozen suggestion）：

```text
TASK
INPUTS
CURRENT_STATE
COMPLETED
FAILED
BLOCKED
NEXT_ACTION
IMPORTANT_FACTS
```

目的：即使更换 Agent，也不需要重新解释上下文。

---

## 6. 文件命名约定 File Naming Conventions

### 执行计划文件

| 项       | 约定                               |
| ------- | -------------------------------- |
| 生成者     | exec-plan-maker                  |
| 存放目录    | `.exec-plan/`                    |
| 命名格式    | `exec-plan-<项目版本号>-<执行计划版本号>.md` |
| 执行计划版本号 | `a` / `b` / `c` / `d` … 单字母顺序迭代  |
| 示例      | `exec-plan-v1.10-a.md`           |

### 审计报告

| 项          | 约定                                        |
| ---------- | ----------------------------------------- |
| 生成者        | governance-agent / audit-agent            |
| 存放目录       | **与被审计文件同目录**                             |
| 命名格式       | `<被审计文件名>-<harness 名称>-review.md`         |
| harness 名称 | TRAE IDE / Codebuddy / Cherry / Workbuddy / codexCLI / others IDE / CLI（取值以 §3 角色清单为准） |
| 示例         | `SKILL-v1.10-codexCLI-review.md`          |

### 自审报告

| 项     | 约定                                                  |
| ----- | --------------------------------------------------- |
| 生成者   | coding agent                                        |
| 存放目录  | `.selfreview/`                                      |
| 命名格式  | `selfreview-<execution + 项目版本号 + 执行计划版本号>-<时间戳>.md` |
| 时间戳格式 | `YYYYMMDDHHmm`（日期时分，无间隔）                            |
| 示例    | `selfreview-execution-v1.10-a-202609090931.md`      |

---

## 7. 待议层：`.contract/` — Deferred Layer

状态：**默认不建立**（项目执行闭环稳定前，过早拆分文件会增加同步成本）。

未来用途：

```text
项目本体
    ↓
Stable Contract
```

建议内容（如将来启用）：

```text
.contract/
├─ state-schema.md
├─ result-schema.md
├─ runtime-status.md
└─ version-policy.md
```

收益 Benefit：

- 修改**外观 / 汇报格式**不会触碰 contract
- 实现只需遵守稳定契约
- 项目从"一个很长的说明文档"演进为：

```text
Contract
   +
Implementation
   +
Validation
   +
Runtime
```

启用条件 Trigger：出现下列任一情况时再评估——

- 格式变更开始影响行为判定
- 多个实现模块共用同一份状态
- 需要跨项目复用同一套状态/结果定义

---


## 8. Git 仓库结构（推荐） Recommended

本章只回答：**哪些目录进仓库、哪些不进**。各目录的用途定义分布在 §4（流程层）与 §9（非流程资产目录）。

Git 内（上传远端）：

```text
Git
├─ 项目本体文件
├─ readme.md
├─ .exec-plan/
├─ .handoff/
├─ .selfreview/
├─ .GPT/（.anthropic/）
├─ .Template/
└─ .Teamwork-Guideline/
```

Git 外（仅本地）：

```text
.output/     持久化生产状态（Production State）
.runtime/    临时运行时（Runtime State）
```

目录职责说明 Directory roles：

| 目录                     | 职责                          | Git 策略       |
| ---------------------- | --------------------------- | ------------ |
| `.exec-plan/`          | 执行规划                        | 进 Git        |
| `.handoff/`            | Agent 间上下文传递                | 进 Git        |
| `.selfreview/`         | 自我审查                        | 进 Git        |
| `.GPT/（.anthropic/）`   | 决策输入（本模板中称 L1）              | 进 Git        |
| `.Template/`           | 可复用模板存放目录（定义见 §9）           | 进 Git        |
| `.Teamwork-Guideline/` | 工程约定与协作体系 spec 文件目录（定义见 §9） | 进 Git        |
| `.output/`             | Production State Artifact   | 仅本地（默认）      |
| `.runtime/`            | Runtime State               | `.gitignore` |

---

## 9. 非流程资产目录 Non-flow Asset Directories

> 本类目录**不属于 L1–L6 流程层**，不参与执行数据流，仅作为仓库内的长期资产存放位置。

### `.Template/` — 可复用模板目录 Reusable Templates

| 项      | 内容                  |
| ------ | ------------------- |
| 定位     | 可复用模板存放目录（**非流程层**） |
| 用途     | 沉淀可复用模板，供各流程层按需取用   |
| Git 策略 | 进 Git               |
| 与流程层关系 | 不属于 L1–L6，不参与执行数据流  |

约定 Conventions：

- 本目录是**资产目录**，不是执行层：不进入 `.GPT/（.anthropic/） → … → .output/` 的数据流。
- 模板的具体类型由项目自行积累，本模板**不枚举**。
- 取用原则：模板被实例化后的产物，按**落地位置**归属对应层（例如落到 `.handoff/` 即受 §5 字段约束）；模板原件始终留在 `.Template/`。

### `.Teamwork-Guideline/` — 工程约定与协作体系目录 Engineering Convention

| 项      | 内容                                                                           |
| ------ | ---------------------------------------------------------------------------- |
| 定位     | 工程约定与协作体系 spec 文件存放目录（**非流程层**）                                              |
| 内容     | `Teamwork-Guideline-spec-"项目名".md`、通用模板 `Teamwork-Guideline-spec-general.md` |
| Git 策略 | 进 Git                                                                        |
| 与流程层关系 | 不属于 L1–L6，不参与执行数据流；本目录是**流程的定义者**，不是流程的参与者                                   |

---


## 10. 全景流程图 Workflow Map

```text
                      ┌──────────────────────┐
                      │   GPT（anthropic）    │
                      │   Architecture      │
                      │   Independent Audit │
                      │   Prompt            │
                      └──────────┬───────────┘
                                 │ 工作指令 / Prompt
                                 ▼
                    .GPT/（.anthropic/）
                                 │
                                 ▼
                      ┌──────────────────────┐
                      │     本地 Agent        │
                      │     Execution        │
                      └──────────┬───────────┘
                                 │
              ┌──────────────────┼──────────────────┐
              ▼                  ▼                  ▼
       .exec-plan/          .handoff/        .selfreview/
              │                  │                  │
              └──────────────────┼──────────────────┘
                                 │ Git 同步
                                 ▼
                      ┌──────────────────────┐
                      │         Git          │
                      │  唯一事实同步层        │
                      └──────────┬───────────┘
       ┌─────────────────────────┼─────────────────────────┐
       ▼                         ▼                         ▼
  项目本体文件              .Template/        .Teamwork-Guideline/
 Implementation         Reusable Templates   Engineering Convention
                                 │
                                 │ 执行产出（本地）
                                 ▼
                      ┌──────────────────────┐
                      │      .output/        │
                      │  Production State    │
                      │  （仅本地持久化）      │
                      └──────────┬───────────┘
                                 │ 运行过程
                                 ▼
                      ┌──────────────────────┐
                      │      .runtime/       │
                      │   Runtime State      │
                      │  （临时，可丢弃）      │
                      └──────────────────────┘

  ── Git 内（上传远端）：项目本体文件 / .exec-plan/ / .handoff/
     .selfreview/ / .GPT/（.anthropic/）/ .Template/ / .Teamwork-Guideline/
  ── Git 外（仅本地）：.output/ / .runtime/
  ── 审计：GPT（anthropic）对 Git 内容做独立审计，不采信 .selfreview/ 自审结论
```

---

## 11. 模板落地清单 Adoption Checklist

复制本模板到具体项目后，逐项确认：

| # | 待确认项                            | 默认值 Default  |
| - | ------------------------------- | ------------ |
| 1 | 是否启用 `.anthropic/` 并列目录         | 否（仅 `.GPT/`） |
| 2 | L1 `.GPT/（.anthropic/）` 是否进 Git | 进 Git        |
| 3 | L5 `.output/` 是否上传远端            | **否（仅本地）**   |
| 4 | L6 运行时目录名                       | `.runtime/`  |
| 5 | 是否启用 `.contract/`               | 否            |
| 6 | 项目本体文件名与位置                      | 按项目填写        |
| 7 | `.output/` 主状态文件名               | 按项目填写        |
| 8 | Handoff 字段是否扩展                  | 沿用 §5 八字段    |

确认后写入该项目的 `Teamwork-Guideline-spec-"项目名".md`，并删除本模板中的"通用/默认"表述。
