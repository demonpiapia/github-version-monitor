## T42 - Token Set

### Fixture
- microsoft/vscode with localVer=1.0.0
- GITHUB_TOKEN set (length=93)

- result.json stats.token: 'set'
- SUMMARY line shows token=set: True
- BACKUP_OK: True
- FETCH_COMPLETE: True
- RUN_STATUS|success|: True

### Secret Leak Verification
- Token value NOT in stdout: True
- No Authorization/Bearer header in stdout: True
- No Cookie in stdout: True
- No secret token patterns (github_pat_, ghp_, etc.) in stdout: True
- No 'Bearer <token>' pattern in stdout: True

### Result: **PASS**
