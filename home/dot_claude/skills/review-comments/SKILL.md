---
name: review-comments
description: Turn code-review findings into PR review comments that survive contact with the author. Runs after (or wraps) the built-in `/code-review`, plus any domain reviewer skill the repo ships that covers the diff, then verifies every claim against the repo, routes each finding to an inline or top-level comment, drafts it in the `[do]` / `[question]` / `[consider]` / `[nit]` house style, presents the set with a recommended approve / request-changes / comment verdict that blocks only on non-trivial fixes in environments that matter, and delivers copy-safe text. Use when the user says "review this PR", "draft review comments", "turn these findings into comments", "check my review comments", "post my review", or "/review-comments". NOT for reviewing your own branch.
argument-hint: "[low|medium|high|xhigh|max] <pr-url>"
---

# Review Comments

`/code-review` finds things. It does not decide which findings are true, which
belong on a line, how to say them, or how they get onto GitHub. That is this
skill.

**The output of a review is not a list of findings. It is a set of comments an
author can act on.** A finding that is overstated, unanchorable, or has no ask
attached costs the author time and costs you credibility. Everything below
exists to stop those three failures.

## Scope

| Task | Skill |
|---|---|
| Reviewing someone else's PR, delivering comments | **this skill** |
| Reviewing your own branch before pushing | `/code-review` on the branch, or the repo's self-review skill |
| Finding the issues in the first place | `/code-review`, plus any reviewer skill the repo ships |

This skill composes with the finders. It does not replace them.

## Arguments

    /review-comments [low|medium|high|xhigh|max] <pr-url>

| Argument | Required | Meaning |
|---|---|---|
| Effort level | No | Passed through unchanged to `/code-review`. Omitted, `/code-review` reuses the last level typed. |
| PR link | **Yes** | `https://github.com/<org>/<repo>/pull/<N>`. Supplies `<org>`, `<repo>` and `<N>` for every command below. |

The first argument is the level only when it is one of the five words exactly;
otherwise treat it as the PR link. With no PR link, stop and ask for one. Do not
infer the PR from the current branch or from earlier in the conversation.

Every step below reads the PR through a local clone of `<org>/<repo>`. The
clone need not be the session's working directory: a deploy-config PR is often
reviewed from a session in the application repo. Find a clone whose `origin` is
`<org>/<repo>` and run git as `git -C <clone>` and `gh` with `-R <org>/<repo>`.
If there is no such clone, say so and stop.

## The cycle

1. Produce findings
2. **Verify every claim** (gate, nothing skips this)
3. Route each finding to a placement
4. Draft each comment
5. Present for triage, with a recommended verdict
6. Revise from the verdicts
7. Deliver

## 1. Produce findings

If the user has not already run a finder, run `/code-review <level> <N>`, with
the level argument if one was given and without it if not. If they have, the
level argument is unused; take the findings as **input, not as truth**.
Findings arrive from a subagent that read the diff under time pressure; treat
every one as an allegation.

Pin the head SHA once and use it for the rest of the session:

    gh pr view <N> --json headRefOid,author,isDraft,baseRefName
    git fetch -q origin pull/<N>/head        # then read via git show FETCH_HEAD:<path>

Read files at `FETCH_HEAD`, never from the working tree. The local checkout is
live and may not match the PR.

### Domain reviewer skills: run them too

Some repos ship their own reviewer skills for an area: a data-platform review,
a Spark or SQL review, a framework's conventions. When one is available and
its description covers paths or technology in `gh pr diff <N> --name-only`,
run it after `/code-review`. It carries conventions and checks a generic
review lacks. If the user already ran it on this PR in this session, take that
output as input and do not run it again. If it only supports some repos and
this PR is in another, say when you present that it was skipped and why.

- **Run it in a subagent.** Spawn a general-purpose subagent that invokes the
  skill through the Skill tool and returns only its findings (severity, file,
  line, mechanism, ask) and any evidence it gathered. It must not return a
  review body, a "submit" prompt or anything meant for posting. Loaded inline,
  a reviewer skill can bring a large instruction set and its own posting path,
  and a user who says "submit" or "post my review" would post its unverified
  findings.
- **Relay its questions.** A subagent cannot ask the user. When the skill
  wants to ask something (an access gate, a scope choice), the subagent stops
  and returns the question and options. Ask the user with `AskUserQuestion`,
  then resume the subagent with `SendMessage` carrying the answer. The same
  question can come back, for example after a retry.
- **Its checks are read-only.** Tell the subagent: read-only queries only, no
  writes, no running the PR's code or jobs, and no creating cluster resources,
  in any environment. This overrides whatever the skill itself allows.
- **Its findings are allegations too.** They go through step 2 like the rest.
  Its evidence is usable, by verdict:
  - Confirmed: the claim stands. Still re-check the line numbers.
  - Refuted, on one of its own findings: it dropped or downgraded that finding.
    Say which when you present.
  - Refuted, on a claim in the PR description: the author's claim is false,
    which is a finding in its own right.
  - Unverified, or resting on a source it could not fully reach: the claim it
    backs is a `[question]` at most.
- **Its severity is not a tag.** Severity describes the damage. The tag still
  comes from your confidence after verification. Its top severity often also
  covers outages and silently wrong output, so it blocks a small fix only when
  it meets the exception in the verdict. A low-severity observation is
  `[consider]` or `[nit]`, and drop it if it has no ask.
- **Merge duplicates.** When two finders hit the same defect, write one comment
  and keep the better-evidenced mechanism. A finder that reads other reviewers'
  comments may restate them, so drop any finding an existing thread already
  raises.

## 2. Verify every claim (the gate)

**Re-derive every factual assertion from the repo before it goes in a comment.**
Not the plausible ones, all of them. In the session this skill was distilled
from, a 14-finding review contained four defects that only fell out under
verification:

| What the finding said | What was true | Rule it produces |
|---|---|---|
| Test file line 70 | The row was at line 72 | Re-derive every line number at the head SHA |
| "This input has no test vector, a regression ships green" | Covered by a test in a different file | Before claiming *untested*, grep the whole test tree, not the file under review |
| "The commit carries an spr commit-id trailer, amend carefully" | Plain branch, no trailer | Before asserting a repo mechanic (spr, a CI gate, a lint rule), read the artifact |
| "The dep is redundant" | Depends on build-system classpath reduction; unverifiable without a build | If you cannot substantiate it without running a build, downgrade to `[question]` |

Concretely, for each finding:

- **Line numbers**: open the file at the head SHA and confirm. Off-by-two makes
  the author distrust the whole review.
- **Negative claims** ("no test", "no caller", "nothing checks this"): search
  repo-wide, not just the diff. `git grep -n <symbol> FETCH_HEAD -- '*.java'`.
  Negative claims are where reviews are most often wrong.
- **Claims about tooling or process**: read the commit message, the lint script,
  the CI config, the CODEOWNERS file. Do not recall them.
- **Claims requiring a build to prove**: either build, or restate as a question.
- **Quoted text**: paste from the file, do not retype.

When verification kills or weakens a finding, say so plainly when you present.
A review that quietly drops a finding teaches the user nothing; one that says
"this was wrong and here is why" makes the next review better.

## 3. Route each finding to a placement

**An inline comment requires the file to be in the diff.** Check:

    gh pr diff <N> --name-only

| Finding concerns | Placement |
|---|---|
| A changed line | Inline, anchored to that line |
| A file in the diff, but no single line | Inline at the most relevant line, say in the body that it is about the file |
| A file **not** in the diff (stale doc pointers, missing CODEOWNERS entry, a caller the change invalidated) | **Top-level comment** |
| The commit message or PR body | **Top-level comment** |

Findings that cannot be anchored are not lesser findings. Three of the most
substantive items in the motivating session were top-level, because the move
invalidated files the PR never touched. Collect them into one comment rather
than several.

## 4. Draft each comment

If `~/.claude/style-voice.md` exists, read it before drafting. It describes how the reviewer
actually writes — comment length, sentence shape, how they ask, refuse, concede and correct
themselves, and the tells that mark a draft as machine-written. It governs **voice and
phrasing**; the tag table below still governs **which tag to use**. So a `[do]` keeps its
meaning here and takes its wording from the guide. The file is personal and most people won't
have it; when it's absent this section is the whole standard.

### Tag every comment

| Tag | Means | Author's obligation |
|---|---|---|
| `[do]` | This needs to change | Change it, or argue back |
| `[question]` | I think this is wrong, but you may have context | Answer |
| `[consider]` | Worth thinking about, your call | Think, then decide |
| `[nit]` | Trivial, non-blocking | Optional |

Pick the tag from your confidence *after* verification, not from severity. A
serious issue you could not fully substantiate is `[question]`, not `[do]`.

A `[do]` says what has to change. It does not decide whether the review blocks.
That is the verdict's job (see *Block only when it earns the round-trip*). Two
rules come from that split:

- **A small fix goes in a `suggestion` block.** A fix is small when it is one
  line, or a few lines of mechanical edit, and leaves no design decision to
  make. The author can apply it in one click, and nobody needs a second look.
  A `suggestion` replaces right-side lines inside a diff hunk. It cannot
  target a deleted line, and a multi-line one needs `start_line` and
  `start_side` in the review payload (step 7). A small fix outside the diff,
  or one that only deletes code, goes in prose (top-level when outside the
  diff), and it still does not block.
- **A finding that only touches a dev or test environment that is not a
  release gate is `[consider]` at most.** A test file is not a test
  environment: test, CI and build code count as shared code. See the tiers
  below.

### Anatomy

1. **The tag**, then the defect in one sentence.
2. **The mechanism**, with concrete `file:line` references. Why is it broken,
   not just that it is.
3. **The ask.** What should change. This is the step most often skipped and it
   is the one that makes a comment actionable. A comment that states a problem
   and stops makes the author invent a fix, and the obvious invention is usually
   worse than the one you had in mind.
4. **The bound**, when the blast radius is smaller than it sounds. "Production
   images are unaffected because X" stops the author over-fixing.

### Styling

- **Inline backticks** around identifiers, file names, symbols, expressions.
  Single backticks, since this is the text that lands on GitHub.
- **Fenced blocks only when proposing a concrete edit.** A `[do]` carrying a
  five-line fix is clearer as a snippet than as a paragraph describing the same
  edit. Everything else is prose plus inline spans.
- **No em-dashes.** Plain sentences, one idea each. `style-voice.md`, where present, is the
  fuller version of this bullet and wins on anything it covers.
- **Link across files.** A comment on file A that cites file B needs a permalink,
  because GitHub will not show B in context:
  `https://github.com/<org>/<repo>/blob/<headSha>/<path>#L6-L10`
  Same-file references stay as plain line numbers; a wall of links reads worse.
- **State the alternative** when the author could reasonably close the finding a
  different way (narrow the API instead of hardening it, for example). Then say
  which you prefer.

### Cross-check the set before presenting

- Two comments asking for contradictory things is the fastest way to lose an
  author. If fix A dissolves finding B, say so in one of them.
- If one comment asks "does this need to be public?" and another accepts a
  different public symbol, be deliberate and say why they differ.
- Identical bodies on different anchors ("please add return value" twice) must
  actually be identical asks. Check each anchor's real gap.

## 5. Present for triage

One block per finding, in severity order.

    N. <one-line summary of the defect>

    <path>, lines <X-Y>

    > <the comment body, delimiters bumped one level:
    >  `` `spans` `` and four-backtick fences>

    <explanation outside the quote: why it matters, confidence, what you
    verified, what you could not, what you would do about it>

The blockquote is the deliverable. The paragraph after it is for the user's
decision-making and never gets posted. Keeping them visually separate is what
makes the set triageable at speed.

### End with a recommended verdict

Every presentation ends with one recommended review event, derived from the
set **after** verification, and a one-line reason naming the findings that
decide it. Never leave the verdict for the user to infer.

#### Block only when it earns the round-trip

`REQUEST_CHANGES` costs a full cycle. The author fixes it, re-requests review,
and then waits on the reviewer again. We trust authors to apply a fix they were
handed without being watched. So a `[do]` blocks only when **both** of these
hold:

1. **The fix is not small** (as defined in step 4). A small `[do]` ships as a
   `suggestion` and the review approves. Small fixes add up, though. Past about
   three to five of them, or fewer when they touch dependent logic or carry
   real severity, treat the set as not small. Use judgement.
2. **The defect reaches an environment that matters.** Production matters, and
   so does any environment that holds real customer data or is a release gate
   (a shared QA or staging environment every release passes through). Other
   dev and test environments break
   often and are cheap to fix forward, so they never block. The repo's
   `CLAUDE.md` or `CLAUDE.local.md` (below) may name the tiers; when it does,
   it wins. Classify by where the change lands:
   - **Code**, including test, CI and build code, ships to every environment,
     so it matters.
   - **Per-environment config** is classified by what each environment is.
     Look for the field that maps it to a tier, such as a config root or a
     profile, rather than guessing from the name. A name that looks like
     dev or QA can still be a release gate.
   - **Shared config counts as every environment that reads it.** A shared
     dev/test base that also feeds a release-gate environment matters, and a
     chart's or module's defaults feed them all.
   - **Dev-only** means a file under a single dev or test environment's own
     config directory.
   - **An environment you cannot classify matters.** Say so when you present.

   Some environments exist in config but are not live. They may be listed in
   `CLAUDE.md` or `CLAUDE.local.md` at the root of the clone's main checkout,
   the parent of `git -C <clone> rev-parse --path-format=absolute
   --git-common-dir`. Read them from the main checkout's working tree, not
   `FETCH_HEAD`, because they describe the environments rather than the PR.
   Claude Code does not auto-load them when the session runs elsewhere. When a finding
   lands only on a non-live environment, drop it and say why.

**One exception: irreversible damage blocks even when the fix is one line.**
That means a verified defect that would corrupt or lose data in production or
any other environment holding real customer data, or expose or make reachable a secret or customer
data there (an authz bypass counts), where fixing the code and re-running does
not undo it. Approving trusts the author to apply the fix, and here a missed
fix costs too much. A secret already in the diff is outside this exception: it
leaked at push, and blocking the merge does not undo that. The `[do]` asks for
rotation as well as removal, and the verdict does not hinge on it.

The case that produced this rule: a config PR set one flag across a dozen
environments. The review requested changes because one dev environment should
have been `'false'`. That was a one-line suggestion on an environment nobody
depends on. The right verdict was `APPROVE`, with the dev note as a
`[consider]`.

| The verified set | Recommend | Why |
|---|---|---|
| At least one blocking `[do]` (both tests above, or the exception) | `REQUEST_CHANGES` | The fix needs a second look before merge |
| A `[question]` whose wrong answer would ship a correctness, security or data-loss defect to an environment that matters | `COMMENT` | Hold approval until the author answers; do not block on an unconfirmed claim |
| Only small `[do]`s, `[consider]`s, `[nit]`s, or `[question]`s that are safe to merge whatever the answer | `APPROVE` | Name in the body any `[do]` the approval assumes will land: "Approving, take the suggestion on `values.yaml:42` before merging." |
| Nothing survived verification | `APPROVE` | Say what was checked, so the empty set reads as a result rather than a skipped review |

When more than one row applies, the first matching row wins: a set with a
blocking `[do]` and a high-stakes `[question]` is `REQUEST_CHANGES`.

Count unresolved blocking threads from earlier reviews, the user's included,
alongside the new findings. A PR with an open blocking `[do]` from a previous
round is not an `APPROVE` because this round found nothing new. Apply the same
tests to it: an old `[do]` that is small or dev-only does not hold the PR.
Resolution state is only in GraphQL; the REST review and comment endpoints do
not report it:

    gh api graphql -F owner=<org> -F repo=<repo> -F n=<N> -f query='
      query($owner: String!, $repo: String!, $n: Int!) {
        repository(owner: $owner, name: $repo) {
          pullRequest(number: $n) {
            reviewThreads(first: 100) {
              nodes { isResolved isOutdated path line
                comments(first: 1) { nodes { body author { login } } } }
            }
          }
        }
      }' --jq '.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved | not)'

The first comment is the thread's root. Its tag, put through the tests above,
says whether the thread blocks. An outdated thread may still be unaddressed,
so read it before discounting it. The query stops at 100 threads; page with
`pageInfo` past that.

The verdict is a recommendation. The user may pick a different one, and
whatever they pick becomes the `event` of the review at delivery.

    Recommended verdict: REQUEST_CHANGES, because finding 1 drops a column the
    loader still reads in prod, which loses data a re-run cannot restore.
    2 and 3 are nits.

### Write every code span with double backticks

**In the transcript only, wrap each inline code span in a double-backtick span:**
write ``` `` `parseConfig` `` ``` where the posted comment will say
``` `parseConfig` ```.

The terminal renderer consumes single backticks as styling, so a span written
normally looks right on screen but copies out as the bare word with its
backticks gone. With the double-backtick form the *outer* pair is consumed as
the delimiter and the *inner* pair is literal content, so it stays visible on
screen and the copied text is already valid GitHub markdown.

This applies to the blockquoted comment body and to any prose where the user
may copy an identifier. It costs density: a body with many identifiers reads
noisier, and that is the accepted trade.

**Bump fences by one level too.** A code example the user will copy goes inside
a four-backtick fence, so the inner three-backtick fence is literal content
rather than a delimiter and survives the copy along with its language tag. Same
mechanism, one level up. Inside the fence, code stays as written: do not double
the backticks there, they are already preserved.

The rule in one line: **anything the user will paste into GitHub gets its
delimiter bumped by one.** Spans go from one backtick to two, fences from three
to four. Both nest correctly inside a blockquote.

## 6. Revise from the verdicts

Expect terse verdicts: "landed", "not true because X", "make this focus on the
fix", "drop it". Apply them without re-litigating.

- **"landed"** = accepted as written.
- **A technical rebuttal** = check it. If the user is right, drop the finding
  and move on without ceremony. If their stated reason is not quite the reason
  the finding fails, note the real mechanism in one sentence, then drop it
  anyway. Do not defend a finding the user has closed.
- **"focus on the fix"** = the comment is problem-only. Rewrite so the
  remediation is the bulk of it, with a behaviour-preservation argument if the
  fix touches live logic.

If the user has already drafted comments themselves, read them before
commenting on them:

    gh api repos/<org>/<repo>/pulls/<N>/reviews --jq '.[]|select(.state=="PENDING")|.id'
    gh api repos/<org>/<repo>/pulls/<N>/reviews/<REVIEW_ID>/comments \
      --jq '.[]|{id,path,position,body}'

Then audit them the same way: verify their claims too, check anchors, check for
garbled sentences, check every comment has an ask.

## 7. Deliver

### The drafts file

With the double-backtick presentation above, short comments are copyable
straight out of the transcript. Write a drafts file when the set is long, when
the user asks, or when a comment carries fenced blocks that would be awkward to
copy piecemeal:

    cat > "$SCRATCHPAD/pr<N>-review-drafts.md" <<'DRAFTS'
    ... raw markdown, one labelled section per comment ...
    DRAFTS

Quoted heredoc delimiter, always, or the shell eats the backticks instead.
Label each section with the comment id and position it belongs to.

### What can and cannot be automated

| Action | Mechanism |
|---|---|
| Post a top-level comment | `gh pr comment <N> --body-file <path>`, ask first |
| Post a fresh inline review | `gh api repos/<org>/<repo>/pulls/<N>/reviews --method POST --input <review.json>` (shape below) |
| Read a pending review's comments | Review-scoped endpoint (above) |
| **Edit a pending review comment** | **Not possible.** `PATCH /pulls/comments/<id>` 404s while the review is pending. Hand-edit in the UI. |

`review.json`:

    {
      "commit_id": "<head SHA pinned in step 1>",
      "event": "REQUEST_CHANGES",
      "body": "<the one-line verdict reason>",
      "comments": [
        { "path": "<file>", "line": 42, "side": "RIGHT", "body": "[do] ..." }
      ]
    }

- **`commit_id`**: always the SHA pinned in step 1. Omitted, GitHub anchors to
  the head at post time, and a push during triage moves the verified lines.
- **`event`**: the verdict the user chose: `APPROVE`, `REQUEST_CHANGES` or
  `COMMENT`.
- **`body`**: never empty. GitHub documents it as required for
  `REQUEST_CHANGES` and `COMMENT`, and top-level findings go out through
  `gh pr comment`, so the review has no body unless you give it one.
- **`comments[]`**: `line` is the line in the file at `commit_id`; `side` is
  `RIGHT` for added or unchanged lines, `LEFT` for deleted ones. A comment
  that spans lines, including a multi-line `suggestion`, also needs
  `start_line` and `start_side`, with `line` as the last line.

Always confirm before anything reaches GitHub. Posting a review is
outward-facing and irreversible in practice.

## Recurring checks

Cheap to run, and each has caught a real defect:

- **New top-level directory** → does it have a `CODEOWNERS` entry? A bare
  `/util/` style line with no owners *clears* ownership, so a new module under
  it resolves to zero required reviewers.
- **Commit message and PR body** → check them against the repo's commit style
  guide. Many ban `Co-Authored-By:` AI trailers and "Generated with" footers,
  and some lint for them.
- **Code moved between files or modules** → grep for inbound references to the
  old location. A doc comment pointing at a section that moved is invisible to
  every compiler and every test.
- **A symbol promoted from private to public** → does its null/error contract
  match its siblings? Does anything now direct callers to it?
- **A new dependency** → is it in the production dependencies when only a test
  needs it? Does the module document a closed dependency set it now violates?
- **A new test asserting inherited odd behaviour** → the PR is blessing it.
  Ask for a comment and a ticket, or ask for the row to go.

## Anti-patterns

- **Posting the finder's output verbatim.** It is unverified and written for a
  machine.
- **A comment with no ask.** The author is left to guess the remediation.
- **`[do]` on something you could not verify.** Use `[question]`.
- **Blocking on a one-line fix.** Put it in a `suggestion` block and approve,
  unless it prevents irreversible damage where real data lives.
- **Blocking on a dev or test environment.** Only production, release gates,
  environments holding real customer data, and shared code or config that
  reaches them hold a merge.
- **Single-backtick spans in a terminal presentation.** They render fine and
  copy wrong. Use the double-backtick form.
- **Padding the count.** Ten verified comments beat fourteen with four wrong
  ones; the four wrong ones are what the author remembers.
- **Silently dropping a killed finding.** Say it was wrong and why.
