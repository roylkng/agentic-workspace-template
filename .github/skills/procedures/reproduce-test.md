# Procedure: Reproduce Test

> Write a failing test that captures the bug BEFORE investigating root cause or writing code.
> This test becomes a permanent regression test in the suite.
> **Bugs only** — skip this procedure for features and tasks.

---

## Pre-Requisites

- `ticket.md` populated with bug details
- Affected service(s) identified from classify step
- Environment running with the bug present

---

## Why Test First?

1. **Proves the bug exists** — the test fails on current code
2. **Guides investigation** — assertion failures and stack traces pinpoint root cause
3. **Proves the fix works** — the test passes after implementation
4. **Prevents regression** — the test stays in the suite forever
5. **Scopes the fix** — if the test passes, the fix is done

---

## Step 1: Identify Test Location

Determine where the test belongs based on bug type:

| Bug Location | Test Type | Where |
|-------------|-----------|-------|
| Business logic, data transformation | **Unit test** | `services/<svc>/tests/` (service repo) |
| API endpoint returns wrong status/data | **API test** | `tests/api/test_<svc>.py` (workspace) |
| UI rendering, user interaction | **Browser test** | `tests/browser/test_<feature>.py` (workspace) |
| Service-to-service communication | **Contract test** | `tests/contract/test_<contract>.py` (workspace) |
| Full workflow across services | **E2E test** | `tests/e2e/test_<workflow>.py` (workspace) |

**Rule of thumb**: Unit test if the bug is in one function. API/integration test if the bug is in how the service responds. Browser test only if the bug is visual or interaction-based.

Read `workspace.yaml` → `services[].test` for the service's test command.

---

## Step 2: Search for Existing Tests

Check if a test already covers the bug area:

```bash
# Service-level tests
cd services/<svc>
grep -rn "<keyword>" tests/ --include="*.py" 2>/dev/null
grep -rn "<keyword>" test/ --include="*.py" 2>/dev/null
grep -rn "<keyword>" **/*test* --include="*.py" 2>/dev/null

# Workspace-level tests
grep -rn "<keyword>" tests/ --include="*.py" 2>/dev/null
```

Use keywords from the ticket: error messages, endpoint paths, function names, status codes.

| Existing Test? | Does it fail? | Action |
|---------------|---------------|--------|
| Yes | Yes | Document it, skip to investigate |
| Yes | No (passes) | Test doesn't cover this path — write a more specific test |
| No | — | Write a new test (Step 3) |

---

## Step 3: Write the Failing Test

### Naming Convention

```
test_<ticket_key_lowercase>_<short_description>
```

Example: `test_proj_1234_invalid_source_returns_400`

### Unit Test (Service-Level)

```python
import pytest

class TestPROJ1234:
    """Regression test for PROJ-1234: <bug summary>."""

    def test_proj_1234_<description>(self):
        """
        <Ticket summary> — <expected behavior>.

        Bug: <one-sentence root cause hypothesis>.
        """
        # Arrange: set up conditions that trigger the bug
        ...

        # Act: call the function where the bug occurs
        result = function_under_test(input_data)

        # Assert: expected (correct) behavior — FAILS with bug present
        assert result == expected_value
```

### API Test (Workspace-Level)

```python
import pytest
import httpx

@pytest.mark.api
class TestPROJ1234:
    """Regression test for PROJ-1234: <bug summary>."""

    def test_proj_1234_<description>(self, base_url, auth_headers):
        """<Expected behavior> — currently returns <actual behavior>."""
        response = httpx.post(
            f"{base_url}/api/v1/endpoint",
            json={"trigger": "payload"},
            headers=auth_headers,
        )
        # Assert correct behavior — FAILS with bug present
        assert response.status_code == 200
        assert "expected_field" in response.json()
```

### Browser Test (Workspace-Level)

```python
import pytest
from playwright.sync_api import Page, expect

@pytest.mark.browser
class TestPROJ1234:
    """Regression test for PROJ-1234: <UI bug summary>."""

    def test_proj_1234_<description>(self, page: Page):
        """<Expected UI behavior>."""
        page.goto(f"{base_url}/path")
        page.click("selector")
        # Assert expected state — FAILS with bug present
        expect(page.locator("result-selector")).to_be_visible()
```

### Test Quality Checklist

- [ ] Test name includes ticket key
- [ ] Docstring describes bug and expected behavior
- [ ] Arrange/Act/Assert structure
- [ ] Asserts the **correct** behavior (so it fails now, passes after fix)
- [ ] No dependency on other tests (can run in isolation)
- [ ] Uses markers (`@pytest.mark.api`, `@pytest.mark.browser`, etc.)

---

## Step 4: Run the Test — Confirm It Fails

```bash
# Service-level
cd services/<svc>
<service.test> <test_path>::<test_name> -v

# Workspace-level
cd tests
pytest <type>/test_<file>.py::<TestClass>::<test_name> -v -m <marker>
```

### Expected: Test FAILS

This proves:
1. The test correctly targets the bug
2. The bug exists in the current code
3. You have a reproducible signal

### If the test passes

| Reason | Action |
|--------|--------|
| Test doesn't hit the bug path | Adjust test input to trigger the exact failure condition |
| Bug is environment-specific | Add environment setup to test, or document as "env-only" |
| Bug is timing/race condition | Add concurrency to the test (asyncio.gather, threading) |
| Bug is data-dependent | Use fixtures that match the production data shape |
| Still can't reproduce | **TRIGGER: Missing repro** — proceed to investigate with code inspection |

---

## Step 5: Document the Reproduce Test

Record in `investigation.md` under Reproduce Test section:

```markdown
## Reproduce Test

- **Test file**: `<path to test file>`
- **Test name**: `test_proj_1234_description`
- **Test type**: Unit / API / Browser / Contract / E2E
- **Status**: ❌ FAILING (bug confirmed)
- **Run command**: `<exact command to run>`
- **Failure output**:
  ```
  <assertion error or key failure lines>
  ```
```

---

## After This Procedure

1. **Investigate** — use the test's failure output (assertion message, stack trace) to pinpoint root cause
2. **Implement** — the code fix should make this test pass
3. **Verify** — explicitly re-run this test as the first verification:
   ```bash
   # Confirm the reproduce test now passes
   <same command from Step 4>
   ```

The test stays in the codebase permanently as a regression guard.
