# Skill: Development Agent

> End-to-end ticket completion. Input: ticket key. Gates: Plan Approval + PR Creation.
> Orchestrates procedures: reproduce-test, investigate, plan, implement, verify, changeset, pr-compose.

---

## Entry

```
→ Invoking dev-agent with ticket key PROJ-1234
```

**Do NOT search for tickets here.** If the user said a ticket key, use it. If they described work without a key, invoke [Ticketflow](../ticketflow/SKILL.md) first.

---

## Gates

| Gate | When | Purpose |
|------|------|---------|
| **Plan Approval** | After reproduce test + investigation, before coding | Prevents wasted work on wrong assumptions |
| **PR Creation** | After all tests pass (including reproduce test), before opening PR | Prevents unreviewed code from hitting repos |

These are non-negotiable. Even if the fix is one line, both gates apply.

---

## Risk Triggers

See copilot-instructions.md § The 2-Gate Model for the full list. If triggered, **stop and ask** before continuing. If none fire → continue silently.

Thresholds are in `workspace.yaml` under `risk_triggers`.

---

## Step 1: Initialize

**Silent. No output to user.**

### 1a. Read workspace context
1. Read `workspace.yaml` — services, environment formula, conventions, gates
2. Read `docs/service-map.md` if it exists — service interactions and dependency graph
3. If no docs exist and >2 services present, flag for workspace-understand after this ticket

### 1b. Create artifact directory
```bash
make artifact-init TICKET=<KEY>
```

### 1c. Fetch ticket details

Try MCP tools in this order:

| Tool | When to Use |
|------|-------------|
| `mcp_atlassian_getJiraIssue` | Jira ticket (PROJ-1234 format) |
| `mcp_github_issue_read` | GitHub issue (#123 format or full URL) |
| No MCP available | Ask user to paste ticket details |

Write fetched content to `artifacts/<KEY>/<timestamp>/ticket.md`.

### 1d. Capture baseline
```bash
make snapshot TICKET=<KEY>
```

**Error handling**: If `make artifact-init` fails, the Makefile may not exist or the artifacts dir is misconfigured. Check `ls Makefile` and `ls artifacts/`. If missing, create the directory manually.

---

## Step 2: Classify & Scope

**Silent.**

1. From ticket details, determine: **Bug** / **Feature** / **Task**
2. Read service list from `workspace.yaml`
3. Identify which services are likely affected:
   - Search ticket text for service names, file paths, endpoint URLs, error messages
   - If ticket mentions a URL path → grep services for that route handler
   - If ticket mentions an error message → grep services for that string
   - If ticket is vague → read `docs/service-map.md` to identify the entry service, then trace

**Check**: If >1 service identified → **TRIGGER: Multi-service change** — ask user to confirm scope.

---

## Step 3: Reproduce Test (Bugs Only)

> **Test-first for bugs**: Before RCA or code changes, write a test that captures the bug.
> For features/tasks, skip to Step 4.

**Silent unless trigger fires.**

Execute the **[reproduce-test procedure](../procedures/reproduce-test.md)** in full:

1. Search for existing tests covering the bug area
2. If existing test already fails → document it, skip to Step 4
3. Determine test type: unit (service-level) or API/browser/contract (workspace-level)
4. Write a test that asserts **correct** behavior (so it fails with the bug present)
5. Run the test — **confirm it fails**
6. Document test details in `investigation.md` § Reproduce Test

**Test naming**: `test_<ticket_key_lowercase>_<description>`

**Where to put it:**
- Business logic bug → service repo `services/<svc>/tests/`
- API endpoint bug → workspace `tests/api/test_<svc>.py`
- UI bug → workspace `tests/browser/test_<feature>.py`
- Cross-service bug → workspace `tests/contract/test_<contract>.py`

**Check risk triggers:**
- Cannot write test AND cannot reproduce after 3 attempts → **TRIGGER: Missing repro**

**Output**: Failing test (committed or staged). Test info recorded for plan gate.

---

## Step 4: Investigate

**Silent unless trigger fires.**

Execute the **[investigate procedure](../procedures/investigate.md)** in full:

1. Verify environment health (`make env-check`)
2. Map the request path
3. Use the failing test output (assertion message, stack trace) to guide investigation
4. Root cause analysis (using the 5 strategies from the procedure)
5. Verify root cause (mechanism + specificity + reproduction + completeness tests)
6. Write `investigation.md`

**If investigation takes >15 minutes of work** (many services to search, complex call chains): write a brief progress note in `changes.md` as you go, so the artifact has context if you need to pause.

---

## Step 5: Plan Gate [HUMAN APPROVAL REQUIRED]

**Present to user (10-15 lines max):**

```
## Plan: <TICKET>

**Root Cause**: <one sentence from investigation.md>
**Reproduce Test**: <test_name> — ❌ FAILING (bugs only)
**Fix**: <one sentence — what will change>
**Risk**: Low / Medium / High — <one sentence why>

**Changes**:
- <service-1>: `<file>` — <what changes>
- <service-2>: `<file>` — <what changes>

**Tests**: <what will be run to verify>
**Rollback**: <how to revert>

Proceed? [yes / no / modify]
```

| User Response | Action |
|---------------|--------|
| "yes" / "proceed" / approval | Move to Step 6 |
| "no" / "stop" | Stop. Branches not created. Artifacts preserved |
| "modify" / feedback | Revise the plan based on feedback, re-present |
| Asks questions | Answer from investigation context, re-present plan |

The plan presented here is a summary. The full plan is written to `plan.md` per the **[plan procedure](../procedures/plan.md)** before presenting.

---

## Step 6: Implement

**Silent unless trigger fires.**

Execute the **[implement procedure](../procedures/implement.md)** in full:

1. Create branches in each affected service
2. Implement changes per approved plan (reading files before editing, matching conventions)
3. Run service-level lint and tests
4. Handle failures per the procedure's decision trees
5. Commit with conventional format
6. Update `changes.md`

**Triggers that can fire here:**
- Schema files changed → **Schema migration**
- Lock files changed → **Dependency bump**
- LOC >threshold → **Large diff**
- Changing files not in the plan → **Scope drift**

---

## Step 7: Verify

**Silent unless trigger fires.**

Execute the **[verify procedure](../procedures/verify.md)** in full:

1. **Re-run the reproduce test first** — confirm it now PASSES (bugs only)
2. Run workspace-level tests (each modified service's test suite)
3. Cross-service verification (API contracts, env vars, DB if applicable)
4. UI verification (if applicable + Playwright MCP available)
5. Capture evidence → `test-results.md`

**If the reproduce test still fails → the fix is incomplete. Go back to Step 6.**

**If other tests fail after 2 retry cycles → TRIGGER: Test failures.**

---

## Step 8: Push & Track

**Silent.**

Execute the **[changeset procedure](../procedures/changeset.md)** in full:

1. Push service branches to remote
2. Capture post-change snapshot
3. Generate submodule diff
4. Stage workspace submodule pointers

Then run artifact validation:
```bash
make validate TICKET=<KEY>
```

If validation finds missing artifacts, fill them before proceeding.

---

## Step 9: PR Gate [HUMAN APPROVAL REQUIRED]

**Present to user:**

```
## PR Ready: <TICKET>

**Summary**: <one sentence — what was fixed/built>
**Tests**: ✅ all passing

**Service PRs to create**:
| Service | Branch | Changes |
|---------|--------|---------|
| backend-api | fix/PROJ-1234 | +45 -12 (2 files) |
| frontend | fix/PROJ-1234 | +8 -3 (1 file) |

**Submodule changes**:
| Service | Before | After |
|---------|--------|-------|
| backend-api | abc1234 | def5678 |
| frontend | 111aaa | 222bbb |

Open PR(s)? [yes / no]
```

| User Response | Action |
|---------------|--------|
| "yes" | Create PRs via MCP (Step 10), then auto-review |
| "no" | Stop. Branches exist on remote but no PRs created. User can create manually |
| Asks for changes | Go back to Step 6 with the new instructions |

---

## Step 10: Create PRs & Auto-Review

Execute the **[pr-compose procedure](../procedures/pr-compose.md)**:

1. Generate `pr-body.md` from artifacts
2. Create PR(s) via GitHub MCP (or present body for manual creation)
3. Record PR numbers in `changes.md`

Then, if GitHub MCP is available, invoke **[code-review skill](../code-review/SKILL.md)**:

1. Request automated review
2. Present review summary to user
3. If changes requested: offer to address them (max 2 cycles)

---

## Error Recovery

| Error | At Step | Recovery |
|-------|---------|---------|
| Can't fetch ticket from MCP | 1 | Ask user to paste ticket details |
| Can't reproduce bug in test | 3 | Try different test type/setup. After 3 attempts → TRIGGER: Missing repro |
| Environment unhealthy | 4 | Show env-check output, ask user to fix, then retry |
| Can't find affected service | 2 | Show service list, ask user which service |
| Git conflicts on branch creation | 6 | `git pull --rebase origin main`, retry |
| Lint fails on your code | 6 | Fix lint errors (they're part of implementation) |
| Pre-existing lint errors | 6 | Note in changes.md, don't fix |
| Reproduce test still fails | 7 | Fix incomplete — go back to Step 6 |
| Tests fail on your code | 6-7 | Fix the implementation. If you can't, trigger test-failures |
| Push rejected | 8 | Check permissions. If auth issue, ask user |
| PR creation fails via MCP | 10 | Present pr-body.md for manual creation |

---

Artifact structure: see copilot-instructions.md § Artifact Structure.
