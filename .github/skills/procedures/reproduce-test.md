# Procedure: Reproduce Test

## Purpose

Write a failing test that captures the bug BEFORE investigating root cause or writing code. This test becomes a permanent regression guard. **Bugs only** — skip for features and tasks.

## Inputs

- `ticket.md` populated with bug details
- Affected service(s) identified from classify step

## Prerequisites

- Environment running with the bug present
- Service test commands known (from `workspace.yaml` → `services[].test`)

## Procedure

### 1. Identify Test Location

| Bug Location | Test Type | Where |
|-------------|-----------|-------|
| Business logic, data transformation | Unit test | `<service>/tests/` (service repo) |
| API endpoint returns wrong status/data | API test | `tests/api/test_<svc>.py` (workspace) |
| UI rendering, user interaction | Browser test | `tests/browser/test_<feature>.py` (workspace) |
| Service-to-service communication | Contract test | `tests/contract/test_<contract>.py` (workspace) |
| Full workflow across services | E2E test | `tests/e2e/test_<workflow>.py` (workspace) |

Rule of thumb: unit test if the bug is in one function; API test if it's in how the service responds; browser test only if visual or interaction-based.

### 2. Search for Existing Tests

```bash
grep -rn "<keyword>" <service>/tests/ --include="*.py"
grep -rn "<keyword>" tests/ --include="*.py"
```

Use keywords from the ticket: error messages, endpoint paths, function names, status codes.

| Existing test? | Fails? | Action |
|----------------|--------|--------|
| Yes | Yes | Document it, skip to investigate |
| Yes | No | Test doesn't cover this path — write a more specific one |
| No | — | Write new test (step 3) |

### 3. Write the Failing Test

**Name**: `test_<ticket_key_lowercase>_<short_description>`

**Structure** (Arrange / Act / Assert):

```python
class TestPROJ1234:
    """Regression test for PROJ-1234: <bug summary>."""

    def test_proj_1234_description(self):
        """<Expected behavior> — currently <actual behavior>."""
        # Arrange: set up conditions that trigger the bug
        # Act: call the function where the bug occurs
        result = function_under_test(input_data)
        # Assert: CORRECT behavior — fails with bug present
        assert result == expected_value
```

**Checklist**:
- Test name includes ticket key
- Docstring describes bug and expected behavior
- Asserts **correct** behavior (fails now, passes after fix)
- No dependency on other tests (runs in isolation)
- Uses markers (`@pytest.mark.api`, `@pytest.mark.browser`, etc.)

### 4. Run the Test — Confirm It Fails

```bash
# Service-level
cd <service> && <service.test> <path>::<test_name> -v

# Workspace-level
cd tests && pytest <type>/test_<file>.py::<Class>::<test_name> -v
```

**Expected: test FAILS.** This proves the test targets the bug.

If the test passes instead:

| Reason | Action |
|--------|--------|
| Doesn't hit bug path | Adjust input to trigger the exact failure condition |
| Environment-specific | Add environment setup, or document as env-only |
| Timing/race condition | Add concurrency (asyncio.gather, threading) |
| Data-dependent | Use fixtures matching production data shape |
| Still can't reproduce after 3 attempts | **TRIGGER: Missing repro** |

### 5. Document

Record in `investigation.md` under Reproduce Test section:

```markdown
## Reproduce Test
- **Test file**: <path>
- **Test name**: test_proj_1234_description
- **Test type**: Unit / API / Browser / Contract / E2E
- **Status**: FAILING (bug confirmed)
- **Run command**: <exact command>
- **Failure output**:
  <assertion error or key lines>
```

## Required Outputs

- One failing test file committed or staged
- Reproduce test details recorded in `investigation.md`

## Success Criteria

- Test runs and **fails** on current code
- Test asserts the **correct** behavior (will pass after fix)
- Test runs in isolation without other test dependencies
- Test name includes the ticket key for traceability

## Failure Modes

| Failure | Recovery |
|---------|----------|
| Can't identify test location | Check `workspace.yaml` for service test commands; ask user which service |
| No existing test framework | Write test in `tests/api/` at workspace level |
| Test passes (can't reproduce) | Try 3 approaches; after 3 → **TRIGGER: Missing repro** |
| Test framework not installed | Install from `tests/requirements.txt` or service deps |
