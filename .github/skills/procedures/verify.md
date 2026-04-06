# Procedure: Verify

> Run tests and capture evidence. Quality gate before pushing.

---

## Pre-Requisites

- Code committed locally, service-level tests passed (from implement)
- This runs workspace-level and cross-service verification

---

## Step 0: Re-run Reproduce Test (Bugs Only)

**First thing**: re-run the reproduce test from the reproduce-test procedure.

```bash
# Same command used in reproduce-test step
<service.test> <test_path>::<test_name>
```

| Result | Action |
|--------|--------|
| ✅ PASSES | Fix works — continue to Step 1 |
| ❌ FAILS | Fix incomplete — go back to implement |

This is non-negotiable for bugs. If the reproduce test still fails, the fix is not done.

---

## Step 1: Workspace Tests

Run each modified service's test suite. If integration test targets exist, run those too.

Use the typed test targets based on what changed:

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
| Same test that passed before now fails | Environment issue → `make env-check`, retry |
| Related to your change, test expectation wrong | Update test, document in changes.md |
| Related to your change, side effect | Go back to implement, fix |
| Unrelated | `git stash && <test> && git stash pop` — if fails on main too, it's pre-existing → note, proceed |
| Flaky (2/3 pass) | Note as flaky, proceed |
| After 2 full retry cycles | **TRIGGER: Test failures** |

---

## Step 2: Cross-Service Verification

If changes span services:

- **API contract**: verify caller sends the expected format after your change
- **Env vars**: verify variable is set, check all services that read it
- **Database**: verify migration runs cleanly, other services' queries unbroken

---

## Step 3: UI Verification

When change affects frontend or API called by UI:

- **With Playwright MCP**: navigate → interact → screenshot → check console errors
- **Without**: note "manual verification required — <what to check>"
- **No UI impact**: skip, note "N/A"

---

## Step 4: Write test-results.md

```markdown
## Test Results: <TICKET>

### Reproduce Test (Bugs)
| Test | Command | Before Fix | After Fix |
|------|---------|-----------|-----------|
| test_proj_1234_desc | pytest path::name -v | ❌ FAIL | ✅ PASS |

### Service Tests
| Service | Command | Result |
|---------|---------|--------|

### Workspace Tests
| Suite | Command | Result |
|-------|---------|--------|
| smoke | make test-smoke | ✅ / ❌ |
| api | make test-api | ✅ / ❌ |

### Pre-existing Issues
| Test | Service | Status | On main? |

### API Verification
<curl output if endpoint changed>

### UI Verification
✅ / ⏭️ N/A / 🔧 Manual required
```

### Retry policy

First failure → fix if obvious, retry. Second failure on same test → investigate. Third → **TRIGGER**.
