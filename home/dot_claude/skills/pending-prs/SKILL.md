---
name: pending-prs
description: List the user's open, non-draft work PRs with their review status, formatted as a paste-ready Slack review-request post (emoji-legend line, plain per-service headers, one bullet per PR with a status emoji, the title, and a bare URL). Read-only; never posts. Use when the user says "which of my PRs need review", "show my open PRs needing review", "pending PRs", "review request post", "PRs to ask for review", "/pending-prs", or wants a Slack-ready list of their PRs awaiting approval.
argument-hint: "[optional: theme line, or a lookback like '30d']"
---

# Pending PRs

Build the Slack post the user pastes into their team channel to ask for approvals. It
lists every open PR with a status emoji, so the channel can see what's waiting, what has
comments, and what's done.

**This skill never posts.** The output is text for the user to paste. Do not call any Slack
send, draft, or schedule tool, and do not request reviewers or comment on the PRs.

## Arguments

$ARGUMENTS

- A quoted phrase or sentence is a theme line placed under the legend line.
- A lookback like `30d` or `all` widens the age window (default: 14 days).

## 1. Collect candidates

Search every repo at once. Work PRs are usually spread across several repos and orgs (a
monorepo, a deploy/helm repo, standalone services), so `gh pr list` in a single repo misses
some:

```bash
gh search prs --author @me --state open --draft=false \
  --json repository,number,title,url,createdAt --limit 200
```

## 2. Decide which owners count as work

Keep only repos owned by the user's **work orgs**. Being a member of an org doesn't make it
a work org (people join open-source and hobby orgs too), so find the list this way:

1. If memory or CLAUDE.md names the work orgs, or says which repos are out of scope, use
   that.
2. Otherwise, group the candidates by owner and ask once with AskUserQuestion
   (multiSelect) which owners are work. Mark the owner of the current repo's `origin` as
   recommended. Offer to save the answer to memory so you don't have to ask next time.

Drop everything else without mentioning it: repos under the user's own login
(`gh api user --jq .login`), third-party repos, and personal or hobby orgs.

## 3. Get review state, base, and files for each candidate

```bash
gh pr view <N> -R <owner/repo> \
  --json number,title,url,isDraft,author,reviewDecision,latestReviews,reviews,comments,baseRefName,headRefName,createdAt,files
```

Run these in parallel (one Bash call with a loop is fine).

Drop `isDraft` PRs (the search filter should already have removed them), and drop PRs older
than the lookback window from the post but list them in the terminal as stale. Every other
PR goes in the post with one status emoji, checked top to bottom:

| Condition | Emoji |
|---|---|
| `reviewDecision == APPROVED`, or (repo has no required reviewers, so `reviewDecision` is empty) any `latestReviews` entry is `APPROVED` | `:white_check_mark:` |
| `reviewDecision == CHANGES_REQUESTED`, or any review or PR comment from a human other than the PR author | `:speech_balloon:` |
| anything else: no human has touched it yet | `:hourglass_flowing_sand:` |

"Human" excludes the PR author and bots: `github-actions`, any login ending in `[bot]`, and
review bots such as `copilot-pull-request-reviewer`. CI and Tilt bots comment on most PRs,
so counting them would mark everything `:speech_balloon:`.

## 4. Assign each PR to a service header

Work it out from the changed paths first and the title scope second:

- Monorepo: the deepest directory that is a service or library, meaning it holds its own
  build file (`BUILD.bazel`, `pom.xml`, `go.mod`, `Cargo.toml`, `package.json`, …). For
  example, `<domain>/<svc>/src/…` goes under `<svc>`, not `<domain>`.
- `.claude/skills/…` or other agent-tooling paths only → `skills`.
- Deploy/helm repo: `charts/<svc>/…` → `<svc> (helm)`.
- Single-service repo → the repo name, or the service name its README or build uses when
  that's different.
- If the PR spans several services, file it under the one the title scope names. If the
  title has no scope, use the service with the most changed files.

Use the full service name as it's written in the repo, not the scope abbreviation from the
commit title.

## 5. Stacking annotations

For stacked-PR branches (`spr/…`, graphite, ghstack): if `baseRefName` is another open PR's
`headRefName`, append `(stacked on <its number>)`. Short parentheticals that explain real
coupling across repos are also fine, e.g. `(the evaluator half of 1234)`, but only when the
session or PR body shows the link. Never guess one.

## 6. Output

Put the post in a single fenced code block so it copies cleanly:

```
:code-review:  emoji legend :white_check_mark: = reviewed, :speech_balloon: = comments and no approval, :hourglass_flowing_sand: = waiting
<theme line, only if one was given>

<service>:
• :white_check_mark: <full PR title verbatim> <bare PR URL>
• :hourglass_flowing_sand: <title> <url> (stacked on <N>)

<other service>:
• :speech_balloon: <title> <url>
```

Rules:

- The legend line is fixed text, copied exactly as above (two spaces after
  `:code-review:`), even if some emoji don't appear in this post.
- Theme line: use the argument if one was given, on its own line right under the legend.
  Otherwise leave the line out. Don't invent a theme.
- Header is a plain `<service>:` line, with a blank line between groups. No `*bold*`:
  Slack's composer doesn't convert pasted markup, so the asterisks would show literally.
- Use the `•` bullet character, not `*` or `-`.
- After the bullet, the status emoji, one space, the title verbatim, then one space and the
  **bare** URL. No colon, and no `<url|text>` mrkdwn: that shows up as literal text when
  pasted into the Slack composer, and Slack shortens bare URLs by itself.
- Leave out sizes, CI status, ticket keys, ages, and reviewer names.
- Order groups by their newest PR, newest first. Inside a group, put a stack in order from
  bottom to top, and otherwise newest first.
- No em-dashes.

After the code block, add a short terminal-only note (not part of the post): a count per
status, and the PRs left out as stale beyond the window, with number and repo for each so
the user can widen the window if they want. If there are no open PRs in the window, say so
and skip the code block.
