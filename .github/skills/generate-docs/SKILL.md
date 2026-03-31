# Skill: Generate Documentation

> **Trigger**: "generate docs", "document the architecture", auto-invoked after workspace-understand.
> **Input**: Optional scope — specific service, specific doc type, or full workspace.
> **Output**: Polished markdown files under `docs/`.

---

## Step 1: Determine Scope

| User Says | Scope |
|-----------|-------|
| "generate docs" | Full workspace — all 5 doc types |
| "document backend-api" | Single service sections across all docs |
| "update the service map" | Regenerate `docs/service-map.md` only |

---

## Step 2: Gather Source Data

**If docs/ has content** → read existing as baseline (you're updating).

**If docs/ is empty** → run workspace-understand Steps 1-6 first to discover data, then proceed.

### Sources per doc type

| Doc | Sources |
|-----|---------|
| service-map | `workspace.yaml`, entrypoints, route files, client modules, Docker/K8s configs |
| api-contracts | Route definitions, request/response models, OpenAPI specs |
| infrastructure | Docker Compose, Helm charts, K8s manifests, connection strings |
| env-vars | `.env` files, `os.environ`/`process.env` reads, ConfigMaps |
| conventions | README files, test files, linter configs, CI configs, auth middleware |

---

## Step 3: Generate Each Document

Use templates at `.github/templates/docs/` for structure. Follow these quality rules:

### docs/service-map.md

Template: `.github/templates/docs/service-map.md`

**Quality rules:**
- Every service under `services/` must appear in inventory
- Every graph connection must have a corresponding row in communication tables
- Ports must match actual config — don't guess
- Mermaid shapes: `[]` services, `[()]` databases, `{}` queues

### docs/api-contracts.md

Template: `.github/templates/docs/api-contracts.md`

**Quality rules:**
- Every endpoint found in code must appear
- Request/response shapes from code (type hints, schemas) — not guessed
- If shape unknown: "See source at `path/file.ext:line`"
- Note which services/frontends call each endpoint

### docs/infrastructure.md

Template: `.github/templates/docs/infrastructure.md`

### docs/env-vars.md

Template: `.github/templates/docs/env-vars.md`

**Quality rules:**
- Cross-service variables are most important — highlight them
- Mark required vs optional based on defaults in code
- Note secrets (helps ConfigMap vs Secret decisions)

### docs/conventions.md

Template: `.github/templates/docs/conventions.md`

---

## Step 4: Validate

| Check | Rule |
|-------|------|
| No empty sections | Every heading has content (even "None detected") |
| No placeholder text | No `<fill this in>`, no `TODO` |
| Consistent names | Same service name across all 5 docs |
| Cross-refs work | Service names in env-vars match service-map inventory |
| Mermaid valid | No unclosed brackets, proper arrows |

---

## Step 5: Present Summary

```
## Documentation Generated

| Document | Content |
|----------|---------|
| docs/service-map.md | X services, Y connections |
| docs/api-contracts.md | Z endpoints across N services |
| docs/infrastructure.md | Databases, queues, caches |
| docs/env-vars.md | M variables, K cross-service |
| docs/conventions.md | Auth, errors, testing |
```

---

## Incremental Updates

When updating existing docs:
1. Read current docs as baseline
2. Identify what changed (new service, updated endpoints, new env vars)
3. Merge — don't regenerate from scratch
4. Note what changed: "Updated: added user-service (3 endpoints, 5 env vars)"
