# Development Workflow

This document defines the workflow for Claude Code sessions on this project.

## Project Context

This is a fork of `anthropics/claude-plugins-official` at `rrtca/claude-plugins`. We are building the `make` plugin in `plugins/make/`. The design doc is at `docs/plans/2026-02-17-make-plugin-design.md`.

## Tools & Runtime

- Use `bun` for all package management and script execution
- Never use `npm`, `node`, or `npx` — use `bun x` for running package binaries
- Never start the dev server — the user runs it themselves
- Beads CLI (`bd`) is installed and used for task management

## Workflow Loop

Every feature or task follows this cycle. Do not ask which approach to use — always follow this process:

1. **Brainstorm** — Discuss the user's input, explore options, ask clarifying questions
2. **Plan** — Write a plan as a dated markdown file in `docs/plans/YYYY-MM-DD-topic.md`
3. **Tasks** — Create beads from the plan: Claude reads plan, runs `bd create` + `bd dep add` for dependencies
4. **Execute** — Work through tasks via `bd ready` (unblocked tasks), claim with `bd update <id> --claim`, complete with `bd update <id> --status done`
5. **Sync** — Run `bd sync` to persist bead state to git
6. **Commit** — Commit source changes and plan doc together
7. **Repeat** — Move to the next feature

## Plan Format

Plans go in `docs/plans/YYYY-MM-DD-topic.md`. Keep them concise and actionable. Include:
- Problem statement / goal
- Approach (what changes, where)
- Task breakdown (numbered, with dependencies)

## Makefile Patterns

- The plugin uses `.Makefile.claude` (not `Makefile`) to avoid collisions with existing project Makefiles
- All make invocations use `make -f .Makefile.claude <target>`
- If no `Makefile` exists, `.Makefile.claude` creates a symlink via file target
- Never use `test -f` in Makefiles — use file targets as dependencies instead
- Follow the dotenv pattern: `mkenv ?= .env` / `-include $(mkenv)` / `export $(shell sed 's/=.*//' $(mkenv) 2>/dev/null)`
- Scripts live in `./scripts/`, always run from project root
- Makefile targets delegate to scripts if logic exceeds one line

## Commit Discipline

- Only commit when the user explicitly asks
- Commit source changes and plan doc together for atomic commits with full context
- Do not commit unless asked

## What NOT To Do

- Do not ask "which execution approach?" — always use the workflow above
- Do not start dev servers
- Do not run full production builds for verification
- Do not use npx
- Do not commit unless asked
