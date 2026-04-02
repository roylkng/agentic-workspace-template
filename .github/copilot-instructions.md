# Agentic Workspace — Copilot Instructions

> Multi-repo workspace managed as git submodules. Work across service repos with human approval at 2 gates.
> **Read the relevant skill file before doing anything.**

---

## Principles

- Skills (`.github/skills/`) define workflows — follow them, don't improvise
- MCP tools are your hands — fall back to terminal/user if unavailable
- `docs/` is your memory — read before investigating or implementing
- Makefile is bootstrapping only — complex logic lives in skills

---

## Routing

| User Says | Skill | File |
|-----------|-------|------|
| "bugs assigned to me", "show P1 tickets" | Ticketflow | [SKILL.md](skills/ticketflow/SKILL.md) |
| "work on PROJ-1234", "fix the auth bug" | Dev Agent | [SKILL.md](skills/dev-agent/SKILL.md) |
| "review PR #42" | Code Review | [SKILL.md](skills/code-review/SKILL.md) |
| "understand the workspace" | Workspace Understand | [SKILL.md](skills/workspace-understand/SKILL.md) |
| "check environment" | Env Health | [SKILL.md](skills/env-health/SKILL.md) |

**Ambiguous?** Ticket key or bug/feature → Dev Agent. Tickets without a key → Ticketflow. Codebase structure → Workspace Understand.

---

## The 2-Gate Model

```
Investigate → ① PLAN GATE → Implement & Test → ② PR GATE → Ship
```

Between gates: autonomous. Interrupt only on risk triggers:
- Multi-service change (>1 repo)
- Schema migration detected
- Dependency bump (lock files)
- Large diff (>500 LOC)
- Test failures after 2 retries
- Scope drift (changing something not in plan)
- Can't reproduce after 3 attempts

---

## Critical Rules

**Before investigating:**
1. Read `docs/` if it exists — service maps, conventions, etc.
2. Read `workspace.yaml` for services, test commands
3. Run `make env-check` before investigating bugs

**When writing code:**
4. Read the file before editing — match style, patterns, imports
5. No drive-by changes — only modify what the plan specifies
6. Run lint + tests from `workspace.yaml`

**When searching across services:**
7. `grep -rn` with specific patterns — don't guess
8. Follow imports and clients for real connections
9. Check Docker/K8s configs for network topology

---

## MCP Tools

Skills check for tools at runtime. No MCP is required — they enhance the workflow.

| MCP Server | Enables | Pattern |
|------------|---------|---------|
| Atlassian | Jira JQL, Confluence | `mcp_atlassian_*` |
| GitHub | PRs, code search, reviews, issues | `mcp_github_*` |
| Playwright | Browser automation, UI testing | `mcp_microsoft_pla_*` |
| Tavily | Web search | `mcp_io_github_tav_*` |

---

## Essential Commands

```bash
make init                     # Initialize workspace
make env-check                # Verify environment health
make artifact-init TICKET=X   # Create artifact dir
make snapshot TICKET=X        # Baseline SHAs
make snapshot-after TICKET=X  # Post-change SHAs
make diff TICKET=X            # Show submodule changes
make validate TICKET=X        # Check artifact completeness
```

---

## Artifact Structure

```
artifacts/<TICKET>/<timestamp>/
├── ticket.md, investigation.md, plan.md, changes.md
├── test-results.md, submodules-before.json, submodules-after.json
├── submodule-diff.md, pr-body.md, screenshots/
```

---

## Conventions

**Git**: `fix/<TICKET>` / `feature/<TICKET>` / `chore/<TICKET>`. Commit: `fix(PROJ-1234): description` (imperative). One service PR per repo, workspace PR updates pointers.

**Code**: Match existing conventions. Lint before commit. No unrelated changes.

**Artifacts**: All sections filled. Evidence required at verification. Max 2 review cycles.
