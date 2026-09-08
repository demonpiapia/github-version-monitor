# Schema Test: input='No_mixed'

## Expected
- PARSE_ERROR

## Actual
- PARSE_ERROR: True
- FETCH_COMPLETE: False
- md unchanged: True
- lock released: True

## SHA256
- before: 7EB74ABD39FAEC36777C4DC4DC9436BD38BF5DB54C8A1E86AA649F4C0930ABD0

- after: 7EB74ABD39FAEC36777C4DC4DC9436BD38BF5DB54C8A1E86AA649F4C0930ABD0


## Stdout
```
PARSE_ERROR|状态文件 schema 校验失败，本轮终止，不写回主 md。
  问题：第 6 列 flag 非法：| 1 | [test](https://github.com/test/test-repo/releases) | v1.0.0 | 2026-01-01 | 1.0.0 | No |

```

## Verdict
PASS
