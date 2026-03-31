# Agentic Workspace

> A scaffold for fully automated software development across multi-repo enterprise projects.

**Fork this repo. Add your services as submodules. Connect your ticketing system. Let AI agents plan, implement, test, and ship your changes, with human approval at 2 gates.**

---

## The Problem

AI coding agents work great on single repos. But enterprise products are multi-repo: microservices, shared libraries, frontends, infrastructure. When a bug spans 3 services, the agent needs to:

- Understand which repos are involved
- Correlate code across service boundaries
- Track changes in each repo independently
- Run integration tests that span services
- Create linked PRs across repos
- Not break things while doing it

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
            -- you say yes

Dev Agent: applies fix, restarts pod, verifies data-estate connects, runs tests

[PR Gate] "Tests passing. Open PR?" -- you say yes

Done. The cross-service comparison revealed in minutes what would take hours
debugging networking and PostgreSQL config in a single repo.
```

## Quick Start

```bash
# 1. Fork this repo
git clone https://github.com/you/agentic-workspace my-platform
cd my-platform

# 2. Edit workspace.yaml with your project details
#    - Project name and ticket prefix
#    - Environment formula (kubernetes / docker-compose / custom)

# 3. Add your service repos
make add-service NAME=backend-api REPO=git@github.com:org/backend-api.git
make add-service NAME=frontend REPO=git@github.com:org/frontend.git
make add-service NAME=data-svc REPO=git@github.com:org/data-svc.git

# Or import from an existing .gitmodules:
make import-services GITMODULES=/path/to/.gitmodules

# 4. Initialize
make init

# 5. Let the agent understand your codebase
# In VS Code with GitHub Copilot:
# "understand the workspace and generate documentation"

# 6. Verify
make env-check

# 7. Start working
# In VS Code with GitHub Copilot:
# "work on my highest priority bug"
```

## What's Included

### Skills (Execution Contracts)

Skills are organized copilot instructions with decision trees, specific grep patterns, error recovery tables, and MCP fallback chains. They're what make the agent actually useful across repos instead of just guessing.

| Skill | Purpose |
|-------|---------|
| **[Ticketflow](.github/skills/ticketflow/SKILL.md)** | Natural language to JQL/GitHub query, ticket selection with full MCP fallback chain |
| **[Dev Agent](.github/skills/dev-agent/SKILL.md)** | Orchestrates investigate, plan, implement, verify, PR with error recovery |
| **[Code Review](.github/skills/code-review/SKILL.md)** | Correctness, security (grep patterns per vuln type), conventions, test coverage |
| **[Workspace Understand](.github/skills/workspace-understand/SKILL.md)** | Framework-specific detection, cross-service grep patterns, Mermaid graph generation |
| **[Generate Docs](.github/skills/generate-docs/SKILL.md)** | Produces 5 living docs from codebase with quality rules and incremental updates |
| **[Onboard Service](.github/skills/onboard-service/SKILL.md)** | Language detection (14 frameworks), auto-discovers build/test/lint commands from CI configs |
| **[MCP Discovery](.github/skills/discover-mcp/SKILL.md)** | Detects available MCP servers, maps capabilities, generates graceful degradation config |
| **[Env Health](.github/skills/env-health/SKILL.md)** | Formula-specific checks, common issue diagnosis table, auto-fix guidance |

Plus 6 atomic procedures with decision trees and error recovery: [investigate](.github/skills/procedures/investigate.md), [plan](.github/skills/procedures/plan.md), [implement](.github/skills/procedures/implement.md), [verify](.github/skills/procedures/verify.md), [changeset](.github/skills/procedures/changeset.md), [pr-compose](.github/skills/procedures/pr-compose.md).

### Generated Documentation

The agent produces and maintains living docs under `docs/`:

```
docs/
├── service-map.md        # Service inventory + dependency graph (Mermaid)
├── api-contracts.md      # All API endpoints across all services
├── infrastructure.md     # Databases, queues, caches, auth providers
├── env-vars.md           # Environment variables by service + cross-refs
└── conventions.md        # Auth flow, error handling, logging, testing
```

These are **agent-consumable context**, generated by the workspace-understand and generate-docs skills. The agent reads them during development to understand how services connect.

### Environment Formulas

Adapters for your infrastructure. Choose one or define your own.

| Formula | For |
|---------|-----|
| **kubernetes** | K8s clusters (Docker Desktop, Minikube, EKS, GKE) |
| **docker-compose** | Docker Compose stacks |
| **custom** | Anything: serverless, mobile, bare metal |

### Artifact System

Every ticket gets a timestamped evidence trail:

```
artifacts/PROJ-1234/20260329-1430/
├── ticket.md              # What was requested
├── investigation.md       # Root cause analysis
├── plan.md                # Implementation plan (human-approved)
├── changes.md             # What was done + execution log
├── test-results.md        # Test evidence
├── submodules-before.json # Service SHAs before
├── submodules-after.json  # Service SHAs after
├── submodule-diff.md      # What changed across repos
└── pr-body.md             # Generated PR description
```

### MCP Auto-Configuration

The workspace doesn't hardcode tool dependencies. It discovers what you have:

- **GitHub MCP** -- enables PRs + code search + reviews
- **Atlassian MCP** -- enables full JQL queries
- **Playwright MCP** -- enables UI testing with screenshots
- **Others** -- auto-detected and integrated

Run `make discover-mcp` or let the agent detect on first use.

## Configuration

Everything in one file: `workspace.yaml`

```yaml
project:
  name: "my-platform"
  ticket_prefix: "PROJ"

services:
  - name: backend-api
    path: services/backend-api
    language: python
    test: "poetry run pytest tests/"

environment:
  formula: kubernetes

gates:
  plan_approval: true      # Always ask before coding
  pr_creation: true        # Always ask before opening PR

risk_triggers:
  multi_service_change: true
  large_diff_threshold: 500
```

## Make Targets

```bash
# Setup
make init                    # First-time setup
make add-service NAME=x REPO=url  # Add a service repo
make import-services GITMODULES=/path  # Bulk import from .gitmodules
make list-services           # List onboarded services
make discover-mcp            # Auto-detect available MCP tools
make env-check               # Verify environment health

# Understanding & Documentation
make understand              # Trigger workspace-understand skill
make generate-docs           # Trigger generate-docs skill
make workspace-info          # Show workspace summary

# Development (per-ticket)
make artifact-init TICKET=X  # Create artifact directory
make snapshot TICKET=X       # Capture baseline submodule SHAs
make snapshot-after TICKET=X # Capture post-change SHAs
make diff TICKET=X           # Show what changed across repos
make validate TICKET=X       # Check artifact completeness

# Operations
make logs SVC=backend-api    # View service logs
make restart SVC=backend-api # Restart a service
make status                  # All services status
make clean-artifacts         # Remove empty artifact dirs
```

## Why 2 Gates?

Enterprise development needs guardrails, but too many approvals kills velocity. We settled on 2:

1. **Plan Gate** -- "Here's what I'm going to change. Proceed?" Prevents wasted implementation on wrong assumptions.
2. **PR Gate** -- "Tests pass, here's the PR. Open it?" Prevents unreviewed code from hitting the repo.

Everything between runs autonomously. Unless a **risk trigger** fires (multi-service change, schema migration, large diff, test failures), then the agent pauses and asks.

## Multi-Repo Protocol

When a change spans repos:

1. Agent creates branches in each service repo
2. Implements and tests changes independently
3. Runs workspace integration tests
4. Captures submodule diffs (before/after SHAs)
5. Creates service PRs first, then workspace PR for pointers
6. Links all PRs together

## Contributing

1. Fork this repo
2. Add your environment formula or skill
3. Submit PR

## License

MIT
