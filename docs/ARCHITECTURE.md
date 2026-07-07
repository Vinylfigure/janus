# Janus architecture

How the pieces connect, the exact hook protocol, and the research the design
choices come from. Read this before changing hooks, caps, or skill shapes —
several "arbitrary" numbers here are load-bearing.

## Component map

```
CLAUDE.md                     always-on memory (≤20 concepts; sentinel-marked blocks)
.claude/
  settings.json               hook wiring + safe-command permissions
  hooks/                      4 shell hooks (protocol below)
  skills/                     10 skills — load on demand (progressive disclosure)
  agents/                     2 subagents — run in their own context windows
  memory/LEARNINGS.md         append-only learnings ledger (git-tracked)
  memory/recalibrated-at      committed epoch stamp of the last /recalibrate run
scripts/
  verify.sh                   quick|full dispatcher; /bootstrap fills the case arms
  test-hooks.sh               fixture suite for the scaffold plumbing — hooks + docs cross-refs (verify.sh full + CI)
.github/workflows/verify.yml  CI: runs test-hooks.sh on every push/PR
```

Sentinel markers give skills deterministic edit targets:

| Marker | File | Written by |
|---|---|---|
| `<!-- janus:facts:start/end -->` | CLAUDE.md | `/bootstrap`, `/replicate` |
| `<!-- janus:rules:start/end -->` | CLAUDE.md | `/evolve`, `/replicate` |
| `# janus:bootstrap:quick|full:start/end` | scripts/verify.sh | `/bootstrap` |

## Hook data flow

All hooks receive JSON on stdin, degrade to no-ops without `jq`, and emit as
little as possible — hook output lands in always-on context, which is a
budgeted resource (see rationale below).

```
SessionStart      session-start.sh      → ≤3 short lines: bootstrap status, leftover
                                          unprocessed signals (→ consider /reflect), ripe-learnings
                                          count, recalibration staleness (only once
                                          bootstrapped; stale = recalibrated-at missing or
                                          >30 days — epoch lives in the file's CONTENT
                                          because git does not preserve mtimes across clones);
                                          when source == "compact": one extra line telling the
                                          agent to re-verbalize its working set (invariants +
                                          "done means") — compaction is exactly when the
                                          workspace was disrupted
UserPromptSubmit  prompt-signal.sh      → silent; correction-looking prompts append
                                          "correction:<ts>" to .claude/memory/.session-signals
PostToolUse       post-edit-verify.sh   → runs `verify.sh quick <file>`; on failure appends
(Edit|Write)                              "verify-fail:<file>" to .session-signals and exits 2
                                          with the output on stderr → Claude iterates
Stop              stop-reflect-nudge.sh → if .session-signals is non-empty AND no
                                          .nudged-<session_id> marker exists: touch the marker
                                          and emit {"decision":"block","reason":"…run /reflect…"}
                                          — blocks at most once per session by construction
```

Marker files (both gitignored): `.session-signals` is the per-session event
log, deleted by `/reflect`; `.nudged-<session_id>` is the once-per-session
guard, so an ignored nudge never becomes an infinite loop. By contrast,
`recalibrated-at` is **committed**: it is provenance, not runtime state — a
headless heartbeat recalibrating in a cloud clone must be able to reset the
staleness signal everywhere via its PR.

Deliberately unused events: `PreToolUse`, `PreCompact`, `Notification`,
`SubagentStop` — nothing in the template earns them yet. Add hooks only with
a purpose, and keep their output inside the budget.

## The global-workspace rationale

Anthropic's interpretability research on the [global workspace in language
models](https://transformer-circuits.pub/2026/workspace/index.html) found
that models maintain a limited-capacity workspace of ~10–25 simultaneously
active concepts used for deliberate reasoning, that *verbalizing* a concept
activates its workspace representation, and that intermediate articulated
reasoning causally drives conclusions — while routine processing happens
outside the workspace entirely.

Janus turns each finding into an enforced convention:

| Finding | Janus mechanism |
|---|---|
| ~10–25 active-concept capacity | CLAUDE.md hard budget: 1 bullet = 1 concept, ≤20 total, ≤12 learned rules; hooks inject ≤2 lines; `/evolve` asserts the counts every run |
| Verbalization activates workspace representations | Every skill opens with **Hold in mind** — 3–5 invariants the agent restates before acting |
| Articulated intermediate reasoning drives conclusions | Skills end with **Before finishing** (state what was verified + evidence); `/verify-loop` requires a one-sentence failure diagnosis before each fix; the verifier demands pasted output and must articulate a counterfactual — one way green could still be wrong — before any PASS |
| Workspace representations generalize across tasks | Learnings are distilled as one-concept imperative *rules*, not narratives, so they transfer between tasks and (via `Scope: portable`) between repositories |
| Routine work happens outside the workspace | Progressive disclosure: skill bodies load only on use; clean sessions get no Stop-hook ceremony; exploration and verification are delegated to subagents so their context never enters the main thread |

Honesty note: the paper is interpretability research about *internal*
representations. It makes no claims about agent harnesses, external memory,
RAG, or knowledge graphs — the mapping above is Janus's inference, and the
paper is convergent evidence for the small-active-set bounds, not a
prescription. Treat it accordingly when citing it.

This is why the caps are hard: every concept added to CLAUDE.md competes for
the same limited workspace the model needs for the actual task. When `/evolve`
refuses to add a rule without retiring one, that is the design working.

## The memory pipeline (J-brain)

Learning crosses sessions through three tiers, all native Claude Code
mechanisms — no external dependency. Retrieval is just-in-time at every
tier: indexes load, bodies are pulled when relevant.

| Tier | Mechanism | Scope | Loads |
|---|---|---|---|
| Rules | `CLAUDE.md` (≤20 concepts) + path-scoped `.claude/rules/*.md` | git-shared | always / when matching files are touched |
| Genome | `LEARNINGS.md` ledger (reflect → evolve → replicate) | git-shared | only by the memory skills |
| Ambient | native auto memory (`MEMORY.md` index + topic files) | machine-local | index each session; topic files on demand |

Capture is ambient (auto memory notes things as work happens, zero
ceremony), consolidation is deliberate (`/reflect` harvests shareable
repo-truths from auto memory and the session into evidence-gated ledger
entries), promotion is curated (`/evolve` routes: global rule → CLAUDE.md;
path-local rule → `.claude/rules/<topic>.md` with `paths:` frontmatter;
procedure → skill).

**The adapter slot.** The ambient tier is replaceable without touching the
reflect → evolve → replicate loop: `autoMemoryDirectory` relocates the
store, `autoMemoryEnabled` toggles it, and an MCP memory server can augment
retrieval. An external memory backend plugs in there — the pipeline's
interfaces (harvest at `/reflect`, promote at `/evolve`) do not change.
Dogfooding note: subagent persistent memory is docs-supported and a future
option for the verifier — observe the need first, encode later.

## Context-budget accounting

Always-loaded context = CLAUDE.md (≤20 concepts) + every skill's
`description` + ≤3 hook status lines. Everything else is on-demand: skill
bodies load on invocation, the ledger is opened by exactly three skills,
exploration and verification run in subagents that return conclusions. This
is why skill descriptions are capped at ≤50 words and the skill count at
≤15: since the model-invocation flip, every skill's description rides in
every session forever — a skill is a permanent tax, so the budget mirrors
CLAUDE.md's.

## The methodology mapping (Boris Cherny / Anthropic practice)

| Practice | Where it lives in Janus |
|---|---|
| Plan mode before code | `/plan-feature` (and prime directive #1) |
| Ship as a loop — babysit CI and reviews to merged | `/ship`, plus `.github/workflows/verify.yml` running `scripts/test-hooks.sh` as the remote closed loop |
| CLAUDE.md as compounding memory — "any time Claude does something wrong, add a note" | The session loop: signals → `/reflect` → ledger → `/evolve` → CLAUDE.md, with evidence thresholds so notes compound instead of accumulating |
| Closed feedback loops — "if Claude can close the loop on its own, it will iterate until the output is right" | PostToolUse hook (inner loop) + `/verify-loop` + the verifier agent |
| Subagents for focused work | Custom: verifier (evidence-bound judge) and memory-curator (proposal-only librarian). Scouting and independent design use Claude Code's native exploration/planning subagents — the platform owns the mechanism; the template keeps only the disciplines it adds |
| Parallel sessions in worktrees — 3–5 at once, one task per session | `/worktree-parallel`: native `claude --worktree` (script fallback), `claude agents` as the fleet view; `.claude/` is in-tree so every worktree gets the full scaffold |
| Team-shared configuration | `.claude/settings.json` is committed; `settings.local.json` is gitignored |
| Encoded practices drift as tools evolve | `/recalibrate` re-verifies conventions against primary sources and files drift as candidate learnings; `/evolve` keeps promotion authority; the session-start staleness nudge and the heartbeat routine keep it running |
| Loops trigger; skills encode quality | Skills auto-invoke from their trigger descriptions (the conductor directive routes goals to skills + modality); side-effect skills carry in-body gates that degrade to PR-delivery when headless; `/goal`-style loops and the weekly heartbeat only decide *when* |
