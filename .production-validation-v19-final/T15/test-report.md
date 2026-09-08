# T15 Test Report

## Description
versionJump (major diff >=2)

## Scenario
MOCK_SCENARIO=normal

## Expected
- queryStatus: ok- review: True
- versionJump: True

## Actual Results
- queryStatus: ok
- cmp: lt
- review: True
- reviewReasons: version_jump
- gitVer: v2.0.0
- gitDate: 2026-09-07
- flag: yes
- prevFlag: no
- latest: v2.0.0
- publishedUtc: 09/07/2026 12:00:00
- versionJump: True
- dateSuspicious: False
- isFlip: True
- isNew: True
- error: 
- apiOk/apiErr: 1/0
- lockReleased: False

## Verdict
PASS
