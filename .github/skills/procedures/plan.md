# Procedure: Plan

## Purpose

Create an implementation plan from investigation results. This is what the human approves at Plan Gate.

## Inputs

- `investigation.md` with verified root cause
- Affected services identified with specific files
- Reproduce test name and status (bugs)

## Prerequisites

- Root cause passes all 4 verification tests
- Artifact directory exists with `ticket.md` and `investigation.md`

## Procedure

### 1. Define Changes Per Service

For each service: which files, what changes, estimated LOC, dependencies.

- Start from root cause file → trace callers up, handlers down
- Check for other callers: `grep -rn "function_name\|endpoint_path" <service>/src/`
- Fix root cause only — note other bugs as separate tickets, don't fix them here

### 2. Assess Risk

| Level | Criteria |
|-------|----------|
| **Low** | Single service, <50 LOC, no API/schema changes |
| **Medium** | 50–200 LOC or API contract change |
| **High** | Multi-service, schema migration, >200 LOC, auth flow change |

Risk checklist (note YES items in plan):
- Changes API contract? → list all callers that must update
- Changes DB schema? → describe migration + rollback
- Changes auth/permissions? → describe before vs after
- Changes shared config? → list all services that read it
- Adds/removes dependency? → name it and why
- Could break currently-working requests? → describe blast radius

Multi-service ordering: deploy RECEIVERS before SENDERS.

### 3. Test Strategy

| Type | What | Service |
|------|------|---------|
| Reproduce test | `test_proj_1234_desc` — currently failing, should pass after fix | backend-api |
| Existing unit | `test_auth_middleware.py` — should still pass | backend-api |
| Integration | `make test-smoke`, `make test-api` | workspace |
| Contract | `make test-contract` — if cross-service interfaces change | workspace |

If no tests exist for affected code → write one. Untested fixes aren't verifiable.

### 4. Rollback

| Change Type | Rollback |
|-------------|----------|
| Code-only | `git revert <sha>` |
| DB migration | Provide down migration (or state irreversible) |
| Config change | Provide previous value |
| Multi-service | Reverse of deploy order |

### 5. Write plan.md

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

## Required Outputs

- `plan.md` written to artifact directory
- Plan summary presented to user at Plan Gate (10–15 lines max)

## Success Criteria

- Every changed file has a specific description of what changes
- Risk level justified with checklist items
- Test strategy names actual tests, not intentions
- Rollback is concrete (command or migration, not "revert the change")

## Failure Modes

| Failure | Recovery |
|---------|----------|
| Root cause too vague to plan changes | Go back to investigate; root cause needs specificity |
| Can't estimate LOC | Read the target files first to understand scope |
| Risk triggers fire (multi-service, schema, etc.) | Stop and ask user before continuing |
| User rejects plan | Revise based on feedback, re-present |
