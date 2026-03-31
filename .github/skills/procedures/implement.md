# Procedure: Implement

> Write code changes per approved plan. Follow the plan exactly — deviations are scope drift triggers.

---

## Pre-Requisites

- `plan.md` approved at Plan Gate
- Branches not yet created

---

## Step 1: Create Branches

Per affected service:
```bash
cd services/<service>
git fetch origin && git checkout main && git pull origin main
git checkout -b <prefix>/<TICKET>
```

Prefix: `fix/` (bug), `feature/` (feature), `chore/` (task).

If branch exists (retry): `git checkout fix/<TICKET> && git rebase main`

---

## Step 2: Implement Changes

**Before writing code, read the target file.** Match:

| Convention | Rule |
|-----------|------|
| Indentation | Match the file (tabs/spaces, count) |
| Naming | Match the file (camelCase, snake_case, etc.) |
| Error handling | Match the file's pattern (throw, return error, Result type) |
| Imports | Match grouping and ordering |
| Logging | Same logger, same level for similar operations |

**Do NOT**: add type annotations to untyped files, change indentation style, reorganize imports you didn't touch, add comments to code you didn't write, refactor adjacent code.

### Scope triggers

| Situation | Action |
|-----------|--------|
| Fix is in a different file than planned | **TRIGGER: Scope Drift** |
| LOC much larger than planned | **TRIGGER: Scope Drift** |
| Found another bug | Note in `changes.md`, don't fix |
| Needs new dependency | **TRIGGER: Dependency bump** |
| Needs schema change | **TRIGGER: Schema migration** |

---

## Step 3: Run Service Checks

```bash
cd services/<service>
<service.lint>    # e.g., ruff check . --fix / npm run lint / cargo clippy
<service.test>    # e.g., pytest tests/ / npm test / cargo test
```

**Lint fails on your code** → fix it. **Pre-existing lint errors** → note, don't fix.

**Test failures:**

| Situation | Action |
|-----------|--------|
| Your new test fails | Fix your implementation |
| Existing test breaks from your change | Check if fix is correct or has side effect |
| Unrelated test fails | Verify on `main` — if pre-existing, note and proceed |
| Flaky (passes 2/3) | Note as flaky, proceed |

---

## Step 4: Commit

```bash
git add -A && git commit -m "<type>(<TICKET>): <description>"
```

Types: `fix`, `feat`, `chore`, `test`, `docs`. Imperative mood, one line.

---

## Step 5: Update changes.md

```markdown
## Changes: <TICKET>
### <service>
| File | Change | LOC |
|------|--------|-----|
**Lint**: ✅ / ❌  **Tests**: ✅ N passed / ❌
**Commit**: `fix(PROJ-1234): description`
```
