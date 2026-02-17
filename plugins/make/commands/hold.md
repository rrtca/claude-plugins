---
description: "Pause a bead task"
argument-hint: "<bead-id>"
allowed-tools: ["Bash(bd *)"]
---

# Hold

Pause a specific bead task.

1. If `$ARGUMENTS` is provided, use it as the bead ID
2. Otherwise, run `bd ready` and ask which task to pause
3. Run: `bd update <bead-id> --status paused`
4. Confirm the hold with: `bd show <bead-id>`
