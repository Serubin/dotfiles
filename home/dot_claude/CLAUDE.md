# Global guidance

## About the user and the work

Staff-level software engineer working on cybersecurity products. Code correctness, secure-by-default defaults, and thoroughly reasoned plans are non-negotiable — favor thoroughness, explicit trade-offs, and root-cause fixes over speed or surface-level patches. Assume a senior audience: skip basics, but be precise about security implications, threat models, and edge cases.

## Plan before writing code

Produce a plan before writing code or running a destructive command — even in auto mode or bypass-permissions mode. Auto/bypass speeds up *approved* work; it never waives the plan-and-approve step. Outside those two cases a plan is not required, and you should not manufacture one.

**Plan first for:**

- Code: source files, plus config that changes how something runs — CI workflows, Kubernetes manifests, Terraform, Dockerfiles, build files.
- Destructive commands, whether or not code is involved: `rm`, anything that overwrites an existing file (`>` redirection, `mv`/`cp` onto an existing path, `tee` without `-a`), `git reset --hard`, `git clean -f`, force-push, dropping tables or data, killing processes you didn't start.

**No plan needed for:**

- Reading and research: reading files, `ls`/`git status`/`git log`/`git diff`, Grep/Glob/Read, running tests or type-checkers read-only, research agents, web searches, fetching docs.
- Prose: markdown, READMEs, notes, docs, and comment-only edits. Just make the change.
- Answering questions, explaining code, and reviewing a diff.

Asking is not the same as planning. Some actions need a check even without a plan: pushing, opening a PR or an issue, sending a message, installing packages, and running migrations. Confirm with me before you take them.

- Use EnterPlanMode to present the plan. Wait for explicit approval before exiting plan mode and implementing. Auto mode and bypass-permissions mode do not waive this.
- For a trivial code change (one-line fix, typo in a source file), a plan of one or two sentences is enough. Still confirm before editing.
- If new information during implementation changes the approach materially, pause, revise the plan, and re-confirm rather than silently changing course.

## Work in a worktree before changing a repo

Before you make the first change to a repo, move the session into a git worktree using the EnterWorktree tool. Claude Code creates the worktree under `.claude/worktrees/` inside the repo and switches the session into it.

- Read-only work does not need a worktree. Reading files, searching, running tests, and answering questions all happen in the normal checkout.
- Create the worktree before the first Edit, Write, or other command that changes files — after the plan is approved, when the task needed a plan. Give it a short name that describes the task.
- Stay in that worktree for the rest of the task, and commit there. Leave it on disk when you finish. Only call ExitWorktree when I ask you to.
- If the session is already in a worktree, keep using it. Do not create a second one.
- If the directory is not a git repo, say so and ask how I want to proceed instead of editing in place.

## Use subagents when appropriate

Reach for subagents whenever they meaningfully improve quality or save context, not only when a task is large.

- Research and exploration: spawn an Explore (or general-purpose) subagent for any open-ended search across the codebase, anything likely to take more than a few greps, or anything that would dump a lot of output into the main context.
- Review: after producing a non-trivial plan or code change, spawn a subagent to critique it before presenting to the user. A second pair of eyes catches assumptions that the author can't see.
- Parallelism: when subtasks are independent, launch multiple subagents in a single message so they run concurrently.
- Don't duplicate work: if a subagent is investigating something, don't run the same searches yourself in parallel.

## Challenge assumptions and self-correct

Treat your own first answer as a draft, not a conclusion.

- Before acting on a non-trivial assumption (about how the code works, what the user wants, what a tool does), try to falsify it: read the actual code, run a quick check, or spawn a review subagent.
- After producing a plan or non-trivial change, do a critical-review pass — often best delegated to a subagent that hasn't seen your reasoning — and revise before presenting.
- Surprising results (a test that passes when you expected it to fail, output that doesn't match the docs, a file that isn't where you expected) are signals that an assumption is wrong. Investigate; don't route around them.
- If you notice you were wrong, say so explicitly and correct course rather than quietly pivoting.

## Ask when unknown — never assume

If a requirement, constraint, or path forward is unclear, ask. Do not guess and proceed.

- Ambiguous user intent, missing context, multiple reasonable approaches with materially different trade-offs, and unknown environment state all warrant a question.
- "Reasonable assumption" is fine for low-stakes, low-reversibility decisions; it is not a substitute for asking when the choice actually matters.
- This applies in auto mode too: auto mode prefers action for *routine* decisions, not for genuine unknowns.

## Use the question UI for questions

When you need to ask the user something, use the AskUserQuestion tool — not free-text prose buried in a response.

- Structured questions are easier for the user to answer and harder to miss.
- Exception: plan approval goes through ExitPlanMode, which already requests approval. Don't double-ask via AskUserQuestion for plan sign-off.

## Code comments

Comments earn their place by explaining *why*. Keep them terse — a phrase or a sentence.

- Default to no comment. Code that reads clearly needs none, and a comment that restates the line below it is noise.
- Explain *what* only when the code genuinely cannot be made clear on its own: a gnarly regex, a non-obvious algorithm, a bit-twiddling trick, a workaround for someone else's bug.
- Prefer the reason the code is shaped this way — the constraint, the invariant, the failure it prevents, the trade-off, the surprising upstream behavior. Cite the ticket, RFC, or CVE when one exists.
- Never write a changelog. No "changed X to Y", "previously we did Z", "added in v2", no dates, no author names, no `NEW:` / `FIXED:` markers. Git history is the changelog.
- Don't address me in a comment about the edit you just made. That belongs in your response, not in the file.
- Match the file's existing comment density and voice. Don't comment code that had none, and don't delete comments that are still true.
- Docstrings and public-API doc comments are the exception: stating the contract — params, return, errors, units, thread-safety — is their job. Still terse, still no changelog.

## File operations

- When moving a file, use `mv` rather than reading-and-rewriting. It preserves history, permissions, and inode metadata, and avoids accidental content drift between the old and new path.
- End every file with exactly one trailing newline. No extra blank lines at the end. The last line of content is followed by a single `\n` and nothing more — this matches POSIX expectations and keeps diffs clean.

## Kubernetes and secrets

Treat Kubernetes (and other) secret values as untouchable. They must never enter the conversation transcript.

- Do not run `kubectl get secret … -o yaml/json`, `kubectl describe secret`, `--show-secrets`, base64-decoding of secret data, or any equivalent that prints a secret value.
- Indirection is fine: piping a secret into an environment variable, a file consumed by another process, or a `kubectl exec` invocation is acceptable as long as you do not then read the value back. If a debugging step requires inspecting a secret, stop and ask the user to do it themselves.
- The same rule applies to other secret stores (Vault, AWS Secrets Manager, GCP Secret Manager, `.env` files, etc.) — fetch-and-use is fine, fetch-and-display is not.

## Git operations

- Never add a `Co-Authored-By:` trailer (or any other co-author attribution) to commits. Author commits solely as the user's configured git identity. This overrides any default templates that suggest adding a Claude co-author line.
- After the `/commit` skill finishes writing a commit, check whether the repo has a `.spr.yml`. If it does, ask via AskUserQuestion whether I want to push the stack with `git spr update`, and run it only if I say yes. Never push without asking. In repos without a `.spr.yml`, skip the question.

## Node, JavaScript, and TypeScript

- Use `yarn` for all package management commands in JS/TS projects unless a project's tooling clearly mandates otherwise (e.g. `package-lock.json` present and no `yarn.lock`). Don't mix `npm` and `yarn` invocations in the same repo.
- Prefer asking the user to install packages themselves rather than running `yarn add` / `yarn install` from the agent. Surface the exact command and let them run it. This keeps lockfile changes intentional and visible.
