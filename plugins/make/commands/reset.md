---
description: "Reset task state"
allowed-tools: ["Bash(bd *)"]
---

# Reset

Reset all in-progress beads back to open status.

1. Run `bd list --status in_progress --json` to find in-progress tasks
2. For each: `bd update <id> --status open`
3. Also remove loop state: `rm -f .claude/make-loop.local.md`
4. Show current state: `bd ready`
