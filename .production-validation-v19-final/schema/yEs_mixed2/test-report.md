# Schema Test: input='yEs_mixed2'

## Expected
- PARSE_ERROR

## Actual
- PARSE_ERROR: True
- FETCH_COMPLETE: False
- md unchanged: True
- lock released: True

## SHA256
- before: C03BD4FA3EC8A04ADE5AD35E8ADCC5A33FDC10F56B094E4B05209831310A789C

- after: C03BD4FA3EC8A04ADE5AD35E8ADCC5A33FDC10F56B094E4B05209831310A789C


## Stdout
```
PARSE_ERROR|状态文件 schema 校验失败，本轮终止，不写回主 md。
  问题：第 6 列 flag 非法：| 1 | [test](https://github.com/test/test-repo/releases) | v1.0.0 | 2026-01-01 | 1.0.0 | yEs |

```

## Verdict
PASS
