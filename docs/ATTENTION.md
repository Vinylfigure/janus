# Janus Human Attention Protocol — Version 1

The formal contract for when and how a Janus repo involves its human. Every
machine-consumable issue and every human interruption in this repo follows
this protocol; overlord and any control-plane app parse it rather than
interpret prose. The protocol is deliberately small: sparse labels, stable
headings, canonical comments. GitHub stays the only source of work truth.

**The attention contract.** Every human interruption has one ask, one reason,
one consequence, and a bounded set of actions. An interruption that cannot
state all four is not ready to interrupt.

## Versioning

- The protocol version is the **`janus:v1` label**, applied automatically by
  every issue form. Identity is `janus:v1` + a type label. A hidden body
  comment cannot version form-created issues — GitHub Issue Forms display
  markdown elements in the form but do not submit them into the issue body —
  so the label, which GitHub can query structurally, is the identifier.
- Issues created by an app (not a form) MAY additionally carry
  `<!-- janus:attention:v1 -->` in the body for provenance. It is provenance,
  never the protocol identifier.
- Migration rules, locked now for a future v2: readers MUST tolerate the
  previous protocol version; migration MUST NOT silently alter an unresolved
  human decision; issues written under an old version remain interpretable.

## Type and state

**Type** says what a thing is; **state** says where it is in its life. Labels
stay sparse — most states are derived, not labeled.

| Type | Label | Meaning |
|---|---|---|
| idea | `inbox:` | a thought, not a spec — no done-means required |
| task | `task:` | a unit of ready work carrying its own done-means |
| question | `question:` | a decision only the operator can make |

States: `inbox` → (`ready` → `working` → `verifying` → [`human_check`] →
`done`), with `held` and `blocked` reachable from any working state.

| State | How it is expressed |
|---|---|
| inbox | the `inbox:` label |
| ready | `task:` + done-means present + no gating label + no open blocker |
| working | a `claude/*` branch or open PR references the issue |
| verifying | delivery PR open, checks running |
| human_check | the `human-check:` label |
| done | issue closed by a merged PR |
| held | the `loop:hold` label |
| blocked | `question:`, or an open issue named in `### Blocked by` |

**Legal label combinations.** A type label is required on every protocol
issue; state labels attach only where the table allows. Combinations outside
this table are protocol violations (e.g. `human-check:` on an `inbox:` issue
— an unspecced thought cannot be awaiting operator verification):

| | `loop:hold` | `human-check:` |
|---|---|---|
| `inbox:` | no | no |
| `task:` | yes | yes |
| `question:` | no | no |

`aging` / `overdue` are ladder annotations managed by `fleet-status.sh`, not
protocol state; they may appear on any operator-blocked item.

## The consumption gate

One list, mirrored verbatim in `.claude/skills/work-loop/SKILL.md` (Steps 1)
and enforced observably by `fleet-status.sh`'s "Consumable now" line, which
`test-hooks.sh` fixtures:

Consumable = labeled `task:` AND carries a done-means AND is within the
environment's tool grant AND carries **none** of `question:` / `loop:hold` /
`inbox:` / `human-check:` / `intent:` AND every issue named in its `### Blocked by` field
is closed or resolved AND the issue is **not already `working`**.

Intents live above tasks (overlord protocol `overlord:intent:v1`) and are
never consumable.

That last clause is the half this protocol defined and did not compute for
its first day of life. `working` means an open PR or a live delivery branch
already references the issue — derivable from closing keywords in an open
PR's title or body, and from the issue number embedded in a delivery branch
name. An issue another actor has already started reads "ready" to every
consumer until someone computes it; on 2026-08-21 two sessions built this
protocol nine seconds apart through exactly that hole, producing two
mutually contradictory "version 1"s (L-057). `fleet-status.sh` now computes
it and names the reason on each gated issue, and `scripts/check-ready.sh` is
the gate as one executable statement — it takes `--working` as an explicit
argument precisely so a caller that never asked GitHub has to say so by
omission.

`question:` is not `loop:hold`: hold means "not now"; question means "the
answer is not known yet", and building either branch of an unanswered
decision is wrong regardless of timing (#42).

**Dependencies are explicit.** A task blocked on a decision names it in its
`### Blocked by` field (issue refs: `#123`, `owner/repo#123`, or a full issue
URL). Executors evaluate that field only — never prose references. A
question's `Blocks` heading is for humans reading the question; the dependent
task's `### Blocked by` is what the executor checks.

## Inbox ≠ Ready

An `inbox:` issue is a thought, not a spec: one free-text field, no
done-means. The work loop never consumes it. Its idle arm triages: promote at
most 2 inbox items per firing into `task:` proposals with a drafted
done-means (or into a `question:` when a product decision is needed), and
never execute a promotion in the firing that created it — the gap between
firings is the operator's veto window.

## In plain words — required at filing (v1.1, additive)

Every `inbox:`, `task:`, and `question:` issue form opens with a required
`### In plain words` heading: one sentence, in the operator's own words,
stating what is being asked or what becomes true — no ids, file paths,
backticks, or protocol nouns, 80 characters or fewer and 12 words or fewer.
A `question:`'s line is the question itself, asked, so it ends with `?`.
This is an ADDITION
to the v1 body API, not a rename: every existing heading string in this
document stays byte-identical, so a body written under the original
protocol is still fully valid v1 (the heading is simply absent, and a
reader treats that the same as "not yet in plain words").

**One form, emitted; two, read.** `### In plain words` — an H3 heading, the
sentence on the line below — is the only spelling any form, skill, or
conductor in this fleet writes. The bold-emphasis spelling some earlier
dispatches used, with a colon and the sentence on the same line, is a
reading concession only: `scripts/check-record.sh` still parses it, because
a body already on the record cannot be rewritten, and a surface that failed
to read it would silently mute a card that does have a plain line. Nothing
emits it. The same rule holds for every heading in this document: one
spelling out, every spelling ever shipped in.

**One cap, one file.** The caps are not typed into any check: they live in
`scripts/card-grammar.json` — line 1 of every record's plain words is 80
characters, 12 words, and one sentence, and the recorded ask's own caps sit
beside it. `check-record.sh` and `check-ask.sh` read that file rather than
carrying the numbers, overlord's Goal and Intent checks read
their vendored copy of it, and overlord-ui's renderer imports it, so the
number the filer is held to and the number the card clips at cannot be two
different numbers. The rule is the deny-list's rule, for the deny-list's
reason: `scripts/vendor-grammar.sh <consumer>` copies the grammar, the
vocabulary list and both gates into a consumer by content and re-pins the
hashes; a cap change is a change to this file and the copies follow.

The reading contract: a control surface renders `### In plain words`
verbatim as the card's headline. When it is absent, the surface falls back
to the first sentence of `### Decision` (questions) or the raw title —
and only as a fallback, never a substitute at filing time. A headline that
matches a jargon deny-list (fixture, reconcile, canonical, machine-decidable,
protocol vN, schema, drift, marker, orphan, sha256, a Pn/Rn/Ln/DL- id, a
`goal/N` ref, "Drone", or a backtick) renders muted with the label "not yet
in plain words" rather than showing the raw match — a plain line that reads
as machine prose is treated as no plain line at all.

Filers: this heading is REQUIRED on every `task:`/`question:`/`inbox:`
issue an agent or the conductor files, enforced by `scripts/check-record.sh`
at filing time (`.claude/skills/work-loop/SKILL.md`,
`.claude/skills/plan-feature/SKILL.md`, `.claude/skills/ship/SKILL.md`). A
"go and confirm" request is filed as a `Human check` task (below), never as
a `question:` — a question is for a decision only the operator can make,
not an observation the operator is asked to make on the machine's behalf.

`question.yml` additionally requires `### Options`: 2-4 named answers, one
per line, in the operator's own words. These become the control surface's
buttons; `### Recommended choice` must name one of them, verbatim — a
question without named options is not ready to file, and a surface with no
`### Options` falls back to the first sentence of `### Recommended choice`.

## Question schema — the v1 body API

`question.yml` renders these stable headings; they ARE the machine interface
(parsers key on heading text; a rename breaks a fixture, not an app,
silently):

`Decision` · `Recommended choice` · `Why` · `If you do nothing` ·
`Reversible?` · `Needed by` · `Blocks`

Three further headings — `Parent goal`, `Gates signal`, `Kind` — are
additive v1.1: all optional, appended after the seven above, never
renaming or reordering them. A body without them is still valid v1; a
parser must treat their absence as "no parent goal / no gated signal /
Kind = Decision". `Parent goal` is how a question joins the Goal graph
defined in Vinylfigure/overlord `docs/GOAL.md` (`overlord:goal:v1`).

Two more headings are additive v1.1, required for filers, optional for
readers (see "In plain words — required at filing" above): `In plain
words` and `Options`, in that order, both rendered **before** `Decision`.
The two lines a card needs — the headline and the buttons — are the two
the form asks for first, so a surface never walks the body to find them.
Neither renames nor reorders the seven original headings; a reader must
still treat their absence as valid v1, and a parser keys on heading text,
never on position.

A question arrives with a recommendation — "what should I do?" with no
explored options is an unfinished exploration, not a decision request.

## Task schema — the v1 body API

`task.yml` renders these stable headings; `In plain words` and `Done means`
are required at filing, the rest are optional and additive:

`In plain words` · `Done means` · `Discovered from` · `Blocked by` ·
`Parent goal` · `Human check` · `Priority`

`Parent goal` is additive v1.1 and optional: `goal/<n>`, the same reference
form a question uses (`goal/207` anywhere means Vinylfigure/overlord#207).
It is how a task joins the Goal graph, so a delivered task can be counted
against the goal it was filed under instead of being read as unattached
work. A body without it is valid v1; a parser treats its absence as "no
parent goal", never as an error.

## Human check — the v1 task section

A task whose delivery needs the operator's eyes carries a `Human check`
section with stable sub-headings:

`Surface` · `Instruction` · `URL` · `Pass`

`Pass` is the heading the form now renders — one word, the operator's own,
matching the `Pass` wording the Goal protocol uses for a met signal. The
earlier `Pass criteria` spelling stays READABLE forever: a body written
under it is still valid v1 and `check-record.sh` accepts either, along with
the legacy `Pass:` colon field. Only the producing template changed.

Only delivery applies `human-check:`: the artifact exists, machine work and automated
verification are done, and the operator's experiential check gates the merge.
Drafting a Human check section does not request review. Before labeling, run
`scripts/check-record.sh <body-file> --ready-for-review`; it accepts the canonical
four sub-headings (either `Pass` spelling) and legacy colon fields, rejects missing
criteria and placeholder artifact URLs. Use `scripts/request-human-check.sh` for the label transition: it invokes the
field checker, reads the artifact and successful Actions run, compares PR heads
when the artifact is a PR, rechecks the supplied source version, and writes a
`janus:human-check-request:v1` receipt before applying the label. It is read-only
unless passed `--write`. For other preview URLs, availability and the recorded
verification revision are checked; mapping a preview deployment to that revision
is still the delivering agent's responsibility. A repeat review after a current
human verdict requires evidence from a newer run and
`Supersedes-review-operation` naming that latest verdict exactly, including a
pass that followed an earlier failure. Field validation alone
is not proof of delivery.
A control surface renders `[Open preview] [Pass] [Something's wrong]` from
these fields.

## Lifecycle events for human actions

Human action results are protocol events, encoded as canonical comments plus
label transitions — no event bus. Consumers key on the marker line, never on
accompanying prose (prose is welcome; it is for humans).

- `decision_requested` — a `question:` issue opens (with the v1 headings).
- `decision_resolved` — a comment beginning:

  ```
  <!-- janus:decision:v1 -->
  Decision: accept-recommendation
  ```

  (or `Decision: <named option>`). The `question:` label is removed and the
  issue closed; tasks blocked on it become eligible.
- `human_check_requested` — the `human-check:` label is applied at delivery.
- `human_check_passed` — a comment beginning:

  ```
  <!-- janus:human-check:v1 -->
  Result: pass
  ```

  The `human-check:` label is removed; the task is verified and the repo's
  own delivery/merge process resumes. No external surface merges on the
  repo's behalf.
- `human_check_failed` — the same marker with `Result: fail` plus feedback;
  the `human-check:` label stays and the task returns to working with the
  comment as input.

"Yeah looks pretty good to me!" is a reply to a human; the marker comment is
the event. A surface that records the human's action writes both.

## Canonical comments

Every machine-readable comment opens with its marker on its own first line.
A reader keys on the marker and on the field names under it; everything else
in the comment is prose for humans and is never parsed.

| Marker | Written by | Carries | Read as |
|---|---|---|---|
| `<!-- janus:ask:v1 -->` | any session or engine parking work for the operator | `Ask` · `Because` · `If-nothing` · `Options` · `Supersedes` · `Source-revision` | what the machine needs from the operator, newest wins |
| `<!-- janus:decision:v1 -->` | the surface recording the operator's answer | `Decision:` | a `question:` is resolved |
| `<!-- janus:human-check:v1 -->` | the surface recording the operator's verdict | `Result:` | an experiential check passed or failed |
| `<!-- janus:human-check-request:v1 -->` | `scripts/request-human-check.sh` | `Source-version` · `Operation` · `Artifact` · `Evidence` · `Source-revision` · `Status` | the receipt binding a review request to a delivered revision |
| `<!-- janus:attention:v1 -->` | an app filing an issue outside the forms | — | provenance only, never the protocol identifier |

`<!-- overlord:held-for-operator:v1 -->` is **retired**: read it as a hold
reason (why a session stopped), never as an ask. A record carrying only that
marker has not stated what it needs.

## The recorded ask (`janus:ask:v1`)

The attention contract at the top of this document says every interruption
has one ask, one reason, one consequence, and a bounded set of actions. This
is that contract as a fact on the record rather than as prose a reader has to
infer. A session that parks work for the operator posts one comment:

```
<!-- janus:ask:v1 -->
Ask: <one line, ≤80 chars, opening with a verb from the fixed set>
Because:
- <fact, ≤120 chars>
- <fact, ≤120 chars>            (1–3 lines)
If-nothing: <one line, ≤120 chars>
Options: <Name A> | <Name B> [| <Name C> | <Name D>]   (2–4 names, ≤30 chars each)
Supersedes: <the previous ask's comment id on this record, or none>
Source-revision: <head sha for a PR, or the record's updated_at timestamp>
```

The fixed verb set for `Ask:` — **Approve · Answer · Do this · Confirm it is
done · Close or re-spec · Merge**. Six phrases, not six opening words:
`Approve`, `Answer` and `Merge` carry the rest of the sentence, while `Do
this`, `Confirm it is done` and `Close or re-spec` appear verbatim before
theirs. A reader turns the phrase into a button without parsing the sentence,
and "Close it immediately without review" is free prose wearing a legal first
word — `scripts/check-ask.sh` rejects it.

The six rules:

1. **Newest wins.** The ask in force is the `janus:ask:v1` comment with the
   latest creation time. `Supersedes:` is informational — a parser never
   needs it to resolve which ask is current. A change of mind is a newer
   ask, never a retraction a reader has to reconcile.
2. **Vocabulary.** `Ask:`, `Because:` and `If-nothing:` pass the fleet
   deny-list: no issue or pull request numbers, file paths, script or
   function names, branch or label names, permission keys, config fields,
   command syntax, ids of the rule / decision / goal form, and none of the
   machine's own nouns for its own workings. Glossary nouns are carried
   verbatim. `scripts/check-ask.sh` is that list, executable — the emitting
   skill runs it on the drafted body **before** posting, and a failing ask
   is not posted at all.

   **The list is one file, and it lives here.** `scripts/deny-list.json` is
   the fleet's single source: `version`, `identifiers` (regular expressions,
   matched against the field padded with spaces so none needs an anchor),
   `machine_words`, `hedges`, and `artifact_subjects`. `check-ask.sh` reads
   the file rather than carrying a copy of the words, and the fixture suite
   proves it by swapping the file and watching the rules change. Overlord
   and overlord-ui **vendor this file by content** — a byte copy, not a
   re-typing — and each ships a test asserting its copy equals this one.
   Three lists that drift apart is the failure this replaces: an ask that
   passes in the repo that wrote it and fails in the surface that renders
   it is worse than no check. Adding a word is a change to this file, and
   the vendored copies follow.
3. **The subject is never the artifact.** "The check refused a repository
   that was configured correctly" passes; a line opening with any entry in
   `artifact_subjects` — "This PR…", "This pull request…", "This issue…",
   "This change…", "This record…" — fails. The operator cares what became
   true, not what a diff contains.
4. **No hedges.** `may`, `might`, `probably`, `seems`, `perhaps`, `likely`
   are rejected, in any casing and as whole words. An uncertain fact is
   left out; a fact stated is a fact checked.
5. **Who posts one.** Any session or engine that leaves a PR in draft for
   the operator, or holds one (a hold comment gains an `Ask:` line and is
   read as the ask when no `janus:ask:v1` exists), or changes its mind. A
   `question:` or `human-check:` record needs no marker: its `### In plain
   words` + `### Options` (or `### Instruction` + `### Pass`) already are
   the ask, which is why those two headings are the first the forms ask for.
6. **Retired marker.** `overlord:held-for-operator:v1` is a hold reason, not
   an ask. A held record with neither a `janus:ask:v1` comment nor a hold
   comment carrying `Ask:` has not stated what it needs, and a surface says
   exactly that rather than guessing from the thread.

## What a card renders

The render contract every control surface inherits, so a card is assembled
from record fields rather than summarized from prose. Source order is
first-hit-wins, left to right:

| Card line | Rule | Source order |
|---|---|---|
| Headline, ≤80 chars | "<subject> is <state now>" — who is stuck, never the artifact | the operator's own wording → `### In your words` → `### In plain words` → newest ask's `Ask:` → a summarizer's guess, marked inferred → the raw title, muted |
| Your part, 1 line | one verb from the fixed set: Approve / Answer / Do this / Confirm it is done / Close or re-spec / Merge | goal → Approve; question → `### Options`; human check → `### Instruction`; PR → newest ask's verb, else a summarizer's guess, marked |
| What yes does / cost of nothing, 1 line each | what becomes true, and what stays broken | `### If you do nothing` → newest ask's `If-nothing:` → the hold's consequence → the fixed line for that kind |
| Buttons | the actions themselves, never a menu | question `### Options` → human check It works / Needs work → newest ask's `Options:` → the fixed set for that kind |
| Read more, ≤4 facts | statements, each traceable to the record; vocabulary rules above | newest ask's `Because:` lines, then failing checks under their plain-language names |
| The checks | the check's id translated to its plain meaning | the fleet check glossary, sourced from the workflow files — a raw check id never reaches a card |

Two marks are part of the contract, not decoration: a card built from a
summarizer rather than a stated ask carries "machine guess, not stated by
the agent", and a held record with no ask at all renders "the agent did not
say what it needs" as its headline, with "Send it back" as the only action.
Non-compliance is a visible signal; it is never a plausible headline.

## Label vocabulary

Created idempotently by `fleet-status.sh` and declared in git by the forms in
`.github/ISSUE_TEMPLATE/`:

| Label | Kind | Meaning |
|---|---|---|
| `janus:v1` | protocol | this issue speaks Attention Protocol v1 |
| `task:` | type | unit of ready work — carries a done-means |
| `question:` | type | blocked on an operator decision |
| `inbox:` | type | a thought, not a spec |
| `human-check:` | state | operator's eyes required before merge |
| `loop:hold` | state | the work loop must not take this |
| `aging` / `overdue` | ladder | >3d / >7d without a response |
| `dashboard` | plumbing | the regenerated status dashboard issue |

The fleet dashboard renders `Blocked on operator` (questions), `Awaiting your
check` (`human-check:`), `Backlog` with its "Consumable now" gate line, and
`Inbox` (count and titles — informational, never urgent).
