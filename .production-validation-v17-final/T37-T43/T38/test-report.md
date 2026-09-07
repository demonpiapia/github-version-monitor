## T38 - Review Failure

### Fixture
- microsoft/vscode with localVer=some-weird-string (triggers incomparable -> review=true)

- REVIEW_WRITE_ERROR output: True
- No COMMIT_OK: True
- No RUN_STATUS|success|: True
- Main md SHA256 unchanged: True (original=D22600D91085CA6DDF7887EED54934AECA6F8C658EC634001544F15E378A0A4B, updated=D22600D91085CA6DDF7887EED54934AECA6F8C658EC634001544F15E378A0A4B)
- Lock released (by Step 4 error path): True
- result.review.tmp cleaned up: True

### Result: **PASS**
