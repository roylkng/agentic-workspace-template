# Procedure: PR Compose

> Generate PR description from artifacts, create via MCP.

---

## Step 1: Read Artifacts

From `artifacts/<TICKET>/<timestamp>/`: ticket.md (problem), investigation.md (root cause), plan.md (risk level), changes.md (what changed), test-results.md (evidence), submodule-diff.md (SHA changes).

---

## Step 2: Generate pr-body.md

```markdown
## <TICKET>: <summary>

### Problem
<2-3 sentences from ticket.md>

### Root Cause
<1-2 sentences — name file + mechanism>

### Solution
<what changed and why — the diff shows how>

### Changes
| Service | File | Change |

### Testing
- [x] Service tests: <result>
- [x] Workspace tests: <result>

### Risk
**Level**: Low/Medium/High — **Rollback**: <one sentence>

### Submodule Updates
| Service | Old SHA | New SHA |

### Related PRs
<links to other service PRs>

Closes <TICKET>
```

**Rules**: Problem understandable without ticket. Root cause names file + mechanism. Solution describes intent, not implementation. Testing has actual results, not intentions. No placeholders.

---

## Step 3: Create PR

**With GitHub MCP**: `mcp_github_create_pull_request` — owner, repo, title (`fix(<TICKET>): <summary>`), body, base=main, head=fix/TICKET.

One PR per service repo. Workspace submodule PR after service PRs.

**Without MCP**: Present pr-body.md as markdown for manual creation.

---

## Step 4: Record PR Numbers

Update `changes.md` with PR URLs/numbers.
