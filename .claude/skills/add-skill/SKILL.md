---
name: add-skill
description: Author a new skill for this repository using the canonical Janus SKILL.md shape (Hold in mind, Steps, Before finishing) and workspace-priming rules. Use when a procedure is worth repeating, or when /evolve promotes a procedure-shaped learning.
argument-hint: [skill name and purpose]
---

The meta-skill: it makes the repository's skill-authoring standard executable.
Used by humans adding capabilities and by `/evolve` when a learning is
procedure-shaped.

## Hold in mind

1. Skill bodies load on demand — they may be long. Priming blocks may not: 3-5 items, hard cap.
2. The `description` frontmatter is how the model decides to load the skill: write it as *what it does + when to use it*, front-loading trigger phrases.
3. Scaffold weight must match task complexity: heavy checklists for complex/risky procedures, near-zero ceremony for simple ones.
4. Don't shadow built-ins (`init`, `review`, `verify`, `run`, `debug`) or existing janus skills.

## Steps

1. Confirm the skill deserves to exist: it's a *procedure* (multi-step, repeatable), not a *fact* (belongs in CLAUDE.md) and not a one-off.
2. Choose the name (kebab-case directory under `.claude/skills/<name>/SKILL.md`) after checking existing skills and built-ins.
3. Write frontmatter:
   - `description`: what + when, trigger phrases first (this is the only part always in context).
   - `disable-model-invocation: true` if it has side effects the user should time (deploys, replication, promotion).
   - `argument-hint` if it takes arguments.
4. Write the body in the canonical shape:

   ```markdown
   ## Hold in mind
   3-5 invariants the agent must restate in its own words before step 1.
   These are the concepts to hold active while working — not background info.

   ## Steps
   Numbered, imperative. Complex/risky steps get explicit checks; simple
   steps stay terse.

   ## Before finishing
   Forced articulation: what was verified, what evidence was seen. The agent
   must state this, not just think it.
   ```

5. Dry-run it: read the finished SKILL.md and simulate the first two steps mentally. If a step is ambiguous to you now, it will be ambiguous to a fresh session — tighten it.

## Before finishing

State: the new skill's name, its description line, whether it is
model-invocable, and confirm the body follows the canonical shape with a
priming block of <= 5 items.
