# Diff Integrity — SKILL-v1.12 vs SKILL-v1.11

**Phase**: 1 (SKILL modification + Diff Integrity gate)
**Generated**: 2026-09-10T21:42 (Asia/Hong_Kong)

---

## 0. File hashes

| File | SHA256 |
|---|---|
| `SKILL-v1.11.md` (baseline, read-only) | `B6632680A9AE18E02634E6EAF7F261FCD2502FE0529566088D0E0FC7160FC928` |
| `SKILL-v1.12.md` (this phase output) | `3B15C9D7B3B37ADDB185489EBE2E8B89617867787F5EB83979FF066D23B28BE9` |

v1.11 baseline hash matches Phase 0 record (`.production-validation-v112-final/state.sha256`).

---

## 1. `git diff --no-index` hunk summary

`git diff --no-index SKILL-v1.11.md SKILL-v1.12.md > .production-validation-v112-final/v111-v112.diff`

Exit code: **1** (expected — files differ; git diff returns 1 for any diff).

Diff size: **7372 bytes**.

### 1.1 Default context (U3, `git diff --no-index` default) → **6 hunks**

| # | Hunk header | v1.11 range | v1.12 range | Change type | Logical P-changes covered |
|---|---|---|---|---|---|
| 1 | `@@ -5,8 +5,8 @@` | L5-12 | L5-12 | 2-line substitution | **P1-a** (L8) + **P1-b** (L9) merged (adjacent, 1 line apart) |
| 2 | `@@ -41,6 +41,12 @@` | L41-46 | L41-52 | +6 line insertion | **P1-c** (§2 execution context) |
| 3 | `@@ -159,6 +165,11 @@` | L159-164 | L165-175 | +5 line insertion | **P1-d** (Step 1 PS7 check) |
| 4 | `@@ -444,11 +455,16 @@` | L444-454 | L455-470 | try/catch wrap | **P2-a** (Step 3 housekeeping) |
| 5 | `@@ -689,13 +705,14 @@` | L689-701 | L705-718 | 1-line substitution + 1-line insertion | **P1-e** (L692 stage col) + **P2-b** (L699 HOUSEKEEPING_WARNING row) merged (6 lines apart) |
| 6 | `@@ -765,6 +782,7 @@` | L765-770 | L782-788 | +1 line insertion | **Step 5** (Changelog v1.12 entry) |

### 1.2 Minimal context (`git diff --no-index -U0`) → **7 hunks**

The `-U0` view is retained at `.production-validation-v112-final/v111-v112.U0.diff` for granular verification:

| # | Hunk header | Line | Change type | Logical P-change |
|---|---|---|---|---|
| 1 | `@@ -8,2 +8,2 @@` | L8-9 | 2-line substitution | P1-a + P1-b (still merged under U0 because they touch both lines 8 and 9) |
| 2 | `@@ -43,0 +44,6 @@` | L43 | +6 line insertion | P1-c |
| 3 | `@@ -161,0 +168,5 @@` | L161 | +5 line insertion | P1-d |
| 4 | `@@ -447,5 +458,10 @@` | L447-451 | wrap | P2-a |
| 5 | `@@ -692 +708 @@` | L692 | 1-line substitution | P1-e |
| 6 | `@@ -698,0 +715 @@` | L698 | +1 line insertion | P2-b |
| 7 | `@@ -767,0 +785 @@` | L767 | +1 line insertion | Changelog |

### 1.3 All 8 logical changes accounted for — **no unexpected hunks**

The prompt expected 8 logical changes. Under default `-U3`, two natural merges produce 6 hunks; under `-U0`, one merge remains (P1-a+P1-b on adjacent lines 8-9) producing 7 hunks. The full 8 logical changes are all present and accounted for in both views.

| Logical change | Present in U3? | Present in U0? |
|---|---|---|
| P1-a L8 version | ✅ Hunk 1 | ✅ Hunk 1 |
| P1-b L9 PS7 ONLY | ✅ Hunk 1 | ✅ Hunk 1 |
| P1-c §2 path+contract | ✅ Hunk 2 | ✅ Hunk 2 |
| P1-d Step 1 PS7 check | ✅ Hunk 3 | ✅ Hunk 3 |
| P2-a Step 3 housekeeping | ✅ Hunk 4 | ✅ Hunk 4 |
| P1-e §9 RUNTIME_ERROR stage col | ✅ Hunk 5 | ✅ Hunk 5 |
| P2-b §9 HOUSEKEEPING_WARNING | ✅ Hunk 5 | ✅ Hunk 6 |
| Step 5 Changelog | ✅ Hunk 6 | ✅ Hunk 7 |

**Diff Integrity: PASS** — no unexpected hunks. All hunks correspond to the exact change list from Prompt §4 (P1/P2/P3).

---

## 2. `git diff --check` output

Command: `git diff --check --no-index SKILL-v1.11.md SKILL-v1.12.md`

Exit code: **1** (from the underlying `git diff --no-index`, not from `--check` itself).

Full output (only 2 lines):

```
warning: in the working copy of 'SKILL-v1.11.md', LF will be replaced by CRLF the next time Git touches it
warning: in the working copy of 'SKILL-v1.12.md', LF will be replaced by CRLF the next time Git touches it
```

Interpretation: **no whitespace errors** (no `warning: trailing whitespace`, no `warning: space before tab`, no `warning: patch left trailing whitespace`). The two lines are pre-existing line-ending auto-conversion notices emitted by git for both files, present in the baseline as well — they are informational and unrelated to any v1.12 introduced whitespace. **Whitespace-clean: PASS**.

---

## 3. P3 review — 6 fatal paths (post-P1/P2 line numbers)

Per Prompt §6, P3 is review-only; no code modifications. Line numbers below are from `SKILL-v1.12.md` (post-shift). Each path was verified to have an explicit error status output (`RUNTIME_ERROR|` / `PARSE_ERROR|` / `LOCKED|`), therefore §9 table already classifies them as failed-terminal for this round — they are not "第 1 类" (truly fatal + no clear final state).

| v1.11 line | v1.12 line | Path | Error status emitted | Classification | Decision |
|---|---|---|---|---|---|
| L254 | L264 | Step 2 lock missing → `RUNTIME_ERROR\|运行锁不存在（步骤1未执行或锁已丢失），本轮终止。` | `RUNTIME_ERROR\|` | 第 3 类：§9 已 failed | **不修改** |
| L320 | L331 | Step 2 `PARSE_ERROR\|状态文件 schema 校验失败，本轮终止，不写回主 md。` + release-lock + return | `PARSE_ERROR\|` | 第 3 类 | **不修改** |
| L406 | L415 | Step 2 `result.fetch.tmp` JSON schema check fail → `RUNTIME_ERROR\|result.fetch.tmp JSON 结构校验失败，未替换 result.json。` | `RUNTIME_ERROR\|` | 第 3 类 | **不修改** |
| L412 | L421 | Step 2 `result.json` atomic replace fail → `RUNTIME_ERROR\|result.json 原子替换失败：{0}` | `RUNTIME_ERROR\|` | 第 3 类 | **不修改** |
| L444 | L455 | Step 3 heartbeat fail → `LOCKED\|` or `RUNTIME_ERROR\|步骤3 heartbeat 失败：{0}` | `LOCKED\|` / `RUNTIME_ERROR\|` | 第 3 类 | **不修改**（heartbeat 代码未被 P2 触碰，diff hunk 4 从 `$backupDir` L456 开始） |
| L529 | L545 | Step 5 lock missing → `RUNTIME_ERROR\|运行锁不存在（步骤1未执行或锁已丢失），本轮终止。` | `RUNTIME_ERROR\|` | 第 3 类 | **不修改** |

Reason (unified): All 6 paths emit an explicit error marker that §9 already maps to `failed` (or `blocked` for `LOCKED\|`). §9 is declared the sole judging interface (L701: "本表是本轮结果的唯一判定接口"). Therefore no P3 modification is required.

P3 conclusion: **6/6 不修改**.

---

## 4. Step 7 — Capability retention evidence

Each row shows a capability from Prompt §4/§9, whether it appears in the diff removal lines (should be NONE), and the first v1.12 line where it is preserved. Full hit counts and first-3-line evidence are recorded in `.production-validation-v112-final/phase1-capability-stdout.txt`.

| # | Capability | diff deletions of it | v1.12 evidence (first line hits) | Total hits |
|---|---|---|---|---|
| 1 | `.output/GitHub更新监测列表.md` | 0 | L3, L37, L91 | 12 |
| 2 | `.monitor/` | 0 | L37, L162, L178 | 12 |
| 3 | `versionJump` | 0 | L83, L114, L124 | 7 |
| 4 | `dateSuspicious` | 0 | L83, L114, L124 | 7 |
| 5 | `reviewReasons` | 0 | L114, L392, L495 | 4 |
| 6 | schema validation | 0 | L57, L80, L92 | 13 |
| 7 | strict lowercase yes/no | 0 | L80, L103 | 2 |
| 8 | 404 → not_found | 0 | L77, L123, L139 | 10 |
| 9 | rate_limited | 0 | L42, L82, L121 | 11 |
| 10 | network_error | 0 | L142, L378 | 2 |
| 11 | auth_error | 0 | L145, L372, L438 | 3 |
| 12 | forbidden | 0 | L146, L375, L438 | 3 |
| 13 | server_error | 0 | L141, L376 | 2 |
| 14 | invalid_response | 0 | L143, L362 | 2 |
| 15 | metadata_incomplete | 0 | L144, L359 | 2 |
| 16 | http_error | 0 | L147, L377 | 2 |
| 17 | result.fetch.tmp | 0 | L409, L415, L790 | 3 |
| 18 | result.review.tmp | 0 | L485, L491, L741 | 6 |
| 19 | run.lock | 0 | L205, L262, L448 | 9 |
| 20 | heartbeat | 0 | L164, L202, L203 | 17 |
| 21 | ownership | 0 | L447, L451, L493 | 9 |
| 22 | atomic result persistence | 0 | L37, L84, L108 | 21 |
| 23 | atomic review persistence | 0 | L37, L84, L108 | 23 |
| 24 | atomic md commit | 0 | L81, L84, L85 | 40 |
| 25 | commitSucceeded | 0 | L85, L130, L637 | 7 |
| 26 | COMMIT_OK | 0 | L85, L130, L644 | 6 |
| 27 | RUN_STATUS\|success\| | 0 | L85, L130, L667 | 4 |
| 28 | RUN_STATUS\|failed\| | 0 | L87, L130, L493 | 14 |
| 29 | Get-ResponseHeaderValue | 0 | L335, L369, L790 | 3 |
| 30 | Compare-Ver | 0 | L30, L76, L301 | 8 |
| 31 | ConvertTo-NormVer | 0 | L286, L304, L392 | 3 |
| 32 | ConvertTo-UtcIso | 0 | L319, L354, L495 | 4 |

**Capability retention: PASS** — no capability is deleted in diff; every keyword is present in v1.12.

---

## 5. Step 8 — Forbidden items (added lines only)

Search scope: only lines starting with `+` (added) from `.production-validation-v112-final/v111-v112.diff`. Added-line count: **26**.

| # | Forbidden pattern | Result | Evidence |
|---|---|---|---|
| 1 | mock URL | ✅ NOT FOUND | — |
| 2 | forced success | ✅ NOT FOUND | — |
| 3 | debug bypass | ✅ NOT FOUND | — |
| 4 | test-only branch | ✅ NOT FOUND | — |
| 5 | hardcoded token (`ghp_` / `gho_` / `github_pat_`) | ✅ NOT FOUND | — |
| 6 | hardcoded test repository | ✅ NOT FOUND | — |
| 7 | skip schema | ✅ NOT FOUND | — |
| 8 | skip lock | ✅ NOT FOUND | — |
| 9 | skip commit | ✅ NOT FOUND | — |
| 10 | full SemVer parser | ✅ NOT FOUND | — |
| 11 | new API request | ✅ NOT FOUND | — |
| 12 | new review source | ⚠️ False positive | Only hit is the Changelog entry which literally contains the phrase "不扩大 review" (declaring absence); the pattern regex `新增.*review` matched "新增 PS7 版本检查 … 不扩大 review". No functional review source is added. |
| 13 | lock rewrite | ✅ NOT FOUND | — |

**Forbidden item check: PASS** — 12/13 clean; 1 false positive (Changelog metadata), not a code-level violation.

---

## 6. Cross-check: heartbeat code unmodified

The Step 3 heartbeat code block (v1.12 L447-L455) is byte-identical to v1.11 L437-L444. Diff hunk 4 begins at `$backupDir` (v1.11 L445 / v1.12 L456) and never touches the heartbeat. `grep` on `step=3;beat=` shows a single occurrence in v1.12 at L454 (identical to v1.11 L443).

**Heartbeat preservation: PASS**.

---

## 7. Final verdict

| Gate | Result |
|---|---|
| Diff hunks match expected logical changes | ✅ PASS (8 logical, 6 U3 hunks / 7 U0 hunks, all accounted) |
| No unexpected hunks | ✅ PASS |
| `git diff --check` whitespace | ✅ PASS (no trailing whitespace / space-before-tab / patch-left-trailing) |
| P3 6 fatal paths classified 不修改 | ✅ PASS |
| Capability retention (32 items) | ✅ PASS |
| Forbidden items (13 checks) | ✅ PASS (1 false positive, no functional violation) |
| Heartbeat code unchanged | ✅ PASS |

STATUS=SUCCESS
