## T40 - Blocked Semantics

### Scenario 1: STATE_MISSING
- STATE_MISSING output: True
- No lock file created: True
- No backup created: True
- Scenario 1 result: PASS

### Scenario 2: LOCKED
- LOCKED output: True
- No new backup created: True
- Lock file still exists (not taken over): True
- Scenario 2 result: PASS

### Result: **PASS**
