---
name: pr-description
description: Generate a PR title and description from staged git changes and conversation context. Outputs markdown based on the repo's PR template. Use when the user says "PR description", "write PR", "generate PR", "draft PR", or "/pr-description".
argument-hint: "[optional: prefix type]"
---

# Generate PR Description

Create a PR title and filled-in PR description from the currently staged (or branch) changes, using the repo's PR template as the base.

## Arguments

$ARGUMENTS

Parse the user's input to extract:

- **type**: one of `feat`, `bugfix`, `chore` — if not provided, infer from the changes
- **scope**: service or area abbreviation (e.g., `vfm` for vuln-feeds-manager) — if not provided, infer from changed file paths

Also incorporate any relevant context from the current chat conversation that relates to the staged changes (e.g., the user described what they're doing, why, or referenced a ticket).

## Process

### Step 1: Gather Changes

Run these commands to understand the changes:

1. `git diff --cached --stat` — get an overview of staged files
2. `git diff --cached` — get the full staged diff
3. If no staged changes exist, fall back to `git diff main...HEAD --stat` and `git diff main...HEAD` to use the branch diff instead
4. `git log main...HEAD --oneline` — see commit messages on this branch for additional context

### Step 2: Read the PR Template

Read the file `.github/pull_request_template.md` from the repo root to use as the structural base for the description.

### Step 3: Determine PR Metadata

- **Type prefix**: Decide between `feat()`, `bugfix()`, or `chore()` based on the nature of the changes:
  - `feat`: new functionality or capability
  - `bugfix`: fixing broken behavior
  - `chore`: refactoring, dependency updates, config changes, migrations, cleanup
- **Scope**: Derive a short scope from the primary service or area being changed (e.g., `vfm`, `collector`, `api`). Use common abbreviations where they exist.
- **Title**: Write a concise, lowercase title after the prefix (e.g., `chore(vfm): migrate logging from logrus to logging/v2`)

### Step 4: Fill In the Template

Fill in each section of the PR template, replacing the comment lines (lines starting with `>`) with real content:

- **Description**: Explain the **effect** of the change — what behavior, capability, or guarantee changes for users, callers, or the system — not the implementation. A reviewer should be able to read the description and know what is now different about the running system, without needing the diff to make sense of it.
  - Effect (good): "Vulnerability ingestion now retries transient upstream 5xx errors instead of dropping the batch."
  - Implementation (avoid): "Wrapped `fetchBatch` in a `retry.Do` with exponential backoff in `ingest.go`."
  - Mention specific files, functions, or code structures only when they are load-bearing for a reviewer (e.g., a new public API surface, a new config key, a renamed exported symbol) — not as a tour of the diff.
  - Exception: for `chore`/refactor PRs where the implementation *is* the point (e.g., "migrate logging from logrus to logging/v2", dependency bumps, file moves), describing the implementation is appropriate, since that is the effect.
  - Use bullet points when there are multiple distinct effects. Be specific but concise.
- **Tests and additional notes** (optional section): Include this section **only if** at least one of the following applies:
  - Tests were actually added or modified in the diff — name them and summarize the coverage they add.
  - There is a substantive note worth carrying into the PR (e.g., a follow-up that's intentionally out of scope, a known caveat, an important deployment ordering constraint).
  - If neither applies, **omit the entire section** — no header, no placeholder text, no "No test changes in this PR" filler.

### Step 4.5: Anomaly check before output

Before producing the markdown block, review every candidate "additional note" you considered including. If any of them describe something that looks **wrong, missing, inconsistent, or potentially erroneous** rather than a deliberate caveat, **stop the skill** and surface the concern to the user instead of writing it into the PR.

Examples that should trigger an interrupt (not an exhaustive list):
- A config or manifest references a file/path/symbol that is not part of this change and you cannot verify exists.
- A symbol was removed but appears to still be referenced elsewhere in the diff or repo.
- A change looks half-finished (e.g., a TODO left in, an empty function body where logic was expected, an import added but unused).
- A renamed/moved file appears to have lost or gained content beyond what the rename should produce.
- Anything that makes you want to write "Note:" with a hedge — that hedge is a signal to ask, not to ship.

When triggered:
1. Do **not** print the Step 5 markdown block yet.
2. Use `AskUserQuestion` to describe the specific concern and offer at minimum: **"Stop — I'll fix it"** and **"Continue — this is intentional"** (the tool's "Other" escape hatch covers free-form replies).
3. If the user picks "Stop", end the skill here without committing or writing a temp file. They will re-run `/pr-description` after fixing.
4. If the user confirms it's intentional, proceed to Step 5. They may instruct you to fold the note into the PR description, drop it, or rephrase it — follow that instruction.

Deliberate caveats that the user already knows about (e.g., "this is a follow-up to PR #123, the matching server change ships separately") are **not** anomalies — those belong in the Tests and additional notes section without interrupting.

### Step 5: Output

Output the final result as a markdown code block so the user can easily copy it. The format must be:

~~~
```markdown
# Title goes here

### Description
...

### Tests and additional notes      ← include this section only if Step 4 produced content for it
...
```
~~~

If the Tests and additional notes section was omitted in Step 4, the markdown block ends after the Description content — do not emit an empty header.

The title line with the prefix (e.g., `chore(vfm): migrate logging from logrus to logging/v2`) should be the first line inside the code block, as an H1 heading.

Comment lines from the template (lines starting with `>`) must NOT appear in the output — they are instructions, not content.

### Step 6: Commit or save

After printing the markdown block, ask the user — using the `AskUserQuestion` tool — what to do with the generated message. Treat the title as the commit subject and the description body as the commit body (the same text doubles as the PR title/description and the commit message in this user's workflow).

Offer these two options (the tool surfaces an "Other" escape hatch automatically):

1. **Commit staged changes with this message** — proceed to "If commit" below.
2. **Write to temp file** — proceed to "If temp file" below.

Act on the user's choice.

#### If commit

- Build the commit message: subject line = the PR title **without** the leading `# ` (so `chore(vfm): migrate logging from logrus to logging/v2`, not `# chore(vfm): ...`); body = the rest of the markdown block (Description and, if present, Tests and additional notes), separated from the subject by exactly one blank line. If the Tests section was omitted, the body is just the Description.
- Write that message to a temp path via `mktemp -t pr-description` (with `.md` suffix), then run `git commit -F <path>`. Use `-F` rather than inline `-m` because the body is multi-paragraph with bullets.
- **Do not** add a `Co-Authored-By:` trailer or any other co-author attribution. This overrides the default Claude Code commit-flow guidance, per the user's global rule.
- Do not pass `--amend`, `--no-verify`, `--no-gpg-sign`, or similar flags unless the user explicitly asked for them.
- Edge case — nothing staged: if Step 1 fell back to the branch diff because `git diff --cached` was empty, there is nothing to commit. Tell the user that, and offer the temp-file option instead of running `git commit`.
- After the commit succeeds, run `git status` and `git log -1 --oneline` and show the output so the user can confirm the result.

#### If temp file

- Create a path with `mktemp -t pr-description` (with `.md` suffix) and write the full message (subject + blank line + body, same form used for the commit case) to it via the `Write` tool.
- Report the absolute path back to the user along with a ready-to-run command, e.g. `git commit -F /tmp/pr-description.XXXXXX.md`.

#### If the user picks "Other" or declines

Do nothing further; the markdown block from Step 5 is already on screen for them to copy.

