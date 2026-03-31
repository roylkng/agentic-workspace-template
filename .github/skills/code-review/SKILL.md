# Skill: Automated Code Review

> Review pull requests for correctness, security, multi-repo consistency, and conventions.
>
> **Input**: PR URL, PR number, or auto-invoked after PR creation in Dev Agent.
> **Output**: Structured review comments via MCP or presented as markdown.

---

## Entry

```
"review PR #42"
"review https://github.com/org/repo/pull/42"
Auto-invoked after Step 9 of Dev Agent
```

---

## Step 1: Fetch PR Context

### With GitHub MCP

1. Get PR metadata: `mcp_github_pull_request_read` (method: "get")
   - Extract: title, body, author, base branch, head branch, changed file count
2. Get the diff: `mcp_github_pull_request_read` (method: "get_diff")
3. Get changed files list: `mcp_github_pull_request_read` (method: "list_files")

### Without GitHub MCP

Ask user to provide:
- The diff (or point to the branch)
- Which service repo this PR is in

### For each changed file

Read the **full file** (not just the diff hunks). You need surrounding context to judge:
- Whether the change is consistent with the file's patterns
- Whether adjacent code has the same issue
- Whether the change breaks callers

Also read the linked ticket/issue if referenced in the PR title/body — you need to know what this PR is supposed to fix.

---

## Step 2: Correctness Review

For each changed file, check:

| Check | What to Look For | Common Misses |
|-------|-----------------|---------------|
| **Logic matches intent** | Does the code do what the PR description says? | Partial fix — fixes one path but misses another |
| **Edge cases** | Null/empty inputs, boundary values, type mismatches | Missing null check after adding a new code path |
| **Error paths** | Are exceptions caught? Do error handlers make sense? | Catch-all that swallows the real error |
| **Return types** | Do return values match callers' expectations? | Returning `None` where caller expects a value |
| **Side effects** | Does this change affect anything outside its function? | Mutating shared state, changing global config |
| **Concurrency** | Is shared state accessed safely? | Race condition in async code, missing locks |

### How to check edge cases specifically

1. Read the function's inputs — what types can they be?
2. For each input: what happens if it's null? Empty string? Empty list? 0? Negative?
3. Does the function validate inputs, or does it assume they're valid?
4. If the function is called from multiple places, check: do all callers pass valid inputs?

---

## Step 3: Security Review

| Check | What to Grep For | Risk |
|-------|-----------------|------|
| **Hardcoded secrets** | `password =`, `secret =`, `api_key =`, `token =` followed by string literal | 🔴 Critical |
| **SQL injection** | String concatenation in SQL queries (`f"SELECT...{var}"`, `"SELECT..." + var`) | 🔴 Critical |
| **Input validation** | User-provided values used without validation in queries, file paths, commands | 🔴 Critical |
| **Auth checks** | New endpoints missing auth middleware | 🔴 Critical |
| **Path traversal** | User input in file paths without sanitization (`os.path.join(base, user_input)`) | 🟡 Warning |
| **CORS** | Wildcard origins (`Access-Control-Allow-Origin: *`) on authenticated endpoints | 🟡 Warning |
| **Logging secrets** | Log statements that might output tokens, passwords, PII | 🟡 Warning |
| **Dependency security** | New dependencies with known vulnerabilities | 🟡 Warning |

If you find a 🔴 Critical issue → this alone is grounds for REQUEST_CHANGES.

---

## Step 4: Multi-Repo Consistency Check

If this PR is part of a multi-service change:

| Check | How to Verify |
|-------|--------------|
| **API contract match** | Read the endpoint handler in the target service. Does the request shape match what the caller sends? |
| **Schema backward compatibility** | If a field was renamed/removed, do all consumers handle the old format too? |
| **Queue contract match** | Compare the message shape published by the producer with what the consumer expects |
| **Env var consistency** | If a new env var was added, is it set in all environments? (ConfigMaps, .env, CI) |
| **Version compatibility** | If shared libraries were updated in one service, do other services use a compatible version? |

Read the related PRs (linked in the PR description) to check cross-service consistency.

---

## Step 5: Testing Review

| Check | Expected |
|-------|----------|
| **New code has tests** | At least one test covers the new/changed code path |
| **Tests cover the ticket** | A test that would have **caught** this bug before the fix |
| **No test exclusions** | No `@skip`, `xit`, `.skip()` without a comment explaining why |
| **Integration tests updated** | If API contract changed, integration tests should reflect the new shape |
| **Test quality** | Tests assert behavior, not implementation (no mocking internal details) |

If the change has **no tests** and it's not trivial (config change, typo fix):
- Flag as 🟡 Warning: "No tests for new code path. Add a test for [specific scenario]"

---

## Step 6: Convention Review

| Check | How to Judge |
|-------|-------------|
| **Code style** | Does the new code match the file's existing style? (indentation, naming, patterns) |
| **No drive-by refactors** | Changes should be scoped to the ticket. Renamed variables, reformatted code, or reorganized imports in unchanged code = drive-by |
| **Commit messages** | Follow the project's format? (e.g., `fix(PROJ-1234): description`) |
| **Documentation** | If a public API changed, is the documentation updated? |

---

## Step 7: Generate Review Comments

For each issue found, create a structured comment:

```
**File**: `src/middleware/auth.py`
**Line**: 42
**Severity**: 🔴 Critical / 🟡 Warning / 🔵 Suggestion
**Category**: Security / Correctness / Testing / Convention
**Issue**: <specific issue>
**Suggestion**: <how to fix>
```

### Severity guidelines

| Severity | When | Blocks merge? |
|----------|------|--------------|
| 🔴 **Critical** | Security vulnerability, data loss, crash, wrong behavior | Yes — REQUEST_CHANGES |
| 🟡 **Warning** | Missing test, edge case not handled, potential issue | Soft block — REQUEST_CHANGES if >2 warnings |
| 🔵 **Suggestion** | Style, naming, minor improvement | No — COMMENT only |

### Sort order

Present Critical first, then Warning, then Suggestion. If there are no Critical or Warning issues, the review is likely an APPROVE.

---

## Step 8: Submit Review

### With GitHub MCP

1. Create pending review: `mcp_github_pull_request_review_write` (method: "create")
2. Add comments to specific lines: `mcp_github_add_comment_to_pending_review`
3. Submit with verdict:
   - Any 🔴 Critical → `REQUEST_CHANGES`
   - >2 🟡 Warnings → `REQUEST_CHANGES`
   - Only 🔵 Suggestions → `APPROVE` with comments
   - No issues → `APPROVE`

### Without GitHub MCP

Present the full review as markdown. The user can copy comments to the PR manually.

```markdown
## Code Review: <PR title>

**Verdict**: APPROVE / REQUEST_CHANGES / COMMENT
**Issues**: X critical, Y warnings, Z suggestions

### Critical
<issue details>

### Warnings
<issue details>

### Suggestions
<issue details>
```

---

## Step 9: Address Review Comments (if requested)

When asked to fix review comments:

1. Read each comment — understand what the reviewer wants
2. For each change:
   - If it's a valid concern → fix it
   - If you disagree → explain why (don't silently ignore)
3. Commit: `fix(<TICKET>): address review — <summary>`
4. Push to the same branch
5. Re-request review

**Max cycles**: 2 rounds of review fixes (configurable in `workspace.yaml`). If still not approved after 2 rounds → escalate to user.

**Verdict logic**: Any 🔴 → REQUEST_CHANGES. >2 🟡 → REQUEST_CHANGES. Only 🔵 → APPROVE with comments. None → APPROVE.
