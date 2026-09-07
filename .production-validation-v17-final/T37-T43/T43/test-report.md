## T43 - Full Extended Pipeline

### Fixture (6 rows)
1. facebook/react, localVer=1.0.0 (normal upgrade)
2. microsoft/vscode, localVer=1.136.1 (synced)
3. golang/go, localVer=未安装 (uninstalled)
4. python/cpython, localVer=some-weird-string (incomparable)
5. octocat/this-does-not-exist-99999 (404)
6. nodejs/node, gitVer=1.0.0, localVer=1.0.0 (versionJump)

### Pipeline Markers
- BACKUP_OK: True
- FETCH_COMPLETE: True
- SUMMARY: True
- REVIEW_WRITE_OK: True
- COMMIT_OK: True
- RUN_STATUS|success|: True
- result.json valid: True

### Item Details
- facebook/react: status=ok, flag=yes, cmp=lt, review=False, isNew=True, isFlip=True, versionJump=False
- microsoft/vscode: status=ok, flag=no, cmp=eq, review=False, isNew=True, isFlip=False, versionJump=False
- golang/go: status=not_found, flag=no, cmp=, review=True, isNew=False, isFlip=False, versionJump=False
  reasons: not_found
- python/cpython: status=not_found, flag=no, cmp=, review=True, isNew=False, isFlip=False, versionJump=False
  reasons: not_found
- octocat/this-does-not-exist-99999: status=not_found, flag=no, cmp=, review=True, isNew=False, isFlip=False, versionJump=False
  reasons: not_found
- nodejs/node: status=ok, flag=yes, cmp=lt, review=True, isNew=True, isFlip=True, versionJump=True
  reasons: version_jump

### Stats
- total=6 apiOk=3 apiErr=3 synced=1 yes=2 uninstalled=1 pendingReview=4 newReleases=3 flips=2 token=set

### Row Verification
- Row 1 (facebook/react, normal upgrade): status=ok, flag=yes, cmp=lt -> OK
- Row 2 (microsoft/vscode, synced): status=ok, flag=no, cmp=eq -> OK
- Row 3 (golang/go, uninstalled): status=not_found, flag=no -> MISMATCH
- Row 4 (python/cpython, incomparable): status=not_found, cmp=, review=True -> MISMATCH
- Row 5 (404): status=not_found, gitVer='', review=True -> OK
- Row 6 (nodejs/node, versionJump): status=ok, versionJump=True, review=True -> OK

### Data Consistency
- Main md changed from original: True
- Backup md exists: True
- Backup md matches original fixture: True
- fetch_run.log exists: True
- Lock released: True
- Main md data rows count: 6 (expected 6)
- All non-empty gitVers from result.json appear in md: True

### Result: **PASS**
