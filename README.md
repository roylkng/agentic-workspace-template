# Agentic Workspace

> A scaffold for AI-assisted software development across multi-repo enterprise projects.

**Fork this repo. Add your services as submodules. Connect your ticketing system. Let AI agents plan, implement, test, and ship your changes — with human approval at 2 gates.**

---

## The Problem

AI coding agents work great on single repos. But enterprise products are multi-repo: microservices, shared libraries, frontends, infrastructure. When a bug spans 3 services, the agent needs to:

- Understand which repos are involved
- Correlate code across service boundaries
- Track changes in each repo independently
- Run integration tests that span services
- Create linked PRs across repos

This workspace solves that.

## How It Works

```
You: "data estate service keeps crashing with connection errors"

Ticketflow: finds PROJ-5678 in Jira

Dev Agent: checks data-estate logs, connection timeouts to PostgreSQL.
           checks companion service — connects to the same database fine.
           compares db_client.py in both: data-estate uses asyncpg (aggressive SSL),
           companion uses psycopg2 (silently falls back). Same database, different drivers.

[Plan Gate] "Root cause: asyncpg defaults to SSL negotiation which fails over
            port-forward. psycopg2 falls back silently, which is why companion works.
            Fix: add connect_args={'ssl': False} in data-estate db_client.py. Proceed?"

Dev Agent: applies fix, restarts pod, verifies data-estate connects, runs tests

[PR Gate] "Tests passing. Open PR?"

Done.
```

## Quick Start

```bash
# 1. Fork this repo
git clone https://github.com/you/agentic-workspace my-platform
cd my-platform

# 2. Edit workspace.yaml with your project details

# 3. Add your service repos as submodules
git submodule add git@github.com:org/backend-api.git backend-api
git submodule add git@github.com:org/frontend.git frontend

# 4. Initialize
make init

# 5. Let the agent understand your codebase
# In VS Code with GitHub Copilot:
# "understand the workspace"

# 6. Start working
# "work on my highest priority bug"
```

## What's Included

### Skills (Execution Contracts)

Skills are organized copilot instructions with decision trees, grep patterns, error recovery, and MCP fallback chains.

| Skill | Purpose |
|-------|---------|
| **[Ticketflow](.github/skills/ticketflow/SKILL.md)** | Natural language to JQL/GitHub query, ticket selection |
| **[Dev Agent](.github/skills/dev-agent/SKILL.md)** | End-to-end: investigate, plan, implement, verify, PR |
| **[Code Review](.github/skills/code-review/SKILL.md)** | Correctness, security, conventions, test coverage |
| **[Workspace Understand](.github/skills/workspace-understand/SKILL.md)** | Map services, detect frameworks, generate dependency graph |
| **[Env Health](.github/skills/env-health/SKILL.md)** | Check environment readiness, diagnose common issues |

Plus 6 atomic procedures used by the dev agent: [investigate](.github/skills/procedures/investigate.md), [plan](.github/skills/procedures/plan.md), [implement](.github/skills/procedures/implement.md), [verify](.github/skills/procedures/verify.md), [changeset](.github/skills/procedures/changeset.md), [pr-compose](.github/skills/procedures/pr-compose.md).

### Artifact System

Every ticket gets a timestamped evidence trail:

```
artifacts/PROJ-1234/20260329-1430/
├── ticket.md              # What was requested
├── investigation.md       # Root cause analysis
├── plan.md                # Implementation plan (human-approved)
├── changes.md             # What was done
├── test-results.md        # Test evidence
├── submodules-before.json # Service SHAs before
├── submodules-after.json  # Service SHAs after
├── submodule-diff.md      # What changed across repos
└── screenshots/           # UI evidence
```

### MCP Auto-Detection

Skills check for MCP tools at runtime. No MCP is required — they enhance the workflow:

- **GitHub MCP** — enables PRs, code search, reviews
- **Atlassian MCP** — enables Jira JQL queries
- **Playwright MCP** — enables UI testing with screenshots

## Configuration

Everything in one file: `workspace.yaml`

```yaml
project:
  name: "my-platform"
  ticket_prefix: "PROJ"

services:
  - name: backend-api
    path: backend-api
    language: python
    test: "poetry run pytest tests/"

environment:
  type: kubernetes
  kubernetes:
    context: "docker-desktop"

gates:
  plan_approval: true
  pr_creation: true

risk_triggers:
  multi_service_change: true
  large_diff_threshold: 500
```

## Make Targets

```bash
# Setup
make init                    # First-time setup
make env-check               # Verify environment health

# Development (per-ticket)
make artifact-init TICKET=X  # Create artifact directory
make snapshot TICKET=X       # Capture baseline submodule SHAs
make snapshot-after TICKET=X # Capture post-change SHAs
make diff TICKET=X           # Show what changed across repos
make validate TICKET=X       # Check artifact completeness
```

## Structure

```
workspace/
├── .github/
│   ├── copilot-instructions.md    # Agent routing and rules
│   ├── AGENTS.md                  # Skill registry
│   ├── PULL_REQUEST_TEMPLATE.md   # PR template
│   ├── skills/                    # Execution contracts
│   │   ├── ticketflow/
│   │   ├── dev-agent/
│   │   ├── code-review/
│   │   ├── workspace-understand/
│   │   ├── env-health/
│   │   └── procedures/
│   └── templates/                 # Artifact templates
├── workspace.yaml                 # Single config file
├── Makefile                       # Bootstrap CLI
├── docs/                          # Workspace documentation
├── artifacts/                     # Evidence trail per ticket
├── backend-api/                   # ← git submodule
├── frontend/                      # ← git submodule
└── data-svc/                      # ← git submodule
```

## The 2-Gate Model

```
Investigate → ① PLAN GATE → Implement & Test → ② PR GATE → Ship
```

1. **Plan Gate** — "Here's what I'm going to change. Proceed?" Prevents wasted implementation.
2. **PR Gate** — "Tests pass, here's the PR. Open it?" Prevents unreviewed code.

Everything between runs autonomously. Unless a **risk trigger** fires (multi-service change, schema migration, large diff, test failures), then the agent pauses and asks.

## Multi-Repo Protocol

When a change spans repos:

1. Agent creates branches in each service repo
2. Implements and tests changes independently
3. Captures submodule diffs (before/after SHAs)
4. Creates service PRs first, then workspace PR for pointers
5. Links all PRs together

## License

MIT
