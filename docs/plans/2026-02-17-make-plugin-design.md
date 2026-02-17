# Make Plugin Design

**Date:** 2026-02-17
**Status:** Draft
**Plugin:** `make`
**Marketplace:** `rrtca/claude-plugins`

## Problem Statement

Every project needs a consistent workflow: concept, brainstorm, plan, tasks, execute, archive, commit. Currently this is ad-hoc. The `make` plugin enforces this workflow universally, using Makefile + dotenv as the portable interface and beads (`bd`) as the task graph backend.

Makefile + dotenv is a powerful pattern in the Unix world where "everything is a file" and Make "makes files." The combination of file targets, phony tasks, and dotenv enables advanced workflows and enforces patterns across any project.

## Architecture

### File Layout

```
.Makefile.claude              # Plugin-managed Makefile (always used via make -f)
.Makefile.claude-template     # Project-specific template override (optional)
Makefile                      # Symlink to .Makefile.claude (created only if no Makefile exists)
.env                          # Single dotenv at project root
.env-overrides-<desc>         # Subdirectory overrides
.claude/make-loop.local.md    # Ralph-loop state file (ephemeral)
docs/plans/YYYY-MM-DD-*.md   # Plans (committed)
```

### Collision Avoidance

The plugin always operates on `.Makefile.claude`, invoked as `make -f .Makefile.claude <target>`.

If no `Makefile` exists in PWD, `.Makefile.claude` includes a file target that creates the symlink:

```makefile
Makefile:
	@ln -s .Makefile.claude Makefile
```

This is idiomatic Make: if `Makefile` doesn't exist, Make creates it by linking. If it already exists (e.g., project fork with its own Makefile), Make skips it. No `test -f`, no conditionals.

### Template Hierarchy

1. If `.Makefile.claude-template` exists in PWD -> use it (with user confirmation)
2. Otherwise -> use plugin's distributed template (`${CLAUDE_PLUGIN_ROOT}/Makefile.claude-template`)

`/make:edit-template` edits the PWD template, copying from plugin dist if none exists.

## Beads Integration

Beads (`bd`) replaces `prd.json` as the task store. Benefits:
- Dependency DAG (vs flat list) -> solves parallelization
- Hash-based IDs (`bd-a1b2`) -> no merge collisions
- `bd ready` -> gives unblocked tasks, drives the execution loop
- Git-backed persistence via JSONL
- Agent-optimized JSON output

### Integration Points

| Action | Beads command |
|---|---|
| Init project | `bd init` (during scaffolding, if not already initialized) |
| Create tasks from plan | Claude reads plan, runs `bd create` + `bd dep add` |
| Find next work | `bd ready` |
| Claim a task | `bd update <id> --claim` |
| Complete a task | `bd update <id> --status done` |
| Hold tasks | `bd update <id> --status paused` |
| Session end sync | `bd sync` |

Task creation is Claude-driven (not script-parsed): the `/make:tasks` command instructs Claude to read the plan markdown and create beads with proper titles, descriptions, priorities, and dependencies via `bd` CLI calls. This handles nuance in plan format better than brittle markdown parsing.

## Slash Commands

| Command | Delegates to | Description |
|---|---|---|
| `/make:plan-md` | Claude skill | Write a dated plan to `docs/plans/YYYY-MM-DD-<slug>.md` |
| `/make:tasks <plan>` | Claude -> `bd create` + `bd dep add` | Create beads from plan with dependency graph |
| `/make:run` | `make -f .Makefile.claude run` | Execute task loop (ralph-loop on `bd ready`) |
| `/make:break` | `make -f .Makefile.claude break` | Stop the loop |
| `/make:hold` | `make -f .Makefile.claude hold` | Pause specific beads |
| `/make:reset` | `make -f .Makefile.claude reset` | Reset task state |
| `/make:print-env` | `make -f .Makefile.claude print-env` | Dump env after .env import |
| `/make:edit` | Opens `.Makefile.claude` in PWD | Edit the project Makefile |
| `/make:edit-template` | Opens `.Makefile.claude-template` | Edit template (copies from plugin dist if missing) |

## Makefile Template (Minimal)

```makefile
# .Makefile.claude - managed by make plugin
# Project-specific targets go below the plugin section

mkenv ?= .env
-include $(mkenv)
export $(shell sed 's/=.*//' $(mkenv) 2>/dev/null)

.PHONY: help tasks run break hold reset print-env archive
.DEFAULT_GOAL := help

help: ## Show targets
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# Symlink convenience - created only if no Makefile exists
Makefile:
	@ln -s .Makefile.claude Makefile

tasks: ## Show ready tasks (bd ready)
	@bd ready

run: tasks ## Execute task loop
	@echo "Loop driven by stop hook + bd ready"

break: ## Stop the loop
	@rm -f .claude/make-loop.local.md
	@echo "Loop stopped"

hold: ## Pause a task: TASK=bd-xxxx make -f .Makefile.claude hold
	@bd update $(TASK) --status paused

reset: ## Reset task state
	@bd ready --json | jq -r '.[].id' | xargs -I{} bd update {} --status open

print-env: ## Dump environment
	@env | sort

archive: ## Archive completed beads
	@bash scripts/archive-beads.sh
```

### Dotenv Pattern

- Single `.env` at project root: `mkenv ?= .env` / `-include $(mkenv)` / `export`
- Overrides in subdirs: `.env-overrides-<description>`
- Recursive make with override: `env=.env-overrides-foo $(MAKE) -f .Makefile.claude`

## Hooks (Light Set)

### Stop Hook (command)
Absorbed from ralph-loop. When Claude tries to stop during `/make:run`:
1. Check `.claude/make-loop.local.md` for active loop state
2. Run `bd ready` to find next unblocked task
3. If tasks remain: increment iteration, feed next task back as prompt
4. If no tasks: deactivate loop, run `bd sync`, report completion

### SessionStart Hook (prompt)
On session start, inject context:
- Run `bd ready` to show available tasks
- Run `bd show` on any in-progress beads
- Surface where the user left off, prevent re-investigation

### PostToolUse Hook (prompt, on Bash with git commit)
After `git commit` succeeds:
- Capture commit message
- Log as bead comment on the currently claimed bead
- Work self-documents without manual effort

## Changes from Ralph-Loop Clone

1. `plugin.json` -> `make` identity, description, author (`rrtca`)
2. Replace `ralph-loop.md` command -> `run.md` (and other make commands)
3. Replace `cancel-ralph.md` -> `break.md`
4. Replace `help.md` -> make-specific help
5. Replace project-specific `Makefile.template` -> `.Makefile.claude` generic template
6. Adapt `stop-hook.sh`: use `bd ready` instead of flat file re-read
7. Add `SessionStart` hook for resume context
8. Add `PostToolUse` hook for auto-log
9. Rename state file: `ralph-loop.local.md` -> `make-loop.local.md`
10. Add `make` entry to repo `marketplace.json`

## Workflow Enforced

```
1. Concept    -> paste/chat/file with plain english idea
2. Brainstorm -> discuss with Claude, clarify details
3. Plan       -> /make:plan-md writes docs/plans/YYYY-MM-DD-<slug>.md
4. Tasks      -> /make:tasks <slug> creates beads from plan
5. Execute    -> /make:run iterates bd ready via loop
6. Archive    -> completed beads persist in git (bd sync)
7. Commit     -> source changes + plan doc committed together
8. Repeat     -> next feature
```

## Task Breakdown

1. Create feature branch `feature/make-plugin`
2. Update `plugin.json` with make identity
3. Write `.Makefile.claude` template (plugin dist)
4. Create slash commands: plan-md, tasks, run, break, hold, reset, print-env, edit, edit-template
5. Adapt stop hook for beads + make-loop state
6. Add SessionStart hook (prompt-based)
7. Add PostToolUse hook for auto-log
8. Update help command
9. Add `make` to `marketplace.json`
10. Write CLAUDE.md for the plugin project (from workflow-template.md)
11. Test: install plugin, scaffold a project, run full workflow
