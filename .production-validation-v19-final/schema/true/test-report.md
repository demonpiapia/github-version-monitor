# Schema Test: input='true'

## Expected
- PARSE_ERROR

## Actual
- PARSE_ERROR: True
- FETCH_COMPLETE: False
- md unchanged: True
- lock released: True

## SHA256
- before: 40E9F4117E3DA3D674CF7E06E585DCE1FE20749D4686FBBCC9E27497714753E3

- after: 40E9F4117E3DA3D674CF7E06E585DCE1FE20749D4686FBBCC9E27497714753E3


## Stdout
```
PARSE_ERROR|状态文件 schema 校验失败，本轮终止，不写回主 md。
  问题：第 6 列 flag 非法：| 1 | [test](https://github.com/test/test-repo/releases) | v1.0.0 | 2026-01-01 | 1.0.0 | true |

```

## Verdict
PASS
