# Procedure: Implement

## Purpose

Write code changes per the approved plan. Follow the plan exactly — deviations trigger scope drift.

## Inputs

- `plan.md` approved at Plan Gate
- Affected services and files identified

## Prerequisites

- Plan approved by human
- Branches not yet created
- Service repos accessible (submodules initialized)

## Procedure

### 1. Create Branches

Per affected service:
```bash
cd <service>
git fetch origin && git checkout main && git pull origin main
git checkout -b <prefix>/<TICKET>
```

Prefix: `fix/` (bug), `feature/` (feature), `chore/` (task).

If branch exists (retry): `git checkout fix/<TICKET> && git rebase main`

### 2. Implement Changes

**Before writing code, read the target file.** Match:

| Convention | Rule |
|-----------|------|
| Indentation | Match the file (tabs/spaces, count) |
| Naming | Match the file (camelCase, snake_case, etc.) |
| Error handling | Match the file's pattern |
| Imports | Match grouping and ordering |
| Logging | Same logger, same level for similar operations |

**Do NOT**: add type annotations to untyped files, change indentation style, reorganize imports you didn't touch, add comments to code you didn't write, refactor adjacent code.

### Scope triggers

| Situation | Action |
|-----------|--------|
| Fix is in a different file than planned | **TRIGGER: Scope drift** |
| LOC much larger than planned | **TRIGGER: Scope drift** |
| Found another bug | Note in `changes.md`, don't fix |
| Needs new dependency | **TRIGGER: Dependency bump** |
| Needs schema change | **TRIGGER: Schema migration** |

### 3. Run Service Checks

```bash
cd <service>
<service.lint>    # from workspace.yaml
<service.test>    # from workspace.yaml
```

**Lint fails on your code** → fix it. **Pre-existing lint errors** → note, don't fix.

| Test situation | Action |
|----------------|--------|
| Your new test fails | Fix your implementation |
| Existing test breaks from your change | Check if fix is correct or has side effect |
| Unrelated test fails | Verify on `main` — if pre-existing, note and proceed |
| Flaky (passes 2/3) | Note as flaky, proceed |

### 4. Commit

```bash
git add -A && git commit -m "<type>(<TICKET>): <description>"
```

Types: `fix`, `feat`, `chore`, `test`, `docs`. Imperative mood, one line.

### 5. Update changes.md

```markdown
## Changes: <TICKET>
### <service>
| File | Change | LOC |
|------|--------|-----|
**Lint**: pass/fail  **Tests**: N passed
**Commit**: `fix(PROJ-1234): description`
```

## Required Outputs

- Code committed on feature/fix branches in each affected service
- `changes.md` updated with files, lint, test results, commit message

## Success Criteria

- Changes match the approved plan (same files, same scope)
- Service-level lint passes on changed code
- Service-level tests pass
- Commit message follows conventional format with ticket key

## Failure Modes

| Failure | Recovery |
|---------|----------|
| Branch already exists | `git checkout <branch> && git rebase main` |
| Lint fails on your code | Fix lint errors (part of implementation) |
| Tests fail on your code | Fix implementation; if you can't after 2 attempts → TRIGGER: Test failures |
| Scope drift detected | Stop, present the deviation, ask user to approve expanded scope |
| Git conflicts | `git pull --rebase origin main`, resolve, continue |
