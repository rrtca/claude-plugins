---
description: "Stop the active task loop"
allowed-tools: ["Bash(rm -f .claude/make-loop.local.md)", "Read(.claude/make-loop.local.md)"]
---

# Break

To stop the make task loop:

1. Check if `.claude/make-loop.local.md` exists
2. If it exists:
   - Read it to get the current iteration number
   - Remove the file: `rm -f .claude/make-loop.local.md`
   - Report: "Loop stopped at iteration N"
3. If not found: "No active loop."
