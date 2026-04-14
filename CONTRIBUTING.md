# Contributing

Thanks for your interest in improving the Agentic Workspace template.

## How to Contribute

1. **Fork** the repository
2. **Create a branch**: `feature/your-change` or `fix/your-change`
3. **Make your changes** — keep them focused on one thing
4. **Test locally**: `make init && make env-check`
5. **Open a PR** against `main`

## What Belongs Here

This repo is an **instruction-driven template** — not a working codebase. Changes should be:

- **Skills and procedures** — workflow contracts for AI agents
- **Templates** — artifact and PR templates
- **Configuration** — `workspace.yaml` schema and Makefile targets
- **Documentation** — README, guides, examples

## What Doesn't Belong

- Language-specific tooling (Python scripts, Node.js utilities)
- CI/CD pipelines for specific platforms
- Service code or business logic
- Credentials or environment-specific configuration

The idea: any coding agent reading the instructions can implement the tooling for the user's specific tech stack.

## Branching

- `main` — stable, always works
- `feature/<description>` — new capabilities
- `fix/<description>` — corrections

## Commit Messages

Use [Conventional Commits](https://www.conventionalcommits.org/):

```
feat: add contract test procedure
fix: correct routing table in copilot-instructions
docs: improve workspace.yaml examples
chore: update gitignore patterns
```

## Procedure File Standard

All procedure files in `.github/skills/procedures/` follow a 7-section skeleton:

```markdown
# Procedure: <Name>

## Purpose
One sentence — what this procedure accomplishes.

## Inputs
What must exist before this procedure runs.

## Prerequisites
Environment or state requirements.

## Procedure
Numbered steps with decision trees and examples.

## Required Outputs
Artifacts or state this procedure must produce.

## Success Criteria
How to verify the procedure completed correctly.

## Failure Modes
What can go wrong and how to recover.
```

## Skill File Standard

Skills in `.github/skills/<name>/SKILL.md` are execution contracts. They define:

- Entry conditions (when the skill is invoked)
- Step-by-step workflow with decision points
- MCP tool usage with fallback chains
- Error recovery tables
- Human interaction points (gates)

## Review Checklist

Before merging:

- [ ] Instructions are generic (not tied to a specific tech stack)
- [ ] `workspace.yaml` examples are commented templates, not real config
- [ ] Makefile targets use pure shell (no Python/Node dependencies)
- [ ] All internal markdown links resolve
- [ ] Procedure files follow the 7-section skeleton
