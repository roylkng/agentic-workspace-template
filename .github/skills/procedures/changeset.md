# Procedure: Changeset

> Track multi-repo changes. Capture before/after state for audit trail.

---

## Step 1: Push Service Branches

```bash
cd services/<service> && git push origin <branch>
```

| Push Error | Fix |
|-----------|-----|
| `rejected (non-fast-forward)` | `git pull --rebase origin <branch>`, resolve, push |
| `permission denied` | Ask user — needs repo permissions |
| `branch protection` | Expected for PRs — branch exists on remote |

---

## Step 2: Capture Post-Change State

```bash
make snapshot-after TICKET=<KEY>
```

---

## Step 3: Generate Diff

```bash
make diff TICKET=<KEY>
```

Write `submodule-diff.md`:
```markdown
| Service | Before SHA | After SHA | Branch | Commits |
|---------|-----------|-----------|--------|---------|
```

Get details: `git log --oneline <before>..<after>` and `git diff --stat <before>..<after>`

---

## Step 4: Stage Workspace Pointers

```bash
cd <workspace-root>
git add services/<service>    # for each changed service
```

Don't commit yet — that happens after PRs merge.

---

## Multi-Repo PR Order

1. Create **service PRs first** (one per repo, base=main, head=fix/TICKET)
2. Link PRs together in descriptions (reference each other)
3. Create **workspace PR last** (updates submodule pointers, merges after service PRs)
