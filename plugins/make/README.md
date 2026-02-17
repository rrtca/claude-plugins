# Make Plugin

Universal project workflow plugin for Claude Code. Enforces plan-driven development via Makefile + dotenv + beads.

## Install

```
/plugin marketplace add rrtca/claude-plugins
/plugin install make@claude-plugins
```

## What It Does

Every project gets a consistent workflow:

1. **Concept** — paste/chat/file with a plain English idea
2. **Brainstorm** — discuss with Claude, clarify details
3. **Plan** — `/make:plan-md` writes a dated plan to `docs/plans/`
4. **Tasks** — `/make:tasks <plan-slug>` creates beads from the plan
5. **Execute** — `/make:run` iterates on `bd ready` via task loop
6. **Archive** — `bd sync` persists completed state to git
7. **Commit** — source + plan committed together

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
| `/make:help` | Show plugin help |

## Makefile Pattern

The plugin uses `.Makefile.claude` to avoid collisions with existing project Makefiles. All targets are invoked as `make -f .Makefile.claude <target>`.

If no `Makefile` exists in the project, a symlink `Makefile -> .Makefile.claude` is created automatically via a Make file target.

### Dotenv

Single `.env` at project root. The Makefile imports it:

```makefile
mkenv ?= .env
-include $(mkenv)
export $(shell sed 's/=.*//' $(mkenv) 2>/dev/null)
```

Overrides in subdirs use `.env-overrides-<description>` with recursive make.

## Beads Integration

Tasks are managed as [beads](https://github.com/steveyegge/beads) — a git-backed dependency-aware task graph. Key commands:

- `bd ready` — show unblocked tasks
- `bd create "title"` — create a task
- `bd dep add <child> <parent>` — link dependencies
- `bd update <id> --claim` — claim a task
- `bd update <id> --status done` — complete a task
- `bd sync` — persist to git

## Hooks

- **Stop**: Task loop iteration (feeds next `bd ready` task)
- **SessionStart**: Surfaces pending beads and loop state on session start
- **PostToolUse**: Auto-logs git commits as bead comments

## Requirements

- [beads CLI](https://github.com/steveyegge/beads) (`bd`)
- `jq`
- `make`
