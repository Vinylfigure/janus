---
name: respond-to-operator
description: Act on an operator note (a comment beginning `<!-- overlord:operator-reply:v1 -->`) on a `question:` or `human-action:` record — refine the record and re-ask; never decide, close, or relabel.
when_to_use: Use when the triggering comment carries the operator-reply marker or the system prompt says "Operator note mode".
effort: high
---

The operator typed a note into the app instead of tapping an option. The
app posted it as a comment with the marker and the agent mention, so this run
exists only to act on that note. The record stays the operator's: the run
improves the question, it never answers it.

This skill is identical in janus (the template), overlord and overlord-ui —
edit it in janus and copy it verbatim; a divergent copy is a drift finding.

## Hold in mind

1. A note is never a decision. Only a `<!-- janus:decision:v1 -->` comment the
   operator's own surface writes (with `Operation:` and `Action-version:`
   trailers) counts as decided; one this run writes has no trailers, reads as
   `prerequisite_receipt_missing`, and misleads every reader in between.
   Never post that marker. Never close the issue. Never add or remove a label.
2. Never mention the coding agent in anything you write. The dispatch bus
   allows the app's bot to trigger it; a mention echoed by this run would
   trigger the bus again on your own comment.
3. The body edit changes the record's version, so a decision the operator
   armed on the old options is refused as stale and they see the new
   options. That is intended. Keep every existing option id so an option
   they already read is still on the record.
4. Edit only `### Options` and `### Recommended choice`. Every other heading
   is the filer's, and the `### In plain words` line is pinned by
   `scripts/check-record.sh`.

## Steps

1. Read the record and its comments. The note is the LAST comment whose first
   line is `<!-- overlord:operator-reply:v1 -->`; an optional `Reply-kind:`
   line follows the marker. Ignore earlier notes and every receipt comment
   (`<!-- overlord:human-action:v1 -->`).
2. Decide what the note changes about the question:
   - It names a possibility the options lack (a third route, a different
     scope, an existing resource) → add ONE option for it.
   - It supplies a fact that changes which option is best → update
     `### Recommended choice` to that option's label, verbatim.
   - It asks something → answer it in the reply comment (step 4); options
     unchanged.
   - It reads as a decision ("go with the second", "do X") → do not record
     it; in the reply, say exactly which option to tap so one tap finishes it.
3. For a `question:` record, rewrite `### Options` in the declared grammar,
   one option per line, 2–4 options, ids stable:

   ```markdown
   ### Options
   - [convert-account; resolved] Convert the account to an organization — keeps the name and URLs; the personal account is consumed
   - [transfer-existing; resolved] Transfer the repositories to absentoperator — URLs change, GitHub redirects; reversible by transferring back
   - [not-now; deferred] Not now, ask again in a month — each new repository keeps needing its own token copy
   ```

   Unannotated existing options gain an id (kebab-case from the label) and an
   effect: `resolved` permits the dependent step, `denied` refuses it,
   `deferred` postpones it. Then set `### Recommended choice` to one label
   verbatim. Write the new body to a file and apply it with
   `gh issue edit <n> --body-file <file>`; run `scripts/check-record.sh` on
   the file first when the repo ships it.
4. Post exactly one comment: what changed (the option added or the
   recommendation moved, or "options unchanged"), the answer to anything the
   note asked, and one sentence asking for the tap. No marker line, no
   mention, no trailers.
5. For a `human-action:` record (the operator said they are blocked), answer
   the blocker in one comment with the specific next step; never edit the
   record's `Completion` condition and never post a
   `<!-- overlord:human-work-result:v1 -->` comment — that is the operator's.

## Before finishing

State: which comment you treated as the note; the option added or the
recommendation moved, or that neither changed and why; that exactly one
comment was posted and it carries no marker and no agent mention; that the
issue is still open with its labels untouched.
