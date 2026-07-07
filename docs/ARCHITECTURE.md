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
  skills/                     8 skills — load on demand (progressive disclosure)
  agents/                     4 subagents — run in their own context windows
  memory/LEARNINGS.md         append-only learnings ledger (git-tracked)
scripts/
  verify.sh                   quick|full dispatcher; /bootstrap fills the case arms
  new-worktree.sh             worktree create/list/clean
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
SessionStart      session-start.sh      → ≤2 lines: bootstrap status, ripe-learnings count
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
guard, so an ignored nudge never becomes an infinite loop.

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
| Articulated intermediate reasoning drives conclusions | Skills end with **Before finishing** (state what was verified + evidence); `/verify-loop` requires a one-sentence failure diagnosis before each fix; the verifier demands pasted output |
| Workspace representations generalize across tasks | Learnings are distilled as one-concept imperative *rules*, not narratives, so they transfer between tasks and (via `Scope: portable`) between repositories |
| Routine work happens outside the workspace | Progressive disclosure: skill bodies load only on use; clean sessions get no Stop-hook ceremony; exploration and verification are delegated to subagents so their context never enters the main thread |

This is why the caps are hard: every concept added to CLAUDE.md competes for
the same limited workspace the model needs for the actual task. When `/evolve`
refuses to add a rule without retiring one, that is the design working.

## The methodology mapping (Boris Cherny / Anthropic practice)

| Practice | Where it lives in Janus |
|---|---|
| Plan mode before code | `/plan-feature` (and prime directive #1) |
| CLAUDE.md as compounding memory — "any time Claude does something wrong, add a note" | The session loop: signals → `/reflect` → ledger → `/evolve` → CLAUDE.md, with evidence thresholds so notes compound instead of accumulating |
| Closed feedback loops — "if Claude can close the loop on its own, it will iterate until the output is right" | PostToolUse hook (inner loop) + `/verify-loop` + the verifier agent |
| Subagents for focused work | explorer / planner / verifier / memory-curator, each read-only or evidence-bound |
| Parallel sessions in worktrees | `/worktree-parallel` + `scripts/new-worktree.sh`; `.claude/` is in-tree so every worktree gets the full scaffold |
| Team-shared configuration | `.claude/settings.json` is committed; `settings.local.json` is gitignored |

## The knowledge-graph layer (optional)

[Graphify](https://github.com/Graphify-Labs/graphify) builds a local
tree-sitter knowledge graph (`graph.json`, `graph.html`, `GRAPH_REPORT.md` —
all gitignored as regenerable). `/bootstrap` offers the install; when the
graph exists, explorer and planner query it (`graphify query "…"`) before
grepping. The fit is deliberate: a graph query returns entities and
relationships — concepts — where a grep returns file dumps, so exploration
spends less of the workspace budget. `verify.sh full` regenerates the graph
so it never goes stale; no extra hook needed.
