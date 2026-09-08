# Phase 6.2 Schema Regression Test Report

## Purpose
验证 SKILL-v1.9 状态文件 schema 校验（SKILL L79）：
- flag 列必须严格小写 yes 或 
o
- 非法输入触发 PARSE_ERROR| 输出
- PARSE_ERROR 时主 md 不变 + 锁释放

## Schema Rule
`powershell
if([5]-cnotmatch '^(yes|no)$'){+=('第 6 列 flag 非法：{0}'-f );continue}
`

## Results

| Input | Expected | PARSE_ERROR | FETCH_COMPLETE | md unchanged | lock released | Verdict |
|---|---|---|---|---|---|---|
| $(@{Input=yes; DirName=yes; Expected=valid; HasParseError=False; HasFetchComplete=True; ShaBefore=223EB215764C9C718C41216BB11E914CDFA699B3782D291B31CB10C5BD5B98DC; ShaAfter=223EB215764C9C718C41216BB11E914CDFA699B3782D291B31CB10C5BD5B98DC; MdUnchanged=True; LockReleased=False; Verdict=PASS; Detail=}.Input) | valid | False | True | True | False | PASS |
| $(@{Input=no; DirName=no; Expected=valid; HasParseError=False; HasFetchComplete=True; ShaBefore=0930842046DC34763619C321AF179C063510A10C228FBE812B38CCF141FD3138; ShaAfter=0930842046DC34763619C321AF179C063510A10C228FBE812B38CCF141FD3138; MdUnchanged=True; LockReleased=False; Verdict=PASS; Detail=}.Input) | valid | False | True | True | False | PASS |
| $(@{Input=YES; DirName=YES_upper; Expected=PARSE_ERROR; HasParseError=True; HasFetchComplete=False; ShaBefore=0FB9ECEBC661582510D2330D83BEACAA1815A00032BBFBBB94030051D11E99AF; ShaAfter=0FB9ECEBC661582510D2330D83BEACAA1815A00032BBFBBB94030051D11E99AF; MdUnchanged=True; LockReleased=True; Verdict=PASS; Detail=}.Input) | PARSE_ERROR | True | False | True | True | PASS |
| $(@{Input=Yes; DirName=Yes_mixed1; Expected=PARSE_ERROR; HasParseError=True; HasFetchComplete=False; ShaBefore=73628556F1C1EACB0411F6BDB652B76004715D4B3E7B443D6F3691F2E53B8866; ShaAfter=73628556F1C1EACB0411F6BDB652B76004715D4B3E7B443D6F3691F2E53B8866; MdUnchanged=True; LockReleased=True; Verdict=PASS; Detail=}.Input) | PARSE_ERROR | True | False | True | True | PASS |
| $(@{Input=yEs; DirName=yEs_mixed2; Expected=PARSE_ERROR; HasParseError=True; HasFetchComplete=False; ShaBefore=C03BD4FA3EC8A04ADE5AD35E8ADCC5A33FDC10F56B094E4B05209831310A789C; ShaAfter=C03BD4FA3EC8A04ADE5AD35E8ADCC5A33FDC10F56B094E4B05209831310A789C; MdUnchanged=True; LockReleased=True; Verdict=PASS; Detail=}.Input) | PARSE_ERROR | True | False | True | True | PASS |
| $(@{Input=NO; DirName=NO_upper; Expected=PARSE_ERROR; HasParseError=True; HasFetchComplete=False; ShaBefore=2AD07A81898FF4CD76D6C6A977653BD94907047B9A2C2FE8E44CC422164725DA; ShaAfter=2AD07A81898FF4CD76D6C6A977653BD94907047B9A2C2FE8E44CC422164725DA; MdUnchanged=True; LockReleased=True; Verdict=PASS; Detail=}.Input) | PARSE_ERROR | True | False | True | True | PASS |
| $(@{Input=No; DirName=No_mixed; Expected=PARSE_ERROR; HasParseError=True; HasFetchComplete=False; ShaBefore=7EB74ABD39FAEC36777C4DC4DC9436BD38BF5DB54C8A1E86AA649F4C0930ABD0; ShaAfter=7EB74ABD39FAEC36777C4DC4DC9436BD38BF5DB54C8A1E86AA649F4C0930ABD0; MdUnchanged=True; LockReleased=True; Verdict=PASS; Detail=}.Input) | PARSE_ERROR | True | False | True | True | PASS |
| $(@{Input=pending; DirName=pending; Expected=PARSE_ERROR; HasParseError=True; HasFetchComplete=False; ShaBefore=8C3D067174166C3144BD2C00638BFA1AC783266FEB8E579160B3568C7982C587; ShaAfter=8C3D067174166C3144BD2C00638BFA1AC783266FEB8E579160B3568C7982C587; MdUnchanged=True; LockReleased=True; Verdict=PASS; Detail=}.Input) | PARSE_ERROR | True | False | True | True | PASS |
| $(@{Input=true; DirName=true; Expected=PARSE_ERROR; HasParseError=True; HasFetchComplete=False; ShaBefore=40E9F4117E3DA3D674CF7E06E585DCE1FE20749D4686FBBCC9E27497714753E3; ShaAfter=40E9F4117E3DA3D674CF7E06E585DCE1FE20749D4686FBBCC9E27497714753E3; MdUnchanged=True; LockReleased=True; Verdict=PASS; Detail=}.Input) | PARSE_ERROR | True | False | True | True | PASS |
## Summary
- PASS: 9 / 9
- FAIL: 0 / 9

## Valid Inputs (yes/no)
- yes (lowercase): valid → FETCH_COMPLETE
- 
o (lowercase): valid → FETCH_COMPLETE

## Invalid Inputs (7)
- YES, Yes, yEs, NO, No, pending, 	rue: all trigger PARSE_ERROR
- md unchanged: all PASS
- lock released: all PASS
