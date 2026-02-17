---
description: "Execute task loop via beads"
argument-hint: "[--max-iterations N] [--completion-promise TEXT]"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-make-loop.sh:*)"]
---

# Run

Execute the setup script to initialize the make task loop:

```!
"${CLAUDE_PLUGIN_ROOT}/scripts/setup-make-loop.sh" $ARGUMENTS
```

The loop will iterate on `bd ready` tasks. For each iteration:
1. Check `bd ready` for unblocked tasks
2. Claim and work on the next task
3. Mark complete when done
4. Stop hook feeds next task back

When all beads are done (bd ready returns empty), the loop completes.

CRITICAL RULE: If a completion promise is set, you may ONLY output it when the statement is completely and unequivocally TRUE.
