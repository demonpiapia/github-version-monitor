## T39 - Commit Success + Lock Release Failure

### Fixture
- microsoft/vscode with localVer=1.0.0

- COMMIT_OK output: True
- RUNTIME_ERROR output: True
- RUN_STATUS|failed|: True
- No RUN_STATUS|success|: True
- Main md was updated by commit: True
- Foreign lock retained (not deleted): True
- Lock still has foreign PID 999998: True

### Result: **PASS**
