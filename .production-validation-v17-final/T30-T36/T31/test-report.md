# T31 — Heartbeat

**Focus:** Verify the lock file contains `pid`, `start`, `step`, `beat` and that `step` changes 1→2→3→4 across step heartbeats.

## Scenario
Single pwsh process (`t31-heartbeat.ps1`) executes the SKILL Step 1 lock creation, then Steps 2–4 heartbeats (each with `FileShare::None` exclusive rewrite), then Step 5's `LastWriteTime` refresh + ownership-checked release.

## Expected
- Lock fields `pid=`, `start=`, `step=`, `beat=` all present at every step.
- `step` transitions 1→2→3→4.
- `pid` matches current process at every step.
- Step 5 does NOT rewrite the step field (only `LastWriteTime`); step remains 4 pre-release.
- Ownership check passes; lock file deleted after release.

## Result: PASS

## Evidence
- Step1: `pid=2652 step=1` allFields=True pidMatch=True stepMatch=True
- Step2: `pid=2652 step=2` allFields=True pidMatch=True stepMatch=True
- Step3: `pid=2652 step=3` allFields=True pidMatch=True stepMatch=True
- Step4: `pid=2652 step=4` allFields=True pidMatch=True stepMatch=True
- Step5-pre-release: `pid=2652 step=4` allFields=True pidMatch=True stepMatch=True
- Step5-release: lock released (deleted)
- Step5-verify: lock file deleted after release
- OVERALL=PASS

## Files
- `stdout.txt` — full step-by-step output with raw lock contents
