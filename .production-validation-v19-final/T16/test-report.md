# T16 Test Report

## Description
dateSuspicious

## Scenario
MOCK_SCENARIO=normal

## Expected
- queryStatus: ok- review: True
- dateSuspicious: True

## Actual Results
- queryStatus: ok
- cmp: lt
- review: True
- reviewReasons: date_suspicious
- gitVer: v2.0.0
- gitDate: 2026-09-07
- flag: yes
- prevFlag: no
- latest: v2.0.0
- publishedUtc: 09/07/2026 12:00:00
- versionJump: False
- dateSuspicious: True
- isFlip: True
- isNew: True
- error: 
- apiOk/apiErr: 1/0
- lockReleased: False

## Verdict
PASS
