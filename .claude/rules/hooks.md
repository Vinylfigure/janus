---
paths:
  - ".claude/hooks/**/*.sh"
  - "scripts/test-hooks.sh"
---

# Hook rules

- Before committing a hook script, pipe fixture JSON through it and assert exit
  code and output for the pass, fail, and repeat cases. Counting and state bugs
  in hooks do not surface from reading the script — only from a seeded fixture
  that exercises each case. (L-001)
