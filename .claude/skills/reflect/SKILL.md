---
name: reflect
description: Distill this session's lessons (corrections, verification failures, surprises, wasted paths) into structured entries in .claude/memory/LEARNINGS.md. Use at session end, after a correction, or when the Stop hook asks for it.
---

Runs in the main thread only — never delegate this to a subagent. Only this
thread holds the session transcript, and the transcript is the raw material.

## Hold in mind

Restate these in your own words before step 1:

1. A lesson is an imperative *rule* — one concept, testable — not a story about what happened.
2. Capture the trigger (the concrete event), because future readers need to know when the rule applies.
3. Duplicates strengthen, not multiply: an existing equivalent entry gets its Evidence bumped, never a twin.
4. `Scope: portable` means the rule is true in any repository, not just this one — judge honestly; portable entries are inherited by every child project.

## Steps

1. Scan this session for learning events, in two passes:
   - **Transcript pass**: user corrections, verification failures, surprises (things that worked differently than you assumed), wasted paths (approaches abandoned after real effort).
   - **Signals pass**: read `.claude/memory/.session-signals` if it exists — each `correction:` and `verify-fail:` line should be accounted for by an entry or an explicit "no lesson" judgment.
2. For each event, decide: is there a rule here? Some failures are noise (typo, flaky network). Say so in one line and move on — do not manufacture lessons.
3. For each real lesson, check `LEARNINGS.md` for an equivalent entry (grep for key terms). If found: increment its `Evidence` count and update its date. If not: append a new entry after the `<!-- entries below this line -->` marker, using the format spec at the top of the file. Next ID = highest existing L-NNN + 1.
4. Delete `.claude/memory/.session-signals`.
5. If any entry now has `Evidence: 2` or more, tell the user: "N learnings have enough evidence to promote — run /evolve when convenient."

## Before finishing

Read back each entry you wrote and confirm out loud: each is an imperative rule
(not a narrative), one concept, with an honest Scope. State how many signals
you processed and how many became entries vs. were dismissed as noise.
