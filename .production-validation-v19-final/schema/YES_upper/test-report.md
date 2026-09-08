# Schema Test: input='YES_upper'

## Expected
- PARSE_ERROR

## Actual
- PARSE_ERROR: True
- FETCH_COMPLETE: False
- md unchanged: True
- lock released: True

## SHA256
- before: 0FB9ECEBC661582510D2330D83BEACAA1815A00032BBFBBB94030051D11E99AF

- after: 0FB9ECEBC661582510D2330D83BEACAA1815A00032BBFBBB94030051D11E99AF


## Stdout
```
PARSE_ERROR|状态文件 schema 校验失败，本轮终止，不写回主 md。
  问题：第 6 列 flag 非法：| 1 | [test](https://github.com/test/test-repo/releases) | v1.0.0 | 2026-01-01 | 1.0.0 | YES |

```

## Verdict
PASS
