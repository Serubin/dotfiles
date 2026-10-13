---
name: find-session
description: Find a past Claude Code session from a ticket key (VULN-2386), PR number or URL, branch or worktree name, session-id prefix, or a fuzzy description of what was worked on, and hand back a ranked shortlist with copy-pasteable `claude --resume` commands. Searches every project's transcripts, the prompt history (which outlives pruned transcripts), and the memory files' originSessionId links. Read-only; never resumes or modifies a session. Use when the user says "find the session where…", "which session did I…", "resume the X session", "where did I work on X", "find my session for VULN-1234 / PR 35027", "what was that conversation about…", or "/find-session".
argument-hint: "<ticket | PR | branch | session-id | description> [--deep] [--days N] [--project SUBSTR] [--limit N] [--json] | --show <id>"
---

# Find session

Turn a vague handle into the session that actually did the work, plus the command to resume it.

## Arguments

$ARGUMENTS

## What gets searched

`find-session.py` (next to this file) reads, never writes:

| Source | What it gives | Limit |
|---|---|---|
| `~/.claude/projects/<slug>/<id>.jsonl` (subagent transcripts excluded) | titles (current and earlier), worktrees, branches, PR links, the first 20 prompts, last prompt, dates, resume dir | Pruned after `cleanupPeriodDays` (30 days by default) |
| `~/.claude/history.jsonl` | every prompt typed, with project and session id | Goes back months, and is the only trace of pruned sessions |
| `~/.claude/projects/*/memory/*.md` | `originSessionId`: the session that wrote a memory about the topic. A match in the memory's name/description counts strongly; an identifier in its body counts like a prompt | Only for topics that earned a memory |
| `--deep`: raw transcript lines | line-hit counts for each term, including assistant prose and tool output; injected CLAUDE.md/MEMORY.md/skill text is skipped | Counts only, never text. About 7s vs 2s |

The current session (`$CLAUDE_CODE_SESSION_ID`) and earlier `/find-session` slash-command prompts
are excluded, so the search can't match itself. An earlier natural-language request ("find the
session where…") is not excluded. If one ranks high, it is a search, not the work. Skip it.

## 1. Shape the query

- **Copy identifiers exactly.** The script recognises ticket keys, `CVE-…`, `#123` / PR URLs /
  bare numbers of 4+ digits, and session-id prefixes, and weights them heavily. `SHA-256` and
  `UTF-8` are not tickets.
- **For a description,** pass 2–5 distinctive words, not a sentence. Fix typos and add the code
  identifiers the session would have used. "the auto-increment thing in RBS" becomes
  `rbs autoincrement ceiling 1467`. Text is compared as lowercase alphanumerics, so
  `auto-increment`, `auto_increment` and `AutoIncrement` all match `autoincrement`, in both
  default and `--deep` mode. Terms match from a word start, so `rbs` does not hit `herbs`.
- **Know what gets dropped.** Terms shorter than 3 characters (`ld`, `sf`, `go`), stopwords, and
  non-ASCII text are discarded, and `#NN` needs 3+ digits. Bare 4-digit years are not PRs.
  A lowercase `rhel-9` stays a plain term; only uppercase or known Jira keys (VULN, LINK, SEV,
  …) become tickets. Spell short acronyms out, or pair them with a longer term.
- **Check memory first.** If MEMORY.md mentions the topic, the linked memory file names the
  ticket, the PR, and often `originSessionId`. Add those to the query. They beat any description.

## 2. Run

```bash
python3 -I ~/.claude/skills/find-session/find-session.py <terms...> [--days N] [--project SUBSTR] [--limit N]
```

- **Narrow with flags.** `--days N` keeps sessions active in the last N days. `--project SUBSTR`
  matches the project folder or resume dir (e.g. `helm3`, `worktrees/exploit`).
- **Add `--deep`** only when the default run's best hit is weak (prompt tier, low score) or the
  user describes something that came up mid-session rather than what the session was for.
- **Use `--json`** when you need to reason over many results. Plain text is fine for a
  shortlist.

**Reading the output.** Each hit's tier is the strongest place it matched:

| Tier | Where it matched |
|---|---|
| `structural` | title, worktree, branch, project dir, PR link, session id |
| `memory` | a memory written by that session |
| `prompt` | prompt text, the first prompt counting most |
| `full-text` | `--deep` only |

Reporting sessions (ticket-status, oncall handoff, weekly report) mention many tickets in prompts.
Expect them in the prompt tier below the session that did the work. `matched:` explains each
ranking.

**The pruned section** lists sessions whose transcript is gone. They can't be resumed. The
prompt excerpt and dates are all that remains.

## 3. Verify the top candidates

For the top 3–5, run `--show <id-prefix>`:

```bash
python3 -I ~/.claude/skills/find-session/find-session.py --show 5ebc86ac --prompts 8
```

It prints the transcript path, every title the session has had, its worktrees, branches, PRs, a
`continued in` session if it was continued elsewhere, its first N prompts and its last 3 prompts.
Everything except the path and the ids is redacted. Drop candidates that only mention the topic in passing.

If two candidates are still close, delegate a check to a subagent: give it the transcript path
(`--show` prints it; `--json` has it as `path`) and ask whether the session *worked on* X,
returning one sentence. **Never read a transcript into
this context.** They run to tens of MB and hold tool output that may contain secrets.

## 4. Present

Up to 5 sessions, best first. For each one:

- the latest title, its active date range, and the worktree or PRs if any
- one line on why it is the match, in your words, not the raw `matched:` dump
- the `resume:` command, verbatim
  - if it says `(dir no longer exists)`, the worktree was cleaned up. `claude --resume <id>` from
    the original project dir may still work; say so rather than inventing a path.
- for a PR match, `claude --from-pr <number>` as an alternative

Then list pruned matches under their own heading: "existed, transcript gone". Give the date,
project and what the prompt shows. If the user needs what was in it, point to any memory file,
plan, or PR it produced.

If nothing matches, say so. Give the searchable window (`since` in the header) and, if the topic
predates it, that the transcript has most likely been pruned.

## Rules

- **Read-only.** Never run `claude --resume`, `--fork-session`, or anything that writes to a
  session or to `~/.claude`. The user runs the command.
- **Show only what the script prints.** Prompts, titles, branches and worktree names are redacted:
  tokens, keys, JWTs, PEM blocks, URL credentials, bearer/basic auth, `KEY=value`, and hex runs of
  32+ characters (full git SHAs included). Don't add raw transcript text the script withheld.
