# Test Report: T27

## Test ID
T27

## Description
Fixture with duplicate repo — same owner/repo (octocat/Hello-World) appears in two data rows.

## Fixture File
`T27/fixture.md` — two data rows both linking to `https://github.com/octocat/Hello-World/releases`:
```
| 1 | [test-repo](https://github.com/octocat/Hello-World/releases) | v1.0.0 | 2026-01-01 | 1.0.0 | no |
| 2 | [test-repo](https://github.com/octocat/Hello-World/releases) | v2.0.0 | 2026-02-01 | 2.0.0 | yes |
```

## Expected Result
PARSE_ERROR — parser should detect duplicate repo key

## Actual Result
PARSE_ERROR produced:
```
PARSE_ERROR|状态文件 schema 校验失败，本轮终止，不写回主 md。
  问题：repo 重复：octocat/Hello-World
```

## Verdict
**PASS** — Parser correctly detected duplicate repo `octocat/Hello-World` and produced PARSE_ERROR with descriptive message "repo 重复：octocat/Hello-World".
