# Teamwork Guideline Spec

## Agent Engineering 工作流分层 / Agent Engineering Workflow Layering

> 定位：本文件是**协作契约**，不是操作手册。
> 作用：让参与本项目的**每一个环节【GPT（anthropic） / 本地 Agent / Git / 运行时】**都能回答两个问题——
>
> 1. 我在整个流程里的**位置**是哪里？
> 2. 我**该做什么**、**不该做什么**？

---

## 元数据 Metadata

| 字段 Field | 值 Value |
| --- | --- |
| 文档名 Document | Teamwork Guideline Spec |
| 主题 Subject | Agent Engineering 工作流分层 |
| 版本 Version | v0.3 |
| 日期 Date | 2026-09-08 |
| 状态 Status | 已固定为工程约定 Fixed as engineering convention |
| 适用范围 Scope | 本项目全部执行环境（GPT（anthropic） / 本地 Agent / Git / Runtime） |
| 存放位置 Location | `.Teamwork-Guideline/` |

---

## 目录 TOC

1. [目的与定位 Purpose](#1-目的与定位-purpose)
2. [最高原则：Git = Single Source of Truth](#2-最高原则git--single-source-of-truth)
3. [角色分工 Role Boundary](#3-角色分工-role-boundary)
4. [六层工作流分层 The 6-Layer Workflow](#4-六层工作流分层-the-6-layer-workflow)
   - [L1 `.GPT/（.anthropic/）`](#l1-gptanthropic--决策输入层-decision-input)
   - [L2 `.exec-plan/`](#l2-exec-plan--执行规划层-execution-plan)
   - [L3 `.handoff/`](#l3-handoff--上下文传递层-context-handoff)
   - [L4 `.selfreview/`](#l4-selfreview--自我审查层-self-audit)
   - [L5 `.output/`](#l5-output--生产状态层-production-state)
   - [L6 `.monitor/`](#l6-monitor--运行时状态层-runtime-state)
5. [Handoff 文件标准字段](#5-handoff-文件标准字段-handoff-schema)
6. [待议层（当前项目）：`.contract/`](#6-待议层当前项目contract--deferred-layer)
7. [Git 仓库结构（冻结）](#7-git-仓库结构冻结-frozen)
8. [全景流程图](#8-全景流程图-workflow-map)

---

## 1. 目的与定位 Purpose

本规范解决一个具体问题：**多环境协作时，事实来源与职责边界不清，导致版本回滚与功能丢失。**

本规范用**分层 + 单向事实来源**消除该问题。

三条硬规则 Hard rules：

| # | 规则 Rule |
| --- | --- |
| R1 | Git 仓库 = 唯一事实同步层（single source of truth） |
| R2 | 聊天上下文**不再**作为版本事实来源 |
| R3 | 每类职责只归属一个层，不混放（同层并列目录名视为同一层，如 `.GPT/`（`.anthropic/`）） |

---

## 2. 最高原则：Git = Single Source of Truth

从本文件生效起，正式采用：

> **Git repository = single source of truth**

含义：

```text
Git
├─ 项目本体文件（如 SKILL-v1.x.md）
├─ readme.md
├─ .output/
├─ .exec-plan/
├─ .handoff/
├─ .selfreview/
├─ .GPT/（.anthropic/）
└─ .Teamwork-Guideline/
```

配套工作原则：

| 角色 Role | 职责 Responsibility |
| --- | --- |
| GPT（anthropic） | 架构 / **独立审计（Independent Audit）** / 判断 / Prompt / 版本设计 |
| 本地 Agent | 执行 / 修改 / 测试 / Git 操作 / 现实环境验证 |
| Git | 唯一事实同步层 |
| 聊天上下文 | **非**事实来源，仅用于讨论与决策 |

---

## 3. 角色分工 Role Boundary

```text
GPT（anthropic） → 决策与设计：架构、独立审计（Independent Audit）、判断、Prompt、版本设计
本地 Agent       → 执行与验证：执行、修改、测试、Git 操作、现实环境验证
Git              → 同步：唯一事实层
聊天上下文        → 讨论：不作为版本事实
```

审计定性 Audit definition：

> GPT（anthropic）的审计是**独立审计（Independent Audit）**：
> 独立复核仓库状态与执行产物，**不采信、不依赖**本地 Agent 的自审结论作为依据。

边界要点 Boundary notes：

- GPT（anthropic）**不下场改文件**；本地 Agent **不擅自变更架构决策**。
- 独立审计的对象是**仓库中的实际产物**（`.output/` / `.selfreview/` / `.exec-plan/` 等），不是聊天中的描述。
- 版本事实以仓库为准；聊天中的描述若与仓库冲突，**以仓库为准**。
- 本地 Agent 完成执行后须 **Git 同步**，同步完成才算交付闭环。

---

## 4. 六层工作流分层 The 6-Layer Workflow

分层总览 Overview：

| 层 Layer | 目录 Directory | 定位 Positioning | Git 策略 Git Policy |
| --- | --- | --- | --- |
| L1 | `.GPT/（.anthropic/）` | 人类 ↔ GPT（anthropic）决策输入 | **进 Git** |
| L2 | `.exec-plan/` | Agent → 执行规划 | **进 Git** |
| L3 | `.handoff/` | Agent → Agent 上下文传递 | **进 Git** |
| L4 | `.selfreview/` | Agent → 自我审查 | **进 Git** |
| L5 | `.output/` | 生产状态（Production State） | **进 Git** |
| L6 | `.monitor/` | 运行时状态（Runtime State） | `.gitignore`，**不进 Git** |

数据流向 Flow：

```text
.GPT/（.anthropic/） → .exec-plan/ → .handoff/ → .selfreview/ → 〔Git 同步〕→ .output/

.monitor/ = Git 外运行时（Runtime State），不进入同步链
```

---

### L1 `.GPT/（.anthropic/）` — 决策输入层 Decision Input

| 项 | 内容 |
| --- | --- |
| 定位 | 人类 ↔ GPT（anthropic）的决策输入 |
| 内容 | validation prompt / revision prompt / research notes / GPT（anthropic）生成的工作指令 |
| Git 策略 | **进 Git** |
| 示例 | `.GPT/v1.8-targeted-validation-prompt.md` |

说明：任务 Prompt 及 GPT（anthropic）侧所需上下文由本层文件提供；本层纳入 Git，作为决策输入的版本事实。

目录命名 Note：本层当前目录名为 `.GPT/`，未来如新增 `.anthropic/` 目录，与本层同层同职责；规范描述统一写作 `.GPT/（.anthropic/）`。

---

### L2 `.exec-plan/` — 执行规划层 Execution Plan

| 项 | 内容 |
| --- | --- |
| 定位 | 本地 Agent 对 GPT（anthropic）下达任务的**执行规划** |
| 回答 | 做什么 / 先做什么 / 后做什么 / 使用什么工具 / 测试哪些项 / 如何组织结果 |
| Git 策略 | **进 Git** |

价值 Value：

> 让 GPT（anthropic）不只看到"最终报告"，还能理解 **Agent 准备怎么做**。

---

### L3 `.handoff/` — 上下文传递层 Context Handoff

| 项 | 内容 |
| --- | --- |
| 定位 | 执行上下文在多个 Agent / 多个执行阶段之间的**传递层** |
| 目标 | 换 Agent 也不重新解释上下文 |
| Git 策略 | **进 Git** |

推荐字段结构见 [§5](#5-handoff-文件标准字段-handoff-schema)。

---

### L4 `.selfreview/` — 自我审查层 Self Audit

| 项 | 内容 |
| --- | --- |
| 定位 | Agent → Self Audit（执行完成后的自我检查） |
| Git 策略 | **进 Git** |
| 性质 | 轻量 second-pass QA |
| 边界 | 属**执行侧自审**，**不等同于** GPT（anthropic）的**独立审计**；自审结论须经独立审计复核 |

流程改变 Process change：

```text
旧：执行 → 直接说"完成"
新：执行 → 自我审查 → 交付
```

---

### L5 `.output/` — 生产状态层 Production State

| 项 | 内容 |
| --- | --- |
| 定位 | **Production State Artifact**（当前项目范围内，不是普通 output） |
| 性质 | Input + Persistent State + Output 三合一 |
| Git 策略 | **进 Git** |
| 已确认路径 | `.output/GitHub更新监测列表.md` |

重要 Important：

> 在当前项目中，`.output/` 明确称为 **Production State Artifact**。
> 它不是"输出目录"，而是**持久化生产状态**——比一般 output 文件更重要。

---

### L6 `.monitor/` — 运行时状态层 Runtime State

| 项 | 内容 |
| --- | --- |
| 定位 | Runtime State（临时运行时） |
| 内容 | `run.lock` / `result.json` / `tmp` / `backup` / `trash` / `logs` |
| Git 策略 | `.gitignore`，**不进 Git**（保持现状，不再推 Git） |

定性：全部属于 **ephemeral runtime**，不参与版本事实。

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

## 6. 待议层（当前项目）：`.contract/` — Deferred Layer

状态：**当前项目下不建立**（现阶段核心任务是稳定执行闭环，过早拆分文件会增加同步成本）。

未来用途：

```text
SKILL
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
- Skill 只需遵守稳定契约
- 项目从"一个很长的 SKILL.md"演进为：

```text
Contract
   +
Implementation
   +
Validation
   +
Runtime
```

---

## 7. Git 仓库结构（冻结） Frozen

```text
Git
├─ 项目本体文件（如 SKILL-v1.x.md）
├─ readme.md
├─ .output/
├─ .exec-plan/
├─ .handoff/
├─ .selfreview/
├─ .GPT/（.anthropic/）
└─ .Teamwork-Guideline/
```

目录职责说明 Directory roles：

| 目录 | 职责 |
| --- | --- |
| `.output/` | Production State Artifact（当前项目） |
| `.exec-plan/` | 执行规划 |
| `.handoff/` | Agent 间上下文传递 |
| `.selfreview/` | 自我审查 |
| `.GPT/（.anthropic/）` | 决策输入（本 spec 中称 L1） |
| `.Teamwork-Guideline/` | 工程约定与协作体系 spec 文件目录（本文件所属层） |

不进 Git Not in Git：

```text
.monitor/
```

---

## 8. 全景流程图 Workflow Map

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
                      │     Local Agent      │
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
   .output/                    SKILL          .Teamwork-Guideline/
Production State          Implementation     Engineering Convention
 （当前项目）

  ── Git 内（同步层内容）：.output/ / SKILL / .Teamwork-Guideline/
     .exec-plan/ / .handoff/ / .selfreview/ / .GPT/（.anthropic/）
  ── Git 外（仅本地）：.monitor/ = Runtime State
  ── 审计：GPT（anthropic）对上述 Git 内容做独立审计，不采信 .selfreview/ 自审结论
```
