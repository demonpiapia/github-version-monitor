# Schema Test: input='NO_upper'

## Expected
- PARSE_ERROR

## Actual
- PARSE_ERROR: True
- FETCH_COMPLETE: False
- md unchanged: True
- lock released: True

## SHA256
- before: 2AD07A81898FF4CD76D6C6A977653BD94907047B9A2C2FE8E44CC422164725DA

- after: 2AD07A81898FF4CD76D6C6A977653BD94907047B9A2C2FE8E44CC422164725DA


## Stdout
```
PARSE_ERROR|状态文件 schema 校验失败，本轮终止，不写回主 md。
  问题：第 6 列 flag 非法：| 1 | [test](https://github.com/test/test-repo/releases) | v1.0.0 | 2026-01-01 | 1.0.0 | NO |

```

## Verdict
PASS
