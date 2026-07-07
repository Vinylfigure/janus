# How Janus improves itself

The scaffold treats every session as training data and every project as a
generation. This document is the lifecycle spec — what counts as a lesson,
how a lesson earns promotion, and how knowledge crosses repositories.

## Lifecycle of a lesson

```
signal ──► entry ──► evidence ──► promotion ──► inheritance
(hooks)   (/reflect)  (recurrence)  (/evolve)    (/replicate)
```

**1. Signal.** Hooks log learning-shaped events silently as they happen:
`prompt-signal.sh` flags correction-looking prompts, `post-edit-verify.sh`
flags verification failures. Both append one line to
`.claude/memory/.session-signals` and say nothing — signals are cheap and
false positives are harmless.

**2. Entry.** At stop time, if signals exist, the Stop hook blocks once and
asks for `/reflect`. Reflect reads the transcript plus the signal log and
writes *rules* to the ledger — imperative, one-concept, testable. Noise
(typos, flaky network) is explicitly dismissed, not recorded. An equivalent
existing entry gets its `Evidence` count bumped instead of a duplicate.

**3. Evidence.** Nothing promotes on one occurrence — one occurrence is an
anecdote. `Evidence: 2` (or explicit user confirmation) is the threshold.
The session-start hook surfaces ripe entries so they don't rot.

**4. Promotion.** `/evolve` (analysis delegated to the `memory-curator`
agent) moves qualifying lessons up:
- Rule-shaped → a bullet in CLAUDE.md's `janus:rules` block, citing its id.
- Procedure-shaped → a skill, via `/add-skill` (procedures load on demand;
  rules must not).
- It is also the garbage collector: rules contradicted by newer entries are
  retired, and the CLAUDE.md caps (≤20 concepts, ≤12 rules) are asserted at
  the end of every run. **Adding requires room; room comes from merging or
  retiring.** The budget rationale is in
  [ARCHITECTURE.md](ARCHITECTURE.md#the-global-workspace-rationale).

**5. Inheritance.** `/replicate` copies `Scope: portable` entries (and their
promoted rules) into child repositories, re-marked `Status: inherited`.
Children re-earn promotion with their own evidence. Ledger entries are never
deleted — `promoted`/`retired`/`inherited` markings keep the full lineage
history, which is what makes the ledger a genome rather than a notebook.

## Ledger integrity rules

- One entry = one concept. Two-sentence rules are two entries.
- `Scope: portable` is a promise: true in *any* repository. Judge harshly —
  a wrongly-portable entry pollutes every descendant.
- Never delete; mark. History is data.

## Improving Janus itself (dogfooding)

The template repository runs its own loops. Working *on* Janus — editing
hooks, skills, agents — generates signals, reflections, and promotions
exactly like feature work in a child project, and improvements committed
here flow to every future child. Two rules keep that safe:

1. A change to a cap, hook protocol, or skill shape must update
   [ARCHITECTURE.md](ARCHITECTURE.md) in the same commit — the rationale doc
   is what stops future sessions from "simplifying" load-bearing constraints.
2. Prove loop changes with the fixture tests before committing: pipe sample
   hook JSON into each script and check exit codes and output (see the
   Verification section of the original build plan, or just read the hook
   headers — each documents its contract).

Existing children do not auto-update; they inherit at replication time only.
To backport an improvement to a child, cherry-pick the commit or re-run the
relevant part of `/replicate` by hand.
