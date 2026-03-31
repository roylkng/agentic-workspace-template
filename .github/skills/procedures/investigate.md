# Procedure: Investigate

> Reproduce the issue and find root cause across multiple service repos.

---

## Pre-Requisites

- `ticket.md` in artifact directory
- `workspace.yaml` lists services
- `docs/service-map.md` if available

---

## Step 1: Verify Environment

```bash
make env-check
```

If unhealthy → fix first. Do NOT investigate on a broken environment.

---

## Step 2: Map the Request Path

Trace the full path before touching code:

1. Read `docs/service-map.md` for the dependency graph (or scan services manually)
2. Identify user-facing entry point
3. Trace downstream calls (HTTP? Queue? Shared DB?)
4. Write path in `investigation.md`: `frontend → API Gateway → Chat Service → PostgreSQL`

**If no docs exist**, find service calls with:
```bash
grep -rn "requests\.\|httpx\.\|fetch(\|axios\.\|http\.Get" services/<svc>/src/
grep -rn "SERVICE.*URL\|SERVICE.*HOST\|localhost:[0-9]" services/<svc>/src/
```

---

## Step 3: Collect Error Signals

### 3a. Logs
```bash
make logs SVC=<entry-service>
make logs SVC=<downstream-service>
```

Key signals: stack traces (innermost frame = root cause), HTTP 5xx between services, 401/403 (auth), timestamps for cross-service correlation.

### 3b. Reproduce

| Bug Type | How |
|----------|-----|
| API | `curl` with auth headers, capture response + status |
| UI | Playwright MCP if available, otherwise describe steps |
| Background job | Check queue consumer logs, dead-letter queues |
| Intermittent | Run 10x, check for race conditions or data-dependence |

After 3 failed attempts → check: environment-specific? needs special data? timing-dependent? code-inspectable? If none → **TRIGGER: Missing repro**.

### 3c. Recent Changes
```bash
cd services/<affected-service>
git log --oneline -20
git log --since="1 week ago" --stat
```

---

## Step 4: Root Cause Analysis

Choose strategy based on situation:

| Strategy | When | Key Action |
|----------|------|-----------|
| **Follow Stack Trace** | Have exception | Read innermost frame → trace bad input upstream via callers/config |
| **Follow Data** | Wrong output, no crash | Walk backward from output through each transformation until data diverges |
| **Cross-Service** | Error spans services | Compare client code (what's sent) vs handler code (what's expected) — check URL, body shape, auth, content-type |
| **Config Mismatch** | Code looks correct | `grep -rn "os\.getenv\|process\.env\|os\.Getenv"` → check actual values in .env/ConfigMaps/Helm |
| **Dependency** | Error in library call | Check version, known bugs, transitive dep conflicts |

---

## Step 5: Verify Root Cause

Must pass ALL four tests:

| Test | Question |
|------|----------|
| Mechanism | Can you explain the exact code path from input to failure? |
| Specificity | Can you name file, line, and what's wrong? |
| Reproduction | Does your explanation predict when the bug occurs and when it doesn't? |
| Completeness | Does it account for ALL symptoms? |

Any test fails → try a different strategy from Step 4.

---

## Step 6: Write investigation.md

```markdown
## Root Cause
<Service, file, line, mechanism — be specific>

## Evidence
### Error Logs
<relevant snippet with timestamps>
### Code Path
1. `services/<svc>/src/file.ts:15` — <what>
2. `services/<svc>/src/handler.py:42` — <where it fails and why>
### Reproduction
<curl command/steps with output>

## Affected Services
| Service | File | Issue |
|---------|------|-------|
| <svc> | src/path/file.ext:line | <specific issue> |

## Impact
<What's broken for users? Scope?>
```
