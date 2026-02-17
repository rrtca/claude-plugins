---
description: "Explain the make plugin and available commands"
---

# Make Plugin Help

Explain the following to the user:

## What is the Make Plugin?

The make plugin enforces a consistent development workflow for every project:

**concept -> brainstorm -> plan -> tasks -> execute -> archive -> commit**

It uses three Unix primitives:
- **Makefile** (`.Makefile.claude`) — portable task runner, "everything is a file"
- **dotenv** (`.env`) — environment configuration
- **beads** (`bd`) — git-backed dependency-aware task graph

## Workflow

1. Discuss an idea with the user
2. `/make:plan-md` — write a dated plan to `docs/plans/`
3. `/make:tasks <slug>` — create beads from the plan
4. `/make:run` — execute task loop (iterates on `bd ready`)
5. `bd sync` — persist completed state to git
6. Commit source + plan together

## Commands

| Command | Description |
|---|---|
| `/make:plan-md [topic]` | Write a dated implementation plan |
| `/make:tasks <plan-slug>` | Create beads from a plan |
| `/make:run [--max-iterations N]` | Execute task loop |
| `/make:break` | Stop the task loop |
| `/make:hold [bead-id]` | Pause a task |
| `/make:reset` | Reset task state |
| `/make:print-env` | Dump env after .env import |
| `/make:edit` | Edit .Makefile.claude |
| `/make:edit-template` | Edit .Makefile.claude-template |

## Makefile Pattern

The plugin uses `.Makefile.claude` to avoid colliding with existing project Makefiles.
All targets: `make -f .Makefile.claude <target>`
If no Makefile exists, a symlink is created automatically.

## Dotenv Pattern

Single `.env` at project root. Overrides via `.env-overrides-<desc>` in subdirs.
