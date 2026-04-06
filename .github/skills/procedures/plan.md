# Procedure: Plan

> Create implementation plan from investigation results. This is what the human approves at Plan Gate.

---

## Pre-Requisites

- `investigation.md` with verified root cause
- Affected services identified with specific files

---

## Step 1: Define Changes Per Service

For each service: which files, what changes, estimated LOC, dependencies on other services.

- Start from root cause file → trace callers up, handlers down
- Check for other callers: `grep -rn "function_name\|endpoint_path" services/<svc>/src/`
- Fix root cause only. Note other bugs as separate tickets — don't fix them here

---

## Step 2: Assess Risk

| Level | Criteria |
|-------|----------|
| **Low** | Single service, <50 LOC, no API/schema changes |
| **Medium** | 50-200 LOC or API contract change |
| **High** | Multi-service, schema migration, >200 LOC, auth flow change |

### Risk checklist (note YES items in plan)

- Changes API contract? → list all callers that must update
- Changes DB schema? → describe migration + rollback
- Changes auth/permissions? → describe before vs after
- Changes shared config? → list all services that read it
- Adds/removes dependency? → name it and why
- Could break currently-working requests? → describe blast radius

### Multi-service ordering

Deploy RECEIVERS before SENDERS — avoid a window where sender sends something receiver doesn't understand.

---

## Step 3: Test Strategy

Name specific tests:

| Type | What | Service |
|------|------|---------|
| Reproduce test | `test_proj_1234_description` — currently failing, should pass after fix | backend-api |
| Existing unit | `test_auth_middleware.py` — should still pass | backend-api |
| Integration | `make test-smoke`, `make test-api` | workspace |
| Contract | `make test-contract` — if cross-service interfaces change | workspace |

If no tests exist for affected code → write one. Untested fixes aren't verifiable.

For bugs: the reproduce test written in Step 3 is the primary verification.

---

## Step 4: Rollback

| Change Type | Rollback |
|-------------|----------|
| Code-only | `git revert <sha>` |
| DB migration | Provide down migration (or state it's irreversible) |
| Config change | Provide previous value |
| Multi-service | Reverse of deploy order |

---

## Step 5: Write plan.md

```markdown
## Plan: <TICKET>

**Type**: Bug fix / Feature / Task
**Risk**: Low / Medium / High — <reason>

## Root Cause (from investigation)
<one sentence>

## Changes
### <service>
| File | Change | LOC |
|------|--------|-----|

## Deploy Order
1. <receiver first> 2. <sender second>

## Tests
| Test | Service | Purpose |

## Rollback
<how to revert>

## Risks & Notes
<edge cases, limitations>
```
