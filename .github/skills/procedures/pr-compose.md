# Procedure: PR Compose

## Purpose

Generate PR description from artifacts and create pull requests via MCP or for manual creation.

## Inputs

- All artifact files populated: `ticket.md`, `investigation.md`, `plan.md`, `changes.md`, `test-results.md`, `submodule-diff.md`
- Service branches pushed to remote

## Prerequisites

- All tests passing (from verify)
- Changeset procedure complete (branches pushed, diffs captured)
- PR Gate approved by human

## Procedure

### 1. Read Artifacts

From `artifacts/<TICKET>/<timestamp>/`:
- `ticket.md` → problem description
- `investigation.md` → root cause
- `plan.md` → risk level
- `changes.md` → what changed per service
- `test-results.md` → evidence
- `submodule-diff.md` → SHA changes

### 2. Generate pr-body.md

```markdown
## <TICKET>: <summary>

### Problem
<2–3 sentences from ticket.md>

### Root Cause
<1–2 sentences — name file + mechanism>

### Solution
<what changed and why — the diff shows how>

### Changes
| Service | File | Change |
|---------|------|--------|

### Testing
- [x] Reproduce test: PASS (was FAIL before fix)
- [x] Service tests: <result>
- [x] Workspace tests: <result>

### Risk
**Level**: Low / Medium / High — **Rollback**: <one sentence>

### Submodule Updates
| Service | Old SHA | New SHA |
|---------|---------|---------|

### Related PRs
<links to other service PRs>

Closes <TICKET>
```

**Rules**: Problem understandable without reading the ticket. Root cause names file + mechanism. Solution describes intent, not implementation. Testing has actual results, not intentions. No placeholders.

### 3. Create PR

**With GitHub MCP**: `mcp_github_create_pull_request` — owner, repo, title (`fix(<TICKET>): <summary>`), body, base=main, head=fix/TICKET.

One PR per service repo. Workspace submodule PR after service PRs.

**Without MCP**: Present `pr-body.md` as markdown for manual creation.

### 4. Record PR Numbers

Update `changes.md` with PR URLs/numbers for each service.

## Required Outputs

- `pr-body.md` in artifact directory
- PRs created (or body presented for manual creation)
- PR numbers recorded in `changes.md`

## Success Criteria

- PR description is self-contained (reviewer understands without reading the ticket)
- Root cause and solution are specific, not vague
- Testing section has actual results with pass/fail
- All service PRs linked to each other

## Failure Modes

| Failure | Recovery |
|---------|----------|
| GitHub MCP unavailable | Present `pr-body.md` for manual PR creation |
| PR creation fails (permissions) | Present body + instructions for manual creation |
| Missing artifact data | Go back and fill missing artifacts before composing |
| User rejects PR body | Revise based on feedback |
