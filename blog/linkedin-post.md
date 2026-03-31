# Making Copilot Useful in a Multi-Repo Microservices Workspace

AI coding agents are great at single-repo tasks. Fix a function, write tests, add an endpoint. That works.

But what happens when your product is 12 microservices across 12 repositories, with Kubernetes, message queues, multiple databases, and an authorization engine? A user reports something broken, and the root cause is spread across multiple services in different repos. No agent handles that out of the box.

We figured out a way to make it work. Not by building new tools, but by organizing the tools we already had.

---

## How This Idea Started

It started with local development setup, not AI agents.

Debugging in a shared dev cluster is painful when you can't reproduce issues locally. So we added Skaffold configs to each service, set up a local Kubernetes cluster, and wrote make commands to bring services up. That worked for individual repos, but coordinating across 12 services was still manual.

So we created a workspace repo. It imported each service as a git submodule, pulled in their Skaffold configs and make commands, and added metadata about how services connect to each other, which ones share a database, which ones talk through message queues, what the request paths look like.

Once we had that structure, we started using AI agents to help with issues. The agent could see all 12 repos at once, so it could compare configs across services instead of looking at one in isolation. We gave it Kubernetes MCP access so it could check pod health and pull logs directly. The goal was simple: let the agent handle the grunt work — reading logs, tracing request paths, correlating code across repos, writing fixes, running tests, drafting PRs. Not replace the developer, but take the ticket from investigation to PR with human approval at two gates.

That worked well, so we pushed further. We added cross-repo awareness to PR reviews, so the agent could flag when a change in one service might break a contract with another. Then we connected Jira, so it could read bug tickets with reproduction steps and start investigating from the ticket itself. Then we added the full workflow: investigate, plan, implement, test, PR.

Each step was a small addition. None of it was planned as a "framework." We just kept giving the agent more context and more structured instructions, and it kept getting more useful.

---

## What We Built

A workspace scaffold that gives AI agents the context they need to work across repos, with 2 default human approval gates and conditional interrupts on risk triggers.

```
workspace/
├── .github/
│   ├── copilot-instructions.md    # Agent system prompt
│   ├── skills/                    # Step-by-step workflows
│   │   ├── ticketflow/            # Find and read tickets
│   │   ├── dev-agent/             # End-to-end bug fix workflow
│   │   └── procedures/            # Atomic steps (investigate, plan, implement...)
│   ├── formulas/                  # Environment adapters (k8s, docker, custom)
│   └── templates/                 # Artifact templates
├── workspace.yaml                 # Single config file
├── Makefile                       # Bootstrap CLI (init, add-service, env-check...)
├── services/                      # Git submodules (your repos)
├── docs/                          # Generated agent memory (service map, contracts...)
└── artifacts/                     # Evidence trail per ticket
```

The key ideas:

**Skills are specific, not vague.** Instead of "investigate the bug," a skill says: check pod health, pull logs, search for exceptions, trace the request path across services defined in workspace.yaml. The more specific the instructions, the better the agent performs. These are just markdown files that the agent reads and follows.

**2 default gates, with conditional interrupts.** After a lot of iteration, we settled on two approval points: plan and PR. First, the agent presents its investigation and plan ("here's what I found, here's what I'll do"). You approve or redirect. Then it implements, tests, and presents the diff. You approve the PR. Everything between those two gates runs autonomously, unless a risk trigger fires (multi-service change, schema migration, large diff, test failures). Those triggers are configurable, not hardcoded.

**Environment formulas.** The same workspace works whether you run Kubernetes, Docker Compose, or something custom. `make env-check` does the right thing regardless.

**docs/ as agent memory.** A workspace-understand skill scans all repos and generates a service map, API contracts, infrastructure inventory, and coding conventions. The agent reads these before every investigation so it doesn't have to re-scan. If a tool isn't available, the skills have fallback instructions. No Jira MCP? The agent just asks you for the ticket key instead.

---

## The First Real Win

While setting up the local dev environment, we port-forwarded to the dev cluster's PostgreSQL instead of running it locally. Most services came up fine. But the storage service kept failing with `asyncpg.exceptions.ConnectionDoesNotExistError` and connection timeouts. The Core service, connecting to the same PostgreSQL instance over the same port-forward, worked perfectly.

We pointed the agent at it. It checked the workspace's service map, saw both services shared the same database, and opened `db_client.py` in both repos. The storage service uses async SQLAlchemy with `asyncpg`:

```python
# storage-svc/app/core/db_client.py
engine = create_async_engine(database_url)  # asyncpg defaults to SSL
```

Core uses sync SQLAlchemy with `psycopg2`:

```python
# Core-svc/app/lib/postgres_client.py
engine = create_engine(database_url)  # psycopg2 defaults to sslmode=prefer
```

Different drivers, different SSL defaults. `asyncpg` aggressively negotiates SSL. Over a kubectl port-forward with no TLS termination, the SSL handshake fails and the connection times out. `psycopg2` tries SSL, fails quietly, and falls back to an unencrypted connection. That's why Core worked and storage didn't.

Two repos. Two files. The root cause is invisible in either repo alone. You'd need to compare driver behavior across services to see it.

The agent proposed adding `connect_args={'ssl': False}` to the storage service's engine creation. We approved, it made the fix, storage connected, and we moved on with the setup.

---

## What We Learned

**Skills need to be very specific.** "Investigate the bug" produces vague results. "Check pod health, pull logs, search for exceptions, trace the request path across services" actually works. The more specific your grep patterns and decision trees, the better.

**Two gates is the sweet spot.** Plan and PR. You stay in control of direction and quality without micromanaging every step. Add conditional interrupts for risky changes (schema migrations, multi-service diffs) and you catch the rest.

**Environment readiness is half the battle.** We spent more time debugging pod health and config mismatches than actual code. Running an environment check before every investigation cut that time in half.

**Artifacts matter.** When an agent changes multiple repos, you need the paper trail. Investigation notes, SHA snapshots, test evidence. Not for process. For the next developer who asks "why was this changed?"

**It's just organized instructions.** We didn't build a framework. We organized markdown files into a structure that makes agents effective across repos. That's it.

---

## Try It

We extracted the pattern into a scaffold template on GitHub: **[agentic-workspace-template](https://github.com/your-org/agentic-workspace-template)**

We've tested it with Python and Node.js services, but the approach is stack agnostic. The skills are markdown files, the config is YAML, and the Makefile is plain shell. It should work for other stacks too.

We built this on GitHub Copilot with MCP servers, but the structure isn't locked to any specific tool. If you're using Cursor, Codex, Cloud Code, or anything else that reads instruction files, you can adapt it. The structure is what matters, not the specific tools.

The goal is to get to a point where bug tickets and feature requests can be handled end-to-end by the agent, with the developer approving the plan and the PR. We're not fully automated, but the workspace structure is what makes it possible.

---

*Building something similar? I'd love to compare notes.*

#AI #SoftwareEngineering #Github #Copilot #DevOps #Microservices #AgenticAI #AgenticEngineering #EnterpriseAI
