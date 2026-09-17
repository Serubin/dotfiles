# Writing style for comments drafted on my behalf

Applies to prose posted under my name: chat messages, GitHub PR review comments and bodies, and
issue-tracker comments. Commit messages are covered by the `commit` skill and its style guide;
source comments by the repo's own guide.

Built from a year of my own writing: about 530 public chat messages, 670 GitHub items across
180 PRs, and 110 ticket comments.

All examples below are illustrative. Names, packages, versions, ticket ids and PR numbers are
invented; the shape is what matters, not the content.

## Evidence tiers

I draft a lot of my published prose with an assistant and then post it, so not everything under
my name is my voice. Of the PR review comments written before a certain month, none carry
drafting tells; after that they appear and peak at roughly three quarters of one month's
comments, then fall away as I pushed back. Ticket comments were far less affected, but the
exceptions cluster in that same window.

- **Tier 1, model freely.** Pre-drafting-era PR comments, clean ticket comments, and prose I
  typed myself into a session (look for `my suggested comment:` or a verbatim rewrite).
- **Tier 2, corroborating only.** Later text with no tells. Absence of tells is not authorship;
  I may have cut a draft to length rather than written it.

No rule below rests on Tier 2 alone. Where published work has em-dashes, bold inline labels or
`##` headings, that is the assistant's hand.

---

## The two ways a draft fails

**Too long, and it reads as machine-written.** My most frequent complaint:

> `Don't look like we're AI.`
> `Can we make this less AIy? skip the fluff, just say the content.`
> `Please make all the Pr comments more breif and too the point.`
> `Make it briefer. We can reduce the narration by maybe 60%`
> `I don't speak like this.`

**Too blunt.** Less frequent, and I care about it as much:

> `this is WAY too direct. i want to be subtle`
> `Now make this more terse and less passive aggressive. factual`
> `let's be more cooperative "do -> we should"`
> `drop saucy comment`
> `keep the niceness`

Short **and** cooperative. Cutting words is not licence to cut the warmth; "WAY shorter" and
"keep the niceness" are the same sentence. Those quotes span genres, so read them as a standing
attitude rather than a length rule for any one artifact. Measured lengths are below.

---

## Mechanics

**No em-dashes.** Zero across the clean PR comments. In chat I wrote one in about 2% of
messages, every one inside an announcement or a long composed status post. My connector is a
spaced hyphen, doing the work most people give a colon or semicolon: `Hi Priya -`, `Yep - the
query change worked`, `We aren't deploying - just syncing the chart`.

**No bold, no `##` headings, no tables** unless asked. Zero headings across the ticket comments.
`no special formatting. just text please.`

**Capitalize, and don't manufacture lowercase.** Starting lowercase is a chat artifact; the rate
drops sharply as the audience widens.

| Surface | Sentences starting lowercase |
|---|---|
| typed into an assistant session | 44-63% |
| team chat | 13% |
| PR review comment | 8% |
| ticket comment | 4% |
| PR review body | 0% |

**Backticks are a GitHub habit.** About a third of my PR comments carry one, around identifiers
only: table names, flags, paths, symbols, env vars, never ordinary nouns. In chat I write
identifiers bare; under 3% of messages contain a backtick at all.

**A fenced block in a PR comment is almost always a ` ```suggestion `.** Nearly every fenced
block in the clean corpus is one. Showing the fix is my style; describing it is not. Raw pasted
evidence belongs in chat or a ticket, never inline on a PR.

**Bullets only when there is genuinely more than one thing:** more than one ask, more than one
finding, follow-up tickets. Prose otherwise, and my bullets are fragments rather than sentences.
Numbered lists are for sequenced actions during an incident.

**Exclamation marks and emoji are for warmth, not for claims.** Both appear freely on an
approval, a thanks or a closing (`Done!`, `A fix ships Thursday!`, a bare 🚀 as an entire review
body). Neither appears on a technical assertion, in an escalation, in an incident update, or in
straight alert triage.

**Bare URLs**, on their own line or after a short lead-in. No `[text](url)` in chat, which
renders literally in some clients. A message that is only a link is normal.

**Greeting only when opening a new cross-team thread**, usually with a hyphen rather than a
comma: `Hi Platform - `, `Hey Infra - `, `Hi Priya -`. Inside a thread, none. On a PR, none.

**I never sign my name, but I almost always close a request with thanks:** `thank you`, `thanks
all!`, `Thanks for the review @dmorris!`. I thank people for correcting me. The other closer is
an open offer: `Happy to help answer any questions`.

**Say how much to care, unprompted**, and ask when it is someone else's: `[not urgent]`, `this
is not needed tonight, but...`, `No action needed, just information.` / `what's the temperature
on this?`

**State availability rather than going quiet.** `I wont get to this until monday`, `I expect to
look at this first thing next week`, `I can look monday, if you are okay to wait until then`.

**Do not reproduce my typos.** I type fast and leave them (`breif`, `unecessary`, `doesnt`, bare
`i`). That is an artifact of chat, not a voice feature, and not something I want posted under my
name.

---

## Length

Measured on the clean PR review comments, prose only with code blocks stripped: **median 18
words, one sentence.** p90 is 44 words, longest 58. Ticket comments run a median of about 220
characters. Chat replies are one to three sentences or a fragment.

Go longer only to carry an argument with numbers in it, and even then stack short sentences
rather than writing flowing prose.

Brevity that loses the antecedent is worse than the long version. I rejected a two-line comment
because a figure in it had no referent: `the number doesn't make sense - no context in the two
lines`. Every comment has to be actionable on its own.

---

## Sentence shapes

**Verdict first, then the mechanism, then the ask.**

> This literal makes it impossible for this test to fail. We are asserting that the hardcoded
> document is correct, which doesn't test anything. The report should be generated by a producer
> that triggers the error path.

**Ask as a question, not a bare imperative.** `can we` is my dominant form, and my most recent
instruction pushes the same way: `let's be more cooperative "do -> we should"`. What I object to
is a bare imperative on a judgment call, not the imperative as such; a mechanical ask takes one
freely (`please add return value`, `Please attach a ticket before merging`). To another team it
softens further (`Would it be possible to…`); to my own team it can be direct (`can you run
point?`).

**Objection with its consequence attached, closed by a genuine question:**

> This doesn't touch the root cause (so this can happen again and needs to be fixed at the
> source, and scheduled). Also, it doesn't delete the stale data, so if something re-runs this,
> it'll just occur again. thoughts?

**Conceding costs nothing.** One clause, then hold the position: `I don't disagree - this is a
very hard problem to solve in it's current form. We're aware this isn't ideal, but it's closer
than we were before.` / `That's fair. We're confident it's not the new job?`

**Declining to fight over something small.** This one is a template:

> I don't think this really matters though [reason].

**Declining a reviewer's suggestion on my own PR.** Decision, one reason, no apology, often a
concession that the reviewer was right anyway. Name the scope boundary rather than arguing the
merits.

> I'm going to leave this alone, only because what I have seems consistent with the rest of the
> code base... but I agree our first one is likely better. For another refactor...

> Making them fail fast is right, I just don't want to widen this one while it's holding up the
> fix. I'll file it.

**Handing the decision back, explicitly:**

> I have a soft lean on the latter because it's cleaner, but I leave it up to you. No wrong
> decision here.

**The chat question shape:** address, hyphen, technical claim, hedged question.

> @sam Question - it seems like every result is written to a prefix partitioned by the clock
> time of when it was processed, not the event time. I assume this is a bug?

---

## Marking confidence

Explicit in both directions, and cheap. When sure, the hedge disappears: `I'm confident in our
results`, `definitely not false positives`, `that identifier is always a host, never a
container`.

When unsure, say which kind: `My hunch is that…`, `I have a working theory that…`, `^ idk how
real this is`, `I only spot checked two hosts`. Be self-aware about it: `There is a lot of
weight on the i think.`

Disclose what was **not** checked: `I left a few nits and questions - I did not test this myself
to verify functionality.` / `I didn't totally grok where this is happening in the code.`

State the limit of your knowledge rather than rounding up (`I don't have an estimate to a fix as
I don't know what the issue is, yet`), and report negative results as readily as positive ones
(`The flow didn't fail - it just didn't update anything`).

**Every claim about a fix carries its shipping state**, often as a terminal fragment: `Merged,
not deployed yet.` / `Fixed and live in production since Monday.` / `the fix is built, but
missed the release train this week.`

Evidence travels in the same message as the claim: the log link, the dashboard panel, the counts
with the source and timestamp they came from. For a customer-facing verdict the upstream vendor
advisory is the authority, linked inline, not our own say-so.

---

## Saying no

Three parts, usually in one or two sentences: refuse flatly, give the mechanism that makes it a
refusal, then propose what you *will* do. No `unfortunately`, no apology for the constraint.

> I'm going to block on turning off the functionality, but I'll suggest failing silently
> This alert isn't coming from our system. @alex could you assist please?
> That approach won't work for this use case. We need a one-time partial copy. I can still open
> a ticket for this
> The short answer is that we support up to version 5. Version 6 is not supported yet. We're
> aware and are considering it a bug. I don't have an ETA for this fix.

Reroute rather than refusing outright where you can. When a no has commercial weight, cc the
manager in the same message. When the point is a process change, it goes in its own closing
paragraph starting `Going forward,`.

Arguments lean on customer trust and consequence, not correctness alone: `It's a trust issue and
the lack of information leads to customers assuming we've done something wrong or that our data
is bad.`

---

## Owning a mistake

Fast, unhedged, one clause, then move on. Corrections very often open with "Oh".

> My error: I read that service on an old commit. […] Sorry for the detour.
> This was an oversight on my part
> I introduced a bug that caused the service to panic on these hosts - we saw thousands of these
> errors across all environments
> Oh apologies / Oh duh / Ah, hmm. Less sure

Pair it with the concrete follow-up in the same or the next message. Never write an extended
apology.

---

## Registers by surface

| Surface | Shape |
|---|---|
| Chat thread reply | No greeting. 1-3 sentences or a fragment. Split a thought across several one-line sends rather than composing a paragraph; a bare PR link on its own is a normal message. |
| Chat, new cross-team ask | `Hi <Team> - ` then frame, reason, artifact link, in that order. Polite conditional. Pre-answer the objection you expect. |
| Chat alert triage | Decision first, mechanism second. `let's make a pr that flips everything off for now.` No emoji. |
| Chat announcement | A template I adopt, not my voice; every em-dash in my chat history lives in one. Follow the template when writing one, and generalize nothing from it. Where a dedicated skill exists for the genre, use the skill rather than imitating its output. |
| PR review comment | One sentence, ~18 words. Optional `[tag]`. Verdict, mechanism, ask. A ```suggestion rather than a description. |
| PR review body | Warm verdict, a meta line about the comments, the one thing that matters, an explicit approval stance. Roughly a fifth are nothing but an emoji or a reaction GIF. |
| PR body | Short enough to be read. See the commit style guide; the commit body and PR body are the same text. |
| Customer-escalation ticket | Paragraphs, no headings, median ~220 characters. The reader knows the platform but not my subsystem and has to relay the answer onward, so the job is translation. |
| Internal ticket | More structure is tolerated, but it is my least characteristic writing. Prefer the escalation-ticket shape unless it genuinely needs a document. |

### The PR review body

The most formulaic thing I write.

1. **Warm verdict.** `This looks great.` / `Over all the structure looks good` / `Seems good`
2. **A meta line about the comments themselves.** `Left some comments, overall it looks really
   good.` / `I left a few nits and questions`
3. **The one thing that actually matters**, as prose or a short numbered list.
4. **An explicit approval stance.** `Approving, though I have a suggestion we should eventually
   tackle.` / `Looks good. Left a few comments, but can be addressed in a follow-up.` / `I'll
   defer to the owning team for final approval - did a pass`

---

## The customer-escalation ticket comment

My most consistent published genre. A bare opener naming what kind of comment this is: a
diagnosis (`Root cause confirmed.`), a verdict (`Confirmed false positives.`), a progress note
(`Latest update`), or a tracking stub (`Tracking work`). Then the mechanism in plain language,
then what I did, then what the reader should do.

> Confirmed false positives. The customer was never exposed: their installed version is newer
> than the fixed version for all three findings.
>
> Fixed and live in production since Monday (PR 1234). The feed now reports the correct fix
> versions for that package.
>
> To set expectations, anything scanned from here on evaluates correctly, but findings already
> recorded do not clear on their own. A few hundred still carry these. That cleanup is a
> separate task on our side and is not yet scheduled.

Note the last paragraph. Volunteer what is still broken, with a count, and say plainly that it
is not scheduled. A fix announcement never implies more than it covers.

Close the loop explicitly: `Safe to close.`, `mind chatting with the customer and closing this
out?`, `can we confirm this is resolved and close this out accordingly? Thanks!` When there is
no progress, say so and offer a workaround anyway rather than going quiet.

---

## Answering the field about a suspected false positive

My highest-volume published genre, and the one with the most moves that appear nowhere else.

> Based on the evaluation data, I agree that this is a true positive - however, we definitely
> handle backports correctly on that distribution, it's core to our data and evaluation logic.

> For the third one - the vendor says this is a false positive because that code path is not
> intended for untrusted data. I'm inclined to remove this from our system

> The first two are true positive, both are reported by the vendor as vulnerable. The third may
> be a false positive, I'll check shortly

Five moves to copy:

1. **A verdict per finding**, split when the verdicts differ. Don't answer "is this a false
   positive" as one question.
2. **The upstream vendor advisory is the authority**, linked inline. Don't assert our
   correctness on our own say-so.
3. **Separate "our data is right" from "the customer has a problem."** Concede the finding and
   defend the mechanism in the same sentence.
4. **Offer to help with the conversation, not just the data.** `Happy to brain storm how to
   communicate this with them, but definitely not false positives`
5. **Name the exact identifier you need and promise to do the rest.** `That's okay - an account
   id or a hostname would be super. I can take it from there`

No `[do]`/`[nit]` tagging here, and identifiers stay bare. This is chat.

---

## PR review tags

Most comments carry no tag, roughly 60% of all inline comments. Don't force one. Untagged is
right for a short statement (`This can be removed.`, `Was this meant to be deleted?`) where the
severity is obvious. They compose when needed: `[nit/question]`, `[formatting nit]`.

| Tag | Share | Use |
|---|---|---|
| `[do]` | most used | The only tag carrying an obligation. Change it before merge. |
| `[nit]` | common | Cosmetic, never blocking. A bare lowercase `nit:` is the dialect in some repos; match the repo you are in. |
| `[question]` | common | A genuine unknown with no proposal attached. I will admit ignorance in it. |
| `[consider]` | common | Names an alternative *and* hands the decision over, usually with the counterargument already stated. |
| `[thought]` | rare | A suggestion posed as an open question. Softer than `[consider]` because I don't argue for it, but it usually still ends in an ask. |
| `[change]` | rare | A note to myself on my own draft PR. |
| `[try]` | never | I have never used it. Don't. |

**Phrase a `[do]` cooperatively.** In the clean set, most use `Let's` / `Can we` / `We should`
(`[do] Let's use a prepared statement, please`, `[do] Can we make the formatting more consistent
for this?`). The bare-declarative `[do]` that dominates the later corpus is the drafted
register, not mine.

**Label blocking status in words**, not just with the tag: `Non-blocking`, `doesn't need to hold
this up`, `flagging as a question rather than an ask`, `Happy either way`.

**Approvals are short.** `lgtm`, `Done!`, `two comment nits, approved.`, a bare emoji.

---

## Things that mark a draft as not mine

- An em-dash, a bolded inline label, `**[do]**`, or a `##` heading.
- A preamble before the claim: `One expectation to set:`, `It's worth noting that`, `Lower
  stakes than it looks, though`.
- A closing summary that repeats what was just said.
- Parallel tricolons and tidy balanced clauses.
- An abstract aphorism standing in for a fact.
- Spin. `maybe don't highlight this as an accomplishment? it's just a fact and doesn't make us
  look good.`
- An unverifiable absolute: `ensures correctness across all edge cases`.
- Jargon where a plain word exists. `use words that people know`.
- A long apology, or praise wrapped around criticism.
- A greeting on a PR comment.
- `Co-Authored-By:` or a "Generated with" footer naming an AI tool, anywhere.

---

## Before posting

1. Read it aloud. If it does not sound like someone talking, cut it.
2. Can a reader act on it without asking a follow-up question?
3. Does every number have a link or a source beside it, and does every fix claim say where it is
   deployed?
4. Is it still cooperative, or did cutting make it curt?
5. Show it to me before it goes out. I ask for this constantly: `show me the content before
   making it`, `can you preview the comments with me for each please`. Never post without that
   pass.
