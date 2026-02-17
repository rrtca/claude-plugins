Check for beads state in this project:

1. If `bd` CLI is available, run `bd ready` to see unblocked tasks
2. If there are in-progress beads, run `bd list --status in_progress` to show them
3. If `.claude/make-loop.local.md` exists, note that a task loop was active

Briefly mention what's pending so the user has context. Do not take action — just surface state.
