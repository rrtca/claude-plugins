---
description: "Create beads from a plan"
argument-hint: "<plan-slug>"
allowed-tools: ["Bash(bd *)"]
---

# Tasks

Create beads (task tickets) from a plan document.

## Instructions

1. Find the plan file:
   - If `$ARGUMENTS` is provided, look for `docs/plans/*$ARGUMENTS*.md`
   - If multiple matches, ask user to clarify
   - If no matches, list available plans in `docs/plans/` and ask

2. Read the plan file completely.

3. For each task in the plan's Tasks section:
   - Run: `bd create "<task title>" --description "<detailed description from plan>"`
   - Note the returned bead ID

4. After all beads are created, add dependency links:
   - For each task that depends on another: `bd dep add <child-id> <parent-id>`

5. Verify with: `bd ready`
   - This shows unblocked tasks ready for work

6. Report summary: how many beads created, dependency graph, what's ready.

7. Suggest: "Tasks created. Run `/make:run` to start executing."
