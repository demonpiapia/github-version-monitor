# Schema Test: input='pending'

## Expected
- PARSE_ERROR

## Actual
- PARSE_ERROR: True
- FETCH_COMPLETE: False
- md unchanged: True
- lock released: True

## SHA256
- before: 8C3D067174166C3144BD2C00638BFA1AC783266FEB8E579160B3568C7982C587

- after: 8C3D067174166C3144BD2C00638BFA1AC783266FEB8E579160B3568C7982C587


## Stdout
```
PARSE_ERROR|状态文件 schema 校验失败，本轮终止，不写回主 md。
  问题：第 6 列 flag 非法：| 1 | [test](https://github.com/test/test-repo/releases) | v1.0.0 | 2026-01-01 | 1.0.0 | pending |

```

## Verdict
PASS
