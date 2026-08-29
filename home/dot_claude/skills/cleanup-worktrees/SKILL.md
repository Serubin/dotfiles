---
name: cleanup-worktrees
description: Remove git worktrees whose work has already landed on the trunk, and leave the rest alone. Audits every worktree in the repo for landed content (rebase, squash, and stacked-PR merges all rewrite the commit, so it compares diffs, not SHAs), keeps anything with an open PR, uncommitted work, or an in-progress rebase, names the ignored files removal would destroy, and asks once before deleting anything. Use when the user says "clean up worktrees", "remove old/stale worktrees", "prune worktrees", "/cleanup-worktrees", or asks which worktrees are still needed.
---

# Cleanup Worktrees

Claude Code leaves a worktree under `.claude/worktrees/` behind after every task, and they
accumulate. This skill decides which ones are dead — the work landed on the trunk — and removes
those, after showing you the evidence.

**Landed is decided by diff, not by SHA.** Rebase merges, GitHub squash merges, and stacked-PR
tools (spr, graphite, ghstack) all rewrite the commit that lands, so `git branch --merged` and
SHA comparison both report nothing. A merged PR is not proof either: in a stack, the bottom
commit can be merged while a commit on top of it has no PR at all.

## Step 1 — Audit

```bash
python3 ~/.claude/skills/cleanup-worktrees/audit-worktrees.py -o "$TMPDIR/wt-audit.json"
```

Resolve the script's path relative to this SKILL.md's own directory. Run it from inside the repo,
or pass `--repo <path>`. It is read-only: no code path in it removes a worktree, deletes a ref,
or touches a working tree. Other flags: `--trunk <branch>` when autodetection is wrong (also the
way to audit a repo with no remote), `--no-fetch` when offline — which withdraws the `content`
check, since a byte-match against a stale trunk proves nothing — and `--no-gh` to skip PR lookup.

If it exits non-zero, stop and report the error. **Do not remove anything on a failed audit.**

## Step 2 — Show the table

Print the script's table **verbatim**. Don't summarize the KEEP reasons away — the point of the
table is that the user sees why each survivor survived.

| Verdict | Meaning |
|---|---|
| `LANDED` | Clean, and the whole commit range is on the trunk (`ancestor` / `patch-id` / `squash`). Removal candidate. |
| `LANDED?` | Clean, and the touched paths match the trunk byte for byte, but no patch matches. Candidate, but confirm it individually — the trunk can reach the same bytes through unrelated work, which is exactly how one-line config and version-bump changes look. |
| `EMPTY` | No commits of its own. Candidate. |
| `KEEP_PR` | An associated PR is open. Left alone. |
| `DIRTY` | Uncommitted changes, an in-progress rebase/merge/cherry-pick/bisect, or a stash naming this branch. Left alone. |
| `UNLANDED` / `PR_CLOSED` | Clean but the work isn't on the trunk. Left alone — say so, and let the user decide. |
| `SKIP` | The main worktree, a bare repo, the checkout holding the trunk branch, the worktree this session is in, or a locked one (a live Claude session locks its own). |
| `PRUNABLE` | Registration whose directory is already gone. Prune, don't remove. |
| `ERROR` | A git call failed for that entry. Left alone. |

The `EXTRAS` column carries what the verdict alone doesn't say:

- `ignored:N` — files that `git status` calls clean but `git worktree remove` deletes anyway
  (`.env`, local scratch, build output). The script lists them under the table and in the JSON.
- `reflog:N` — commits the worktree's own reflog still points at but no ref does, i.e. work a
  `reset --hard` orphaned. Amends produce these routinely, so it's advisory — but the reflog dies
  with the directory, so mention it if a candidate carries one.
- `stash:N` — stash entries whose message names this branch. Best-effort: `refs/stash` is
  repo-global, so a rename or a custom `-m` defeats the match.
- `pr:?` — the commits carry stacked-PR `commit-id:` trailers but no PR matched them, so the PR
  picture is incomplete rather than empty.

If the banner says open-PR protection is off, say so — `gh` failed, or `--no-gh` was passed — and
suggest re-running with PR data rather than deleting on partial evidence.

## Step 3 — Ask once

No candidates → say so and stop.

Otherwise ask **once**, with `AskUserQuestion`:

- Offer the `LANDED` rows as one batch.
- List every `LANDED?`, `EMPTY`, and `pr:?` row, and every row carrying ignored files or an
  orphaned reflog, **individually** — naming the ignored files that removal destroys.

Never remove before this answer. Never widen the batch beyond what was confirmed.

## Step 4 — Remove

For each confirmed path:

```bash
git worktree remove <path>
```

- **Never `--force`. Never `rm -rf`.** Without `--force`, git refuses when tracked files were
  modified or untracked files exist — that refusal is a safety net, not an obstacle. If one
  fails, report the error, continue with the rest, and ask before escalating.
- `git worktree prune` for `PRUNABLE` rows.
- **Leave branches alone.** The branch ref is what makes a wrong call cheap: the commits stay
  reachable and the worktree can be recreated. Mention `git branch -D <branch>` as a manual
  follow-up; don't run it.
- Never touch a remote ref or a stash.

If the session is currently inside a candidate worktree, don't remove it — tell the user to
`ExitWorktree` first.

## Step 5 — Report

Removed, kept and why, and one line of scope: this audits worktrees, so a local branch that isn't
checked out anywhere is outside its view.
