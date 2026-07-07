# Using Janus

The operator's guide. [ARCHITECTURE.md](ARCHITECTURE.md) explains *why* the
pieces exist; [SELF-IMPROVEMENT.md](SELF-IMPROVEMENT.md) specs the memory
system; this document is *how you drive it*, day to day.

## Day 1: starting a project

1. **Create the repo.** Either click **Use this template** on GitHub, or — from
   any existing Janus project — run `/replicate <name>` and let it interview
   you. Replication is better once you have history: portable learnings are
   inherited, so each generation starts smarter.
2. **Open a session.** `cd` into the clone, run `claude`. The session-start
   hook will tell you the scaffold is not bootstrapped.
3. **Run `/bootstrap`.** It detects your stack (or interviews you for one),
   wires `scripts/verify.sh` to your real formatter/linter/tests, sets up the
   [Graphify](https://github.com/Graphify-Labs/graphify) knowledge graph by
   default (the project's external random-access memory — skippable, and the
   scaffold degrades gracefully without it), and *proves* the loop closes —
   you'll see a passing full run and a deliberately-broken edit get caught.
   From this moment every edit you or Claude makes is checked automatically.
4. **Build your first feature with `/plan-feature`.** It will explore via
   subagents, write a plan with explicit "done means" criteria, and drive the
   implementation through the verification loop.

## The daily rhythm

- **Non-trivial work starts in plan mode** (Shift+Tab twice) or with
  `/plan-feature`. Trivial one-file changes: just ask; the inner loop has
  your back.
- **Let the inner loop work.** After every edit, the PostToolUse hook runs the
  quick check and feeds failures straight back to Claude. You don't need to
  paste lint errors — they arrive automatically.
- **Before accepting "done", demand the loop be closed**: `/verify-loop`
  (iterates to green against a runnable check, max 5 rounds) or the
  `verifier` agent (adversarial: runs the suite *plus* probes the change
  directly, and only passes on pasted evidence).
- **Ship with `/ship`**: verify → commit → push → PR → babysit CI and reviews
  until merged.

## Session rituals (the self-learning loop)

You mostly don't have to think about this — the hooks do:

- Every prompt that *looks like a correction* ("no, that's wrong…") is
  silently logged. Every verification failure is silently logged.
- **When you stop a session that logged signals, the Stop hook blocks once**
  and asks Claude to run `/reflect`. That's not an error — it's the system
  refusing to waste an expensive lesson. Let it run; it takes seconds and
  writes one-concept rules to `.claude/memory/LEARNINGS.md` (or states why
  there was no lesson).
- **When the session-start line says learnings are ripe** ("N with
  Evidence ≥ 2 — consider /evolve"), run `/evolve`. It promotes stable
  lessons into `CLAUDE.md` rules or new skills, retires contradicted rules,
  and enforces the concept budget. This is how corrections compound instead
  of repeating.

You can also run `/reflect` manually any time something surprising happened —
don't wait for the nudge.

## Memory operations

- **Read the ledger** at `.claude/memory/LEARNINGS.md`. Entries are
  append-only and marked, never deleted: `candidate` → `promoted:*` /
  `retired`, plus `inherited` in children.
- **Nothing promotes on one occurrence.** Evidence ≥ 2 (or your explicit
  confirmation) is the bar. If you *know* a lesson is right after one
  occurrence, say so and `/evolve` will take your word as evidence.
- **`Scope: portable` is a promise** — true in any repository. These entries
  are what `/replicate` carries into children. Judge harshly.
- **The budget is load-bearing**: CLAUDE.md holds ≤20 concepts, ≤12 learned
  rules. When `/evolve` refuses to add without retiring, that's the design
  working, not a limitation to remove (rationale in
  [ARCHITECTURE.md](ARCHITECTURE.md#the-global-workspace-rationale)).
- **Run `/recalibrate` periodically** (roughly monthly): it re-verifies the
  scaffold's encoded practices against primary sources (Anthropic docs,
  changelog, the Claude Code team's posts) and files drift as candidate
  ledger entries — `/evolve` still decides what changes.

## Scaling up

- **Parallel workstreams**: `/worktree-parallel` splits a task into
  independent tracks and launches each with native worktrees:
  `claude --worktree <name>` (add `--tmux` for its own tmux session);
  `scripts/new-worktree.sh` remains as the fallback and cleanup helper.
  Run 3–5 sessions, **one task per session** — never multiplex tracks in one
  conversation. Number your terminal tabs, enable system notifications, and
  use `claude agents` from the root directory as the fleet view. Every
  worktree carries the full scaffold (`.claude/` is in-tree). Merge only
  tracks that verified green; clean worktrees after.
- **Delegate to subagents by habit**: `explorer` to scout before you plan,
  `planner` for an independent design, `verifier` before you believe "done",
  `memory-curator` inside `/evolve`. Delegation keeps the main thread's
  context clean for actual decisions.
- **New procedures become skills**: when you catch yourself giving the same
  multi-step instructions twice, run `/add-skill`. Rules go to CLAUDE.md;
  procedures become skills.

## Replication and lineage

- `/replicate <name>` stamps a child repo (GitHub template path or local
  fallback), copies portable rules and ledger entries in as
  `Status: inherited`, rewrites identity, and hands off to the child's
  `/bootstrap`.
- Children **re-earn** promotion: inherited entries need fresh evidence in
  the child before `/evolve` promotes them there.
- Children do **not** auto-update from the template. To backport a template
  improvement into an existing child, cherry-pick the commit.
- Improving Janus itself is just feature work — the template runs its own
  loops (see the dogfooding rules in
  [SELF-IMPROVEMENT.md](SELF-IMPROVEMENT.md#improving-janus-itself-dogfooding)),
  and `scripts/test-hooks.sh` keeps the hook plumbing honest in CI.

## Troubleshooting

- **Hook didn't fire?** Hooks need the workspace trusted (accept the trust
  dialog) and `jq` installed — without `jq` they degrade to silent no-ops.
  `claude --debug` shows hook execution.
- **Quick check too slow?** It runs on *every* edit; keep it under ~10s. Move
  anything slower into the `full` arm.
- **Stop nudge felt wrong?** It fires at most once per session and only when
  signals exist. If the signal was a false positive (the correction regex is
  deliberately loose), Claude just states "no lesson" and stops — cost: one
  sentence.
