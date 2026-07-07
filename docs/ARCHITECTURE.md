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
  agents/                     4 subagents — run in their own context windows
  memory/LEARNINGS.md         active learnings ledger (bounded: ≤25 entries, git-tracked)
  memory/ARCHIVE.md           resolved history — queryable, never loaded wholesale
  memory/recalibrated-at      committed epoch stamp of the last /recalibrate run
scripts/
  verify.sh                   quick|full dispatcher; /bootstrap fills the case arms
  test-hooks.sh               fixture suite for the hook plumbing (verify.sh full + CI)
  new-worktree.sh             worktree create/list/clean
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
SessionStart      session-start.sh      → ≤3 short lines: bootstrap status, ripe-learnings
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

## The memory hierarchy

Karpathy's LLM-OS framing — the model is the CPU, the context window is RAM,
everything outside it is disk — is the architecture behind Janus's memory
tiers:

| Tier | Analog | File | Bound | Loaded |
|---|---|---|---|---|
| Registers | always-on | `CLAUDE.md` | ≤20 concepts | every session |
| Working RAM | bounded active set | `LEARNINGS.md` | ≤25 entries | only by /reflect, /evolve, /replicate |
| Disk | resolved history | `ARCHIVE.md` | unbounded | never wholesale — targeted grep only |
| Index | random access | Graphify graph (incl. `.claude/memory/`) | — | queried one concept at a time; answers are leads, confirmed by grep |

His related "LLM wiki" pattern — compile knowledge into cross-referenced
markdown once, rather than re-deriving it on every retrieval — is what the
ledger already is; the graph indexes it, it doesn't replace it.

**Context-budget accounting.** Always-loaded context = CLAUDE.md (≤20
concepts) + every skill's `description` + ≤3 hook status lines. Everything
else is on-demand: skill bodies load on invocation, the ledger is opened by
exactly three skills, the archive never loads wholesale, exploration and
verification run in subagents that return conclusions. This is why skill
descriptions are capped at ≤50 words and the skill count at ≤15: since the
model-invocation flip, every skill's description rides in every session
forever — a skill is a permanent tax, so the budget mirrors CLAUDE.md's.

## The methodology mapping (Boris Cherny / Anthropic practice)

| Practice | Where it lives in Janus |
|---|---|
| Plan mode before code | `/plan-feature` (and prime directive #1) |
| Ship as a loop — babysit CI and reviews to merged | `/ship`, plus `.github/workflows/verify.yml` running `scripts/test-hooks.sh` as the remote closed loop |
| CLAUDE.md as compounding memory — "any time Claude does something wrong, add a note" | The session loop: signals → `/reflect` → ledger → `/evolve` → CLAUDE.md, with evidence thresholds so notes compound instead of accumulating |
| Closed feedback loops — "if Claude can close the loop on its own, it will iterate until the output is right" | PostToolUse hook (inner loop) + `/verify-loop` + the verifier agent |
| Subagents for focused work | explorer / planner / verifier / memory-curator, each read-only or evidence-bound |
| Parallel sessions in worktrees — 3–5 at once, one task per session | `/worktree-parallel`: native `claude --worktree` (script fallback), `claude agents` as the fleet view; `.claude/` is in-tree so every worktree gets the full scaffold |
| Team-shared configuration | `.claude/settings.json` is committed; `settings.local.json` is gitignored |
| Encoded practices drift as tools evolve | `/recalibrate` re-verifies conventions against primary sources and files drift as candidate learnings; `/evolve` keeps promotion authority; the session-start staleness nudge and the heartbeat routine keep it running |
| Loops trigger; skills encode quality | Skills auto-invoke from their trigger descriptions (the conductor directive routes goals to skills + modality); side-effect skills carry in-body gates that degrade to PR-delivery when headless; `/goal`-style loops and the weekly heartbeat only decide *when* |

## The external-memory layer (default-on, gracefully degrading)

[Graphify](https://github.com/Graphify-Labs/graphify) builds a local
tree-sitter knowledge graph (`graph.json`, `graph.html`, `GRAPH_REPORT.md` —
all gitignored as regenerable). It is the project's **random-access memory**:
the workspace (context) is a small, expensive working set, so codebase
structure is offloaded to an external queryable store and fetched one
concept at a time. A graph query returns entities and relationships —
concepts — where a grep returns file dumps.

`/bootstrap` installs it and builds the graph **by default** (greenfield
included; the graph grows with the code), ingesting `.claude/memory/` along
with the code so learnings are queryable one concept at a time; when the
graph exists, explorer and planner query it (`graphify query "…"`) before
grepping, and /reflect, /evolve, and memory-curator use it for graph-first
dedupe — always confirming by grep, since graph answers are leads, not
evidence. `verify.sh full` regenerates it so it never goes stale — no extra
hook needed. It is deliberately **not a hard requirement**: if the user
declines or `uv` is unavailable, agents fall back to grep and everything
still works. RAM by default, never load-bearing.
