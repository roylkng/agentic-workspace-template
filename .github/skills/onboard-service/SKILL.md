# Skill: Onboard Service

> Add service repos as git submodules. Detect language/commands. Chain to workspace-understand → generate-docs.
>
> **Trigger**: "add this repo", "clone all repos from our org", `make add-service`

---

## Entry Modes

| User Says | Mode | Action |
|-----------|------|--------|
| "add this repo: git@..." | **Single repo** | Add one submodule |
| "add all repos from our org" | **Org discovery** | Use GitHub MCP to list repos, user picks, bulk-add |
| "import from .gitmodules" | **Bulk import** | Parse .gitmodules, add each |
| "clone these repos" + list | **Multi-repo** | Add each provided URL |

---

## Step 1: Discover Repos

### Mode: Single Repo (URL provided)

User gave a URL → skip to Step 2.

### Mode: Single Repo (name only, no URL)

If only a name was provided, try to find the repo:

1. **With GitHub MCP**: `mcp_github_search_repositories` — search for the repo name
   ```
   Found 3 matches for "backend-api":
   | # | Repo | Language | Description |
   |---|------|----------|-------------|
   | 1 | org/backend-api | Python | Core API service |
   | 2 | org/backend-api-v2 | Python | New API (WIP) |
   | 3 | other-org/backend-api | Go | Unrelated |
   
   Which one? (#)
   ```
2. **Without GitHub MCP**: Ask for the full URL

### Mode: Org Discovery

1. **With GitHub MCP**: `mcp_github_search_repositories` with `org:<owner>` query
2. Present the repo list:
   ```
   Found 15 repos in org/my-platform:
   
   | # | Repo | Language | Updated | Description |
   |---|------|----------|---------|-------------|
   | 1 | backend-api | Python | 2d ago | Core API service |
   | 2 | frontend | TypeScript | 1d ago | React portal |
   | 3 | auth-service | Python | 5d ago | Authentication |
   ...
   
   Which repos to add? (numbers, "all", or comma-separated: 1,2,5)
   ```
3. **Without GitHub MCP**: Ask for URLs, one per line

### Mode: Bulk Import from .gitmodules

```bash
make import-services GITMODULES=/path/to/.gitmodules
```

Or if no Makefile available, parse manually:
```bash
grep '\[submodule' <file> | sed 's/.*"\(.*\)".*/\1/'  # get names
```

For each submodule entry, extract `path` and `url` from `git config -f <file>`.

---

## Step 2: Add as Git Submodules

For each repo:

```bash
git submodule add <REPO_URL> services/<NAME>
git submodule update --init services/<NAME>
```

**Error handling:**

| Error | Cause | Fix |
|-------|-------|-----|
| `already exists in the index` | Submodule was previously added | `git submodule update --init services/<NAME>` |
| `Permission denied` | No access to the repo | Ask user to check permissions |
| `Repository not found` | Wrong URL | Verify URL with user |
| `Cloning into... failed` | Network issue | Retry once, then ask user |

---

## Step 3: Detect Language, Framework, and Commands

For each added service, detect its stack.

### Language detection

Use the detection matrix from [workspace-understand](../workspace-understand/SKILL.md) § Step 1c (check files in order, first match wins).

### Build/test/lint command detection

**Priority** — prefer explicit config over guessing:

1. **Service's own Makefile** → `build`, `test`, `lint` targets
2. **CI config** → `.github/workflows/*.yml`, `.gitlab-ci.yml`
3. **Package manager defaults** (fallback):

| Language | Build | Test | Lint |
|----------|-------|------|------|
| Python (poetry) | `poetry install` | `poetry run pytest` | `poetry run ruff check .` |
| Python (pip) | `pip install -r requirements.txt` | `pytest` | `ruff check .` |
| Node.js | `npm install` | `npm test` | `npm run lint` |
| Go | `go build ./...` | `go test ./...` | `golangci-lint run` |
| Rust | `cargo build` | `cargo test` | `cargo clippy` |
| Java (Maven) | `mvn compile` | `mvn test` | `mvn checkstyle:check` |
| Java (Gradle) | `gradle build` | `gradle test` | `gradle check` |
| .NET | `dotnet build` | `dotnet test` | `dotnet format --check` |
| Ruby | `bundle install` | `bundle exec rspec` | `bundle exec rubocop` |

### Additional detection

| What | Where | Why |
|------|-------|-----|
| Health endpoint | Grep `/healthz`, `/health`, `/readyz` | env-health checks |
| Port | `PORT`, listen calls, Dockerfile EXPOSE | dependency graph |
| OpenAPI spec | `openapi.yaml`, `swagger.*` | rich API metadata |
| Dockerfile / Helm chart | `Dockerfile`, `Chart.yaml` | deployment info |

---

## Step 4: Update workspace.yaml

For each service, add to the `services` array:

```yaml
services:
  - name: backend-api
    path: services/backend-api
    repo: git@github.com:org/backend-api.git
    language: python
    build: "poetry install"
    test: "poetry run pytest tests/"
    lint: "poetry run ruff check ."
    # health_endpoint: "/healthz"    # if detected
    # port: 8001                     # if detected
    # namespace: "backend"           # if K8s, user fills in
```

**If workspace.yaml has `services: []`**, replace the empty array with the list of services.

**Important**: Fields that can't be detected (deploy command, K8s namespace, specific port) should be left commented out for the user to fill in — don't guess.

---

## Step 5: Chain to Understanding & Docs

After all services are added, invoke the next skills:

```
→ Services added. Running workspace-understand to map interactions...
```

1. Invoke **[workspace-understand](../workspace-understand/SKILL.md)** to scan code and map connections
2. Invoke **[generate-docs](../generate-docs/SKILL.md)** to produce documentation

This is the critical step — onboarding isn't just "clone repos," it's "clone repos and understand how they connect."

If the user said "just add the repo" without wanting full understanding, skip this step — but mention:
```
Service added. Run 'understand the workspace' when ready to map service interactions.
```

---

## Step 6: Present Summary

```markdown
## Onboarding Complete

### Services Added

| Service | Language | Framework | Build | Test |
|---------|----------|-----------|-------|------|
| backend-api | Python | FastAPI | poetry install | poetry run pytest |
| frontend | TypeScript | React | npm install | npm test |
| auth-service | Python | FastAPI | poetry install | poetry run pytest |

### workspace.yaml Updated

Services added with detected commands. Review and adjust:
- [ ] Set deploy commands
- [ ] Set K8s namespaces (if applicable)
- [ ] Set correct ports
- [ ] Verify detected test/lint commands

### Documentation Generated (if workspace-understand ran)

- docs/service-map.md — service inventory + dependency graph
- docs/api-contracts.md — endpoint catalog
- docs/infrastructure.md — databases, queues, caches
- docs/env-vars.md — environment variable mapping
- docs/conventions.md — coding patterns

### Next Steps

1. Review `workspace.yaml` — verify detected commands are correct
2. Run `make env-check` to verify environment connectivity
3. Start working: "show me open bugs" or "work on PROJ-1234"
```

---

## Error Recovery

| Error | Recovery |
|-------|---------|
| Submodule add fails (permissions) | Ask user to verify repo access |
| Language detection fails (no recognized files) | Ask user: "What language is this service?" |
| Service has no tests | Note in workspace.yaml: `test: "# no tests detected"` |
| Service Makefile has custom targets | Read the Makefile, use its commands instead of guessing |
| workspace.yaml is malformed | Read it, identify the issue, suggest fix to user |
