# Skill: Ticketflow

> Discover and select work items from natural language queries.
> Adapts to Jira, GitHub Issues, or Linear based on available MCP tools.
> **Handoff**: Selected ticket → Dev Agent workflow.

---

## Entry Points

Users express ticket queries in natural language:

```
"bugs assigned to me"
"P1 bugs with tag auth"
"work on my highest priority bug"
"tickets assigned to me"
"what's blocking the sprint?"
"open tasks in backend-api"
"PROJ-1234"                     ← direct ticket key, skip search
```

---

## Step 1: Check for Direct Ticket Key

**Before doing any search**, check if the user provided a ticket key:

- Jira pattern: `[A-Z]+-\d+` (e.g., PROJ-1234)
- GitHub pattern: `#\d+` or a full GitHub URL
- If the user said "work on PROJ-1234" → skip to Step 6: Handoff immediately

---

## Step 2: Parse Intent

| Intent | Signal Words | Behavior |
|--------|-------------|----------|
| **List only** | "show", "list", "what are", "find", "any" | Show results, stop |
| **Work on one** | "work on", "fix", "pick", "start", "grab" | Show → select → handoff to dev-agent |
| **Auto-pick** | "highest priority", "oldest", "latest", "next" | Apply sort rule → handoff to dev-agent |

**If ambiguous** (e.g., "bugs this week"): Default to **list only**. It's safer to show results than to assume the user wants to start working.

---

## Step 3: Detect Ticketing Provider

Try MCP tools in this order (first available wins):

1. `mcp_atlassian_searchJiraIssuesUsingJql` → **Jira (full JQL)**
2. `mcp_github_list_issues` / `mcp_github_search_issues` → **GitHub Issues**
4. None → ask user for ticket key directly

If `workspace.yaml` has `ticketing.provider` → prefer that provider.

---

## Step 4: Build Query

### Jira (Atlassian MCP) — Full JQL

The project prefix comes from `workspace.yaml` → `project.ticket_prefix`.

**Base query**: `project = <PREFIX> AND `

**Add clauses based on user words:**

| User Says | JQL Clause |
|-----------|------------|
| "bugs" | `issuetype = Bug` |
| "tasks" | `issuetype = Task` |
| "stories", "features" | `issuetype = Story` |
| "assigned to me", "my" | `assignee = currentUser()` |
| "unassigned" | `assignee IS EMPTY` |
| "created today" | `created >= startOfDay()` |
| "this week" | `created >= startOfWeek()` |
| "this sprint", "current sprint" | `sprint IN openSprints()` |
| "P1", "critical", "blocker" | `priority IN (Highest, Blocker)` |
| "P2", "high" | `priority = High` |
| "P3", "medium" | `priority = Medium` |
| "open" | `status NOT IN (Done, Closed, Resolved)` |
| "in progress" | `status = "In Progress"` |
| "blocked", "blocking" | `status = Blocked` (or `labels = blocked`) |
| "label X" | `labels = "X"` |
| "component X" | `component = "X"` |
| "<service-name>" | `labels = "<service-name>"` OR `component = "<service-name>"` |

**Combine with AND. Add sort:**
- Default: `ORDER BY priority ASC, updated DESC`
- "oldest": `ORDER BY created ASC`
- "latest", "newest": `ORDER BY created DESC`
- "recently updated": `ORDER BY updated DESC`

**Example built query:**
```
project = PROJ AND issuetype = Bug AND assignee = currentUser() AND status NOT IN (Done, Closed, Resolved) ORDER BY priority ASC, updated DESC
```

Call: `mcp_atlassian_searchJiraIssuesUsingJql` with this JQL.

### GitHub Issues

| User Says | GitHub Search Query |
|-----------|-------------------|
| "bugs" | `is:issue is:open label:bug` |
| "assigned to me" | `is:issue is:open assignee:@me` |
| "P1", "critical" | `is:issue is:open label:priority-critical,priority-p1` |
| "open" | `is:issue is:open` |
| "<label>" | `is:issue is:open label:<label>` |

Call: `mcp_github_search_issues` or `mcp_github_list_issues` with the repo owner/name from `workspace.yaml`.

---

## Step 5: Present Results

### Always show the query

```
**Provider**: Jira (Atlassian MCP)
**Query**: `project = PROJ AND issuetype = Bug AND assignee = currentUser() ORDER BY priority ASC, updated DESC`
```

This gives the user transparency and the ability to suggest query refinements.

### Results table (max 10 rows)

| # | Key | Type | Priority | Status | Updated | Summary |
|---|-----|------|----------|--------|---------|---------|
| 1 | PROJ-1234 | Bug | High | Open | 2h ago | Auth timeout on login page |
| 2 | PROJ-1235 | Bug | Medium | In Progress | 1d ago | Dashboard charts not loading |
| 3 | PROJ-1236 | Bug | Medium | Open | 3d ago | Export fails for large datasets |

### Edge Cases

**> 10 results:**

Show the first 10, then summarize the rest:
```
Showing 10 of 47 results.
By priority: 3 Critical, 12 High, 20 Medium, 12 Low
By status: 28 Open, 15 In Progress, 4 Blocked

Narrow down? (e.g., "just critical", "assigned to me", "label:auth")
```

**0 results:**

Don't just say "no results." Suggest ONE relaxed query by removing the most restrictive filter:
```
No results for: project = PROJ AND issuetype = Bug AND assignee = currentUser() AND priority = Highest

Try removing the priority filter?
  → project = PROJ AND issuetype = Bug AND assignee = currentUser()
```

**MCP tool error:**
```
Jira query failed: <error message>
Try providing a ticket key directly: PROJ-1234
```

---

## Step 6: Selection & Handoff

### List-only intent → Stop

Show results. Done. Don't offer to start working unless asked.

### Work-on-one intent → Ask for selection

```
Which ticket? (enter key or #)
```

User responds with key or number → proceed to handoff.

### Auto-pick intent → Apply the rule

| "highest priority" | Pick row #1 (already sorted by priority) |
| "oldest" | Pick the ticket with oldest `created` date |
| "latest", "newest" | Pick the ticket with newest `created` date |
| "next" | Pick the highest priority unassigned ticket |

State what rule was applied:
```
Auto-selected: PROJ-1234 (highest priority open bug assigned to you)
```

### Handoff

```
→ Invoking dev-agent with ticket PROJ-1234
```

The dev-agent skill takes over from here. Ticketflow's job is done.


