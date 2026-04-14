# Procedure: Changeset

## Purpose

Track multi-repo changes. Push branches, capture before/after submodule state, generate diff for audit trail.

## Inputs

- Code committed on feature/fix branches in each affected service
- `submodules-before.json` captured at artifact-init time

## Prerequisites

- All tests passing (from verify)
- Service branches ready to push

## Procedure

### 1. Push Service Branches

```bash
cd <service> && git push origin <branch>
```

| Push error | Fix |
|-----------|-----|
| `rejected (non-fast-forward)` | `git pull --rebase origin <branch>`, resolve, push |
| `permission denied` | Ask user — needs repo permissions |
| `branch protection` | Expected — branch exists on remote for PR |

### 2. Capture Post-Change State

```bash
make snapshot-after TICKET=<KEY>
```

### 3. Generate Diff

```bash
make diff TICKET=<KEY>
```

Write `submodule-diff.md`:

```markdown
| Service | Before SHA | After SHA | Branch | Commits |
|---------|-----------|-----------|--------|---------|
```

Get commit details per service:
```bash
cd <service>
git log --oneline <before-sha>..<after-sha>
git diff --stat <before-sha>..<after-sha>
```

### 4. Stage Workspace Pointers

```bash
cd <workspace-root>
git add <service>    # for each changed service submodule
```

Don't commit yet — that happens after service PRs merge.

### 5. Validate Artifacts

```bash
make validate TICKET=<KEY>
```

If validation finds missing artifacts, fill them before proceeding.

## Required Outputs

- Service branches pushed to remote
- `submodules-after.json` in artifact directory
- `submodule-diff.md` with before/after SHAs and commit details
- Workspace submodule pointers staged (not committed)

## Success Criteria

- All service branches pushed successfully
- Before and after snapshots captured
- Diff shows only expected services changed
- `make validate` passes

## Failure Modes

| Failure | Recovery |
|---------|----------|
| Push rejected | Rebase on main, resolve conflicts, push again |
| Permission denied | User needs to configure repo access |
| Missing before snapshot | Run `make snapshot TICKET=<KEY>` retroactively from main |
| Artifact validation fails | Fill missing artifact files before proceeding to PR gate |
