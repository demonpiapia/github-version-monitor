# Phase 2 Report — Code Extraction + Harness Tooling

**Phase**: 2 (SKILL-v1.12 Execution Plan)
**Spec**: `.exec-plan/exec-plan-v1.12-d.md` lines 556-628
**Skill under test (read-only)**: `SKILL-v1.12.md`
**Timestamp**: 2026-09-10 (Asia/Hong_Kong UTC+8)
**Status**: **completed**

---

## 0. Hard-constraint compliance

| # | Constraint | Result |
|---|-----------|--------|
| 1 | SKILL-v1.12.md SHA256 must equal `3B15C9D7B3B37ADDB185489EBE2E8B89617867787F5EB83979FF066D23B28BE9` | ✅ MATCH (Phase 2 re-verified) |
| 2 | No tests executed (Phase 3-6 forbidden) | ✅ No step*.ps1 was invoked |
| 3 | No hardcoded GITHUB_TOKEN in harnesses | ✅ All harnesses read from `$env:GITHUB_TOKEN` or pass mock token |
| 4 | No `.monitor/` directory created (root or `.production-validation-v112-final/`) | ✅ Both confirmed absent |
| 5 | No PS5.1 compat added | ✅ Not applicable |
| 6 | No `.output/` or `.GPT/` touch | ✅ Neither touched |
| 7 | UTF-8 encoding declaration on every .ps1 | ✅ All 13 lib scripts use `$PSDefaultParameterValues['*:Encoding']='UTF8'` + `[Console]::OutputEncoding=[System.Text.Encoding]::UTF8` |
| 8 | Orchestrators use single-process `&` calls | ✅ Confirmed by grep of `run-full-pipeline.ps1` / `t3-mock-harness.ps1` / `t4-write-failure-harness.ps1` / `t5-housekeeping-harness.ps1` |
| 9 | T4 lock-holder uses B1 4-arg overload `FileShare::Read` | ✅ Confirmed in `lock-holder.ps1` line 34-37 |
| 10 | T5 uses Scheme B (delete `.monitor/backups/` before step 3) | ✅ Confirmed in `t5-housekeeping-harness.ps1` line 65-70 |

---

## 1. Step 1 — Extracted scripts (5 total)

Extraction tool: `lib/extract-code.ps1` (SHA256 `C3C645F0A765BF73796247BBABA1BDE107BC72E53DDFB3C7F4225E3FACD293DB`)
Method: raw byte-slice between ```powershell fences (guarantees byte-exactness)
Source EOL: LF; Source lines: 795; Source bytes: 63322; Open fences: 5

| File | Role | Source body L-range | Bytes | SHA256 | Byte-diff |
|---|---|---|---|---|---|
| `lib/step1.ps1` | state check + PS7 + lock + backup | 167-241 | 3649 | `F8CE7D677527D54565063B6591AD2A7E6D43D908CFB0EEBD3347A841E5C2CCA0` | EMPTY |
| `lib/step2.ps1` | parse + query + state machine + stats | 251-433 | 14752 | `D623FF739BA910CB11AFA9E8454CA437B5EFB912DDD5BC7792DD746010BE6D05` | EMPTY |
| `lib/step3.ps1` | housekeeping (P2-a try/catch) | 443-467 | 1850 | `5A6D523726E46303B4A2E4181A4832868B58CDD7A061B2B8D6E529FC5F955169` | EMPTY |
| `lib/step4.ps1` | review (list + HTML diagnostic) | 489-525 | 6441 | `57CE64F8FC73E50C2B068BF9510F1DB2FED2DC64324036810713C54A3FA79A62` | EMPTY |
| `lib/step5-full.ps1` | commit + lock release + RUN_STATUS | 537-670 | 7457 | `41C8DD7285A103D66119241A5D20324E73FBE21E42BA431FD18DF5F12E3F59C9` | EMPTY |

**Extraction verdict: PASS (5/5 byte-exact)**

### 1.1 Spot-check: step1.ps1 P1-d PS7 check (excerpt lines 1-6)

```powershell
$ErrorActionPreference = 'Stop'
# PowerShell 7.x 强制检查
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Output ("RUNTIME_ERROR|PowerShell 7.x required, current: {0}" -f $PSVersionTable.PSVersion.ToString())
    return
}
```

Match: `RUNTIME_ERROR|PowerShell 7.x required` — **present at line 4** ✅

### 1.2 Spot-check: step3.ps1 P2-a housekeeping try/catch (excerpt lines 17-25)

```powershell
try {
    New-Item -ItemType Directory -Force -Path $trashDir | Out-Null
    Get-ChildItem $backupDir -Filter 'GitHub更新监测列表.backup.*.md' |
      Sort-Object Name -Descending | Select-Object -Skip 1 |
      Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-3) } |
      ForEach-Object { Move-Item $_.FullName (Join-Path $trashDir $_.Name) -Force }
} catch {
    Write-Output ("HOUSEKEEPING_WARNING|backup/trash cleanup failed: {0}" -f $_.Exception.Message)
}
```

Match: `HOUSEKEEPING_WARNING|backup/trash cleanup failed` — **present at line 24** ✅

---

## 2. Step 2 — Orchestrators + auxiliary tools

| File | Purpose | Top-level EAP=Stop line | SHA256 |
|---|---|---|---|
| `lib/run-full-pipeline.ps1` | T2 full single-process pipeline (`& step1..5`) | **8** | `8A22117B9A51D9188A7561F2BDD499D50B095E0905C4D27C256E3B174AA5B2AF` |
| `lib/t3-mock-harness.ps1` | T3 API-failure mock wrapper | **9** | `A6B82BF190F53B3201EF14FDE4BAEB5DDBD8138EB761D782A6B0FCB852C799AB` |
| `lib/t4-write-failure-harness.ps1` | T4 write-failure injection (B1 lock-holder) | **10** | `105B1C52FD88268C43A7C6D3D7F1017E30D6A1C307C2719368331E4A4B517260` |
| `lib/t5-housekeeping-harness.ps1` | T5 housekeeping failure (Scheme B) | **8** | `52DB1CD6C719A6A1FA53CB9299974941838022F34028A017E8E4BB3261D5B019` |
| `lib/create-fixture.ps1` | Test fixture generator (2 repos default: microsoft/vscode + PowerShell/PowerShell) | (aux, non-orchestrator) | `C040442EA69E4BE59D7FE21FEB20481B729CB4AFDAAF85AE24E6630BD2F29D69` |
| `lib/lock-holder.ps1` | External file-lock holder (4-arg FileShare::Read, B1) | (aux, non-orchestrator) | `12AEF14F17C2FD1745C9ECFF0D9BB83E11F7D9AD87CBAA8F48B61D95E3199778` |

**Orchestrator EAP=Stop verification: PASS (4/4 at top level)**
**Auxiliary tool parse check: PASS (both PARSE_OK=True)**

### 2.1 T4 harness design notes (B1, hardware-verified)

- Lock-holder launched via `Start-Process -WindowStyle Hidden` (in-process harness → external hold process).
- Uses 4-arg overload `[System.IO.File]::Open($target, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read)`.
- 3-arg overload rejected (would bind to `FileShare::ReadWrite` — insufficient for write-blocking).
- `FileShare::None` rejected (would refuse harness's own later reads).
- Timing: lock acquired after Step 4 completion, before Step 5 execution (F3/D9).
- OPENED_OK marker polled by harness (max 15s); OPEN_FAILED aborts test.

### 2.2 T5 harness design notes (F2 + Scheme B)

- EAP=Stop at orchestrator top-level so step3's non-terminating errors get promoted to terminating.
- Steps 1, 2 run normally; harness deletes `.monitor/backups/` between step 2 and step 3.
- Step 3's `Get-ChildItem $backupDir` raises PathNotFound → try/catch emits `HOUSEKEEPING_WARNING|`.
- Steps 4/5 proceed; expected `RUN_STATUS|success|`.

---

## 3. Step 3 — Mock library

File: `lib/mock-invoke-restmethod.ps1`
SHA256: `ED8ACE25D4B75934A23CA3947A77CBE0C0E62F2ACFBA2D81335975FD6A960CA4`

### 3.1 Mock contract table (B6 revision)

| # | Scenario | Mock return / throw | SKILL access path | Aligned? |
|---|---|---|---|---|
| 1 | `success` (normal) | `PSCustomObject{ tag_name=string, published_at=ISO string, prerelease=false, draft=false, name=tag }` | step2 L104 `$j.published_at`; L107 `$j.tag_name` | YES |
| 2 | `not_found` (404) | `Exception` with `Response` NoteProperty; `Response.StatusCode=404` | step2 L116 `$_.Exception.Response.StatusCode` → L123 `not_found` | YES |
| 3 | `server_500` | `Exception` with `Response.StatusCode=500` | step2 L126 `$code -ge 500 → server_error` | YES |
| 4 | `rate_429` | `Exception` with `StatusCode=429` + `Headers.X-RateLimit-Remaining='0'` | step2 L124 `rate_limited` | YES |
| 5 | `network` | `Exception` with `Response=$null` | step2 L128 else branch → `network_error` | YES |
| 6 | `list` (`releases?per_page=5`) | `PSCustomObject[]` with 2 items (tag_name, published_at, prerelease, draft) | step4 L7 list endpoint | YES |
| + | `metadata_incomplete`, `invalid_response`, `auth_error`, `forbidden`, `server_503` | Bonus variants | step2 L109/L112/L122/L125/L127 | YES |

### 3.2 HTML diagnostic decision (explicit, per B6)

- `Invoke-WebRequest` mocked to always return:
  - `StatusCode = 200`
  - `Content = "<html><head><title>$Uri - Mock Release Page</title></head><body>mock</body></html>"`
  - Well-formed `<title>` for step4's regex extraction.
- Rationale: avoids real network dependency for T3; deterministic review branch.
- Explicitly recorded in `lib/mock-contract-selfcheck.txt` line ~58.

### 3.3 T3 harness list-endpoint decision

- `MOCK_SCENARIO_LIST = 'list-success'` for all T3 sub-scenarios.
- Rationale: isolates the primary-latest-failure branch from any list-endpoint behavior; review path in step4 proceeds with well-formed apiList.

### 3.4 Alignment self-check

File: `lib/mock-contract-selfcheck.txt`
SHA256: `DA385D6984183454E1D1FB74C482DDC11D35591BD594327CDE70A4E76A2D9B5A`
Verdict: **PASS (all 6 scenarios + 1 HTML diagnostic decision aligned to SKILL code paths)**

---

## 4. Step 4 — Extraction manifest

File: `lib/extraction-manifest.json`
Content includes:
- Source SKILL SHA256 (expected & actual, match=true)
- 5 extracted files: role, source line ranges, SHA256, byte-diff = EMPTY
- Supporting lib files SHA256 (9 files)
- Orchestrator EAP=Stop verification (4 entries, all present=true)
- Spot-check excerpts for step1 (P1-d) and step3 (P2-a)

---

## 5. Step 5 — Phase 2 evidence

| File | Purpose |
|---|---|
| `phase2-stdout.txt` | Full stdout from all Phase 2 tool runs (extract-code, parse-check, EAP-check, SHA-verify, spot-checks) |
| `phase2-stderr.txt` | Stderr log (empty; note on early `OutputEncoding` typo) |
| `phase2-report.md` | This document |
| `phase-progress.json` | Overwritten to Phase2 status; Phase0/Phase1 recorded under `history` |

---

## 6. Final verdict

| Gate | Result |
|---|---|
| 5 step*.ps1 extracted byte-exact | ✅ PASS (5/5) |
| 4 orchestrators with top-level EAP=Stop | ✅ PASS (4/4) |
| 9 lib/*.ps1 files all parse cleanly | ✅ PASS (13/13 total) |
| step1.ps1 P1-d marker present | ✅ PASS |
| step3.ps1 P2-a marker present | ✅ PASS |
| Mock contract covers 6 scenarios + HTML decision | ✅ PASS |
| Mock contract aligned to SKILL extraction expressions | ✅ PASS |
| Extraction manifest complete (JSON, non-empty) | ✅ PASS |
| SKILL-v1.12.md SHA256 unchanged after Phase 2 | ✅ MATCH `3B15C9D7B3B37ADDB185489EBE2E8B89617867787F5EB83979FF066D23B28BE9` |
| No `.monitor/` created | ✅ Confirmed absent |
| No tests executed (Phase 2 scope) | ✅ Confirmed |

**Overall Phase 2 verdict: PASS**

STATUS=SUCCESS
