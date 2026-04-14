# Procedure: Verify

## Purpose

Run tests and capture evidence. Quality gate before pushing. For bugs, the reproduce test is the primary verification.

## Inputs

- Code committed locally, service-level tests passed (from implement)
- Reproduce test name and run command (bugs)

## Prerequisites

- Implementation complete with passing service-level checks
- Environment healthy for workspace-level tests

## Procedure

### 0. Re-run Reproduce Test (Bugs Only)

**First thing** — re-run the reproduce test from the reproduce-test procedure.

```bash
# Same command from reproduce-test step
<service.test> <test_path>::<test_name>
```

| Result | Action |
|--------|--------|
| PASSES | Fix works — continue to step 1 |
| FAILS | Fix incomplete — go back to implement |

This is non-negotiable for bugs. If the reproduce test still fails, the fix is not done.

### 1. Workspace Tests

Run each modified service's test suite plus integration tests:

```bash
make test-smoke       # Always run — basic health
make test-api         # If API endpoints changed
make test-contract    # If cross-service interfaces changed
make test-browser     # If UI affected
make test-e2e         # If full workflow affected
make test-security    # If auth/permissions changed
```

### Test failure decision

| Situation | Action |
|-----------|--------|
| Test that passed before now fails | Environment issue → `make env-check`, retry |
| Related to your change, test expectation wrong | Update test, document in `changes.md` |
| Related to your change, side effect | Go back to implement, fix |
| Unrelated | `git stash && <test> && git stash pop` — if fails on main too, pre-existing → note, proceed |
| Flaky (2/3 pass) | Note as flaky, proceed |
| After 2 full retry cycles | **TRIGGER: Test failures** |

### 2. Cross-Service Verification

If changes span services:
- **API contract**: verify caller sends expected format after your change
- **Env vars**: verify variable is set, all services that read it work
- **Database**: verify migration runs cleanly, other services' queries unbroken

### 3. UI Verification

When change affects frontend or API called by UI:
- **With Playwright MCP**: navigate → interact → screenshot → check console errors
- **Without**: note "manual verification required — <what to check>"
- **No UI impact**: skip, note "N/A"

### 4. Write test-results.md

```markdown
## Test Results: <TICKET>

### Reproduce Test (Bugs)
| Test | Command | Before Fix | After Fix |
|------|---------|-----------|-----------|
| test_proj_1234_desc | pytest path::name -v | FAIL | PASS |

### Workspace Tests
| Suite | Command | Result |
|-------|---------|--------|
| smoke | make test-smoke | pass/fail |
| api | make test-api | pass/fail |

### Pre-existing Issues
| Test | Service | Status | On main? |

### UI Verification
N/A / Manual required / Verified with screenshots
```

## Required Outputs

- `test-results.md` with actual results (not intentions)
- Reproduce test confirmed passing (bugs)
- Screenshots in `screenshots/` if UI verification done

## Success Criteria

- Reproduce test passes (bugs) — the primary signal
- All workspace-level test suites pass (or failures documented as pre-existing)
- Cross-service verification complete if multi-repo change
- Evidence captured with actual output, not placeholders

## Failure Modes

| Failure | Recovery |
|---------|----------|
| Reproduce test still fails | Fix incomplete — go back to implement |
| Environment unhealthy | `make env-check`, fix environment, retry tests |
| Unrelated test fails | Verify on `main`; if pre-existing, document and proceed |
| Flaky tests | Note as flaky with pass rate (e.g., 2/3); proceed |
| After 2 full retry cycles on same failure | **TRIGGER: Test failures** — escalate |
