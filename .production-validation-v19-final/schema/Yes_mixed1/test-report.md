# Schema Test: input='Yes_mixed1'

## Expected
- PARSE_ERROR

## Actual
- PARSE_ERROR: True
- FETCH_COMPLETE: False
- md unchanged: True
- lock released: True

## SHA256
- before: 73628556F1C1EACB0411F6BDB652B76004715D4B3E7B443D6F3691F2E53B8866

- after: 73628556F1C1EACB0411F6BDB652B76004715D4B3E7B443D6F3691F2E53B8866


## Stdout
```
PARSE_ERROR|状态文件 schema 校验失败，本轮终止，不写回主 md。
  问题：第 6 列 flag 非法：| 1 | [test](https://github.com/test/test-repo/releases) | v1.0.0 | 2026-01-01 | 1.0.0 | Yes |

```

## Verdict
PASS
