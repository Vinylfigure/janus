# Sources seen

`/recalibrate`'s watermark: what has been read, when, and what it concluded.
Git-tracked for the same reason as `recalibrated-at` — a headless heartbeat
running in a cloud clone must be able to advance it everywhere via its PR.

Two kinds of row, and the distinction is load-bearing:

- **living** — docs pages, changelogs, blog indexes. Re-read *every* run. A
  stable URL says nothing about stable content, and marking one "seen" would
  make all future drift invisible.
- **one-shot** — a dated article. Read once; skip on later runs.

Format: `| date | kind | URL | conclusion |`. Conclusion is `confirmed`,
`drifted:L-NNN`, `new:L-NNN`, or `no-op`. `/replicate` truncates this table for
a child — a fresh repo has verified nothing, and inheriting a parent's
watermark would make it skip sources it has never read.

<!-- rows below this line -->

| date | kind | URL | conclusion |
|---|---|---|---|
| 2026-07-24 | living | https://code.claude.com/docs/en/memory | drifted:L-021 — auto memory is machine-local, "not shared across machines or cloud environments" |
| 2026-07-24 | living | https://code.claude.com/docs/en/skills | new:L-023 — frontmatter field set grew; 1,536-char listing figure is a truncation ceiling, not a budget |
| 2026-07-24 | living | https://claude.com/blog | drifted:L-019 — the post index the old source list never named |
| 2026-07-24 | one-shot | https://claude.com/blog/the-new-rules-of-context-engineering-for-claude-5-generation-models | drifted:L-024, L-025 — rules→judgment, CLAUDE.md→gotchas, manual memory→auto-memory |
| 2026-07-24 | one-shot | https://claude.com/blog/claude-models-explained-choosing-the-best-model-for-your-use-case | no-op — advisor strategy noted; model pinning rejected as a moving target (L-004) |
| 2026-07-24 | one-shot | https://claude.com/blog/building-verification-loops-in-claude-code-with-skills | confirmed — /verify-loop and the verifier agent match the standalone + PR-wide patterns |
| 2026-07-24 | one-shot | https://claude.com/blog/how-anthropic-secures-its-ai-native-software-development-lifecycle | no-op — least-privilege agent tools already satisfied; /security-review is a platform built-in |
| 2026-07-24 | one-shot | https://claude.com/blog/working-at-the-frontier-rakuten | confirmed — "Adding more agents doesn't add judgment"; supports the propose/dispose gates |
| 2026-07-24 | one-shot | https://claude.com/blog/harnessing-claudes-intelligence | confirmed — "Strip Your Agent Harness Down" backs subtraction over adoption |
| 2026-07-24 | one-shot | https://claude.com/blog/ai-code-migration | no-op — adversarial reviewer trio rejected as an org chart copied as a starting shape (L-017) |
| 2026-07-24 | one-shot | https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents | confirmed — "right altitude" bounds the rules→judgment rewrite at both ends |
| 2026-07-24 | one-shot | https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills | confirmed — progressive disclosure matches the skill-body-loads-on-demand design |
