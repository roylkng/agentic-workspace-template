# Procedure: Investigate

## Purpose

Reproduce the issue and find root cause across service repos. Uses the failing reproduce test output to guide investigation.

## Inputs

- `ticket.md` in artifact directory
- Reproduce test details (bugs) — test name, failure output, stack trace
- `workspace.yaml` listing services

## Prerequisites

- Environment healthy (`make env-check` passes)
- `docs/service-map.md` read if it exists

## Procedure

### 1. Verify Environment

```bash
make env-check
```

If unhealthy → fix first. Do NOT investigate on a broken environment.

### 2. Map the Request Path

Trace the full path before touching code:

1. Read `docs/service-map.md` for the dependency graph (or scan services manually)
2. Identify user-facing entry point
3. Trace downstream calls (HTTP? Queue? Shared DB?)
4. Write path in `investigation.md`: `frontend → API Gateway → Chat Service → PostgreSQL`

If no docs exist, find service calls with:
```bash
grep -rn "requests\.\|httpx\.\|fetch(\|axios\.\|http\.Get" <service>/src/
grep -rn "SERVICE.*URL\|SERVICE.*HOST\|localhost:[0-9]" <service>/src/
```

### 3. Collect Error Signals

**Logs**: `make logs SVC=<entry-service>` and downstream services. Look for stack traces (innermost frame = root cause), HTTP 5xx between services, 401/403 (auth), timestamps for cross-service correlation.

**Reproduce**: For bugs, use the reproduce test failure output from step 3 of the dev-agent. The assertion message and stack trace pinpoint where to look.

**Recent changes**:
```bash
cd <affected-service>
git log --oneline -20
git log --since="1 week ago" --stat
```

### 4. Root Cause Analysis

Choose strategy based on situation:

| Strategy | When | Key Action |
|----------|------|-----------|
| **Follow Stack Trace** | Have exception | Read innermost frame → trace bad input upstream |
| **Follow Data** | Wrong output, no crash | Walk backward from output through each transform |
| **Cross-Service** | Error spans services | Compare client code (sent) vs handler code (expected) |
| **Config Mismatch** | Code looks correct | `grep -rn "os\.getenv\|process\.env"` → check actual values |
| **Dependency** | Error in library call | Check version, known bugs, transitive conflicts |

### 5. Verify Root Cause

Must pass ALL four tests:

| Test | Question |
|------|----------|
| Mechanism | Can you explain the exact code path from input to failure? |
| Specificity | Can you name file, line, and what's wrong? |
| Reproduction | Does your explanation predict when the bug occurs and when it doesn't? |
| Completeness | Does it account for ALL symptoms? |

Any test fails → try a different strategy from step 4.

### 6. Write investigation.md

```markdown
## Root Cause
<Service, file, line, mechanism — be specific>

## Evidence
### Error Logs
<relevant snippet with timestamps>
### Code Path
1. `<service>/src/file.ts:15` — <what>
2. `<service>/src/handler.py:42` — <where it fails and why>
### Reproduction
<curl command/steps with output>

## Affected Services
| Service | File | Issue |
|---------|------|-------|

## Impact
<What's broken for users? Scope?>
```

## Required Outputs

- `investigation.md` with verified root cause, evidence, affected services, and impact

## Success Criteria

- Root cause passes all 4 verification tests (mechanism, specificity, reproduction, completeness)
- Evidence includes actual logs/output, not speculation
- Affected services identified with specific files and line numbers

## Failure Modes

| Failure | Recovery |
|---------|----------|
| Environment is unhealthy | Show `env-check` output, ask user to fix, retry |
| Can't find affected service | Show service list from `workspace.yaml`, ask user |
| Root cause fails verification | Try a different RCA strategy from step 4 |
| Investigation exceeds 15 minutes of search | Write progress in `changes.md`, narrow scope |
| No logs or error signals | Check if logging is disabled; add temporary debug logging |
