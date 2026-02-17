# Make Plugin Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Transform the ralph-loop clone in `plugins/make/` into the `make` plugin — a universal workflow enforcer using `.Makefile.claude` + dotenv + beads as task backend.

**Architecture:** Plugin provides slash commands that wrap `make -f .Makefile.claude` targets and `bd` CLI calls. The ralph-loop Stop hook is adapted to iterate on `bd ready` instead of a flat file. SessionStart and PostToolUse hooks provide context resumption and auto-logging.

**Tech Stack:** Bash, Make, beads (`bd` CLI), Claude Code plugin system (commands, hooks, prompt-based hooks)

---

### Task 1: Update plugin identity

**Files:**
- Modify: `plugins/make/.claude-plugin/plugin.json`

**Step 1: Rewrite plugin.json**

Replace contents with:

```json
{
  "name": "make",
  "description": "Universal project workflow plugin. Enforces plan-driven development via Makefile + dotenv + beads. Scaffolds .Makefile.claude, manages tasks as beads, executes via ralph-loop mechanics.",
  "author": {
    "name": "rrtca"
  }
}
```

**Step 2: Verify JSON is valid**

Run: `jq . plugins/make/.claude-plugin/plugin.json`
Expected: Pretty-printed JSON, no errors.

**Step 3: Commit**

```bash
git add plugins/make/.claude-plugin/plugin.json
git commit -m "Update make plugin identity in plugin.json"
```

---

### Task 2: Write the .Makefile.claude template

**Files:**
- Create: `plugins/make/Makefile.claude-template` (the dist template shipped with the plugin)
- Delete: `plugins/make/Makefile.template` (the old project-specific one)

**Step 1: Create the dist template**

Write `plugins/make/Makefile.claude-template`:

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

# Symlink convenience — created only if no Makefile exists in PWD
Makefile:
	@ln -s .Makefile.claude Makefile
	@echo "Created Makefile -> .Makefile.claude symlink"

tasks: ## Show ready beads (unblocked tasks)
	@bd ready

run: ## Execute task loop (driven by stop hook + bd ready)
	@echo "Loop active — stop hook will iterate on bd ready"

break: ## Stop the task loop
	@rm -f .claude/make-loop.local.md
	@echo "Loop stopped"

hold: ## Pause a task: TASK=bd-xxxx make -f .Makefile.claude hold
	@test -n "$(TASK)" || (echo "Usage: TASK=bd-xxxx make -f .Makefile.claude hold" && exit 1)
	@bd update $(TASK) --status paused
	@echo "Paused $(TASK)"

reset: ## Reset all tasks to open
	@bd ready --json 2>/dev/null | jq -r '.[].id' | xargs -I{} bd update {} --status open
	@echo "All tasks reset to open"

print-env: ## Dump environment after .env import
	@env | sort

archive: ## Sync beads to git
	@bd sync
	@echo "Beads synced"

# ─── Project-specific targets below ───────────────────────────
```

**Step 2: Delete the old template**

Run: `rm plugins/make/Makefile.template`

**Step 3: Verify template syntax**

Run: `make -f plugins/make/Makefile.claude-template -n help`
Expected: Dry-run output showing the awk command, no syntax errors.

**Step 4: Commit**

```bash
git add plugins/make/Makefile.claude-template
git rm plugins/make/Makefile.template
git commit -m "Replace project-specific Makefile with generic .Makefile.claude template"
```

---

### Task 3: Create core slash commands — plan-md, tasks

**Files:**
- Create: `plugins/make/commands/plan-md.md`
- Create: `plugins/make/commands/tasks.md`

**Step 1: Write plan-md command**

Write `plugins/make/commands/plan-md.md`:

```markdown
---
description: "Write a dated implementation plan"
argument-hint: "[topic description]"
---

# Plan

Create a plan document for the described topic.

## Instructions

1. If `$ARGUMENTS` is provided, use it as the topic. Otherwise, ask the user what they want to plan.

2. Brainstorm with the user:
   - Ask clarifying questions (one at a time, prefer multiple choice)
   - Explore options and trade-offs
   - Confirm scope before writing

3. Write the plan to `docs/plans/YYYY-MM-DD-<topic-slug>.md` where:
   - Date is today's date
   - Slug is a short kebab-case summary of the topic

4. Plan format:
   ```
   # <Title>

   ## Goal
   [One paragraph problem statement / what we're building]

   ## Approach
   [What changes and where]

   ## Tasks
   1. [Task with description and dependencies]
   2. [Task with description and dependencies]
   ...
   ```

5. Keep it concise and actionable. No fluff.

6. After writing, suggest: "Plan written. Run `/make:tasks <slug>` to create beads from it."
```

**Step 2: Write tasks command**

Write `plugins/make/commands/tasks.md`:

```markdown
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
```

**Step 3: Commit**

```bash
git add plugins/make/commands/plan-md.md plugins/make/commands/tasks.md
git commit -m "Add plan-md and tasks slash commands"
```

---

### Task 4: Create workflow slash commands — run, break, hold, reset

**Files:**
- Create: `plugins/make/commands/run.md`
- Create: `plugins/make/commands/break.md`
- Create: `plugins/make/commands/hold.md`
- Create: `plugins/make/commands/reset.md`

**Step 1: Write run command**

Write `plugins/make/commands/run.md`:

```markdown
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
```

**Step 2: Write break command**

Write `plugins/make/commands/break.md`:

```markdown
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
```

**Step 3: Write hold command**

Write `plugins/make/commands/hold.md`:

```markdown
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
```

**Step 4: Write reset command**

Write `plugins/make/commands/reset.md`:

```markdown
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
```

**Step 5: Commit**

```bash
git add plugins/make/commands/run.md plugins/make/commands/break.md plugins/make/commands/hold.md plugins/make/commands/reset.md
git commit -m "Add run, break, hold, reset slash commands"
```

---

### Task 5: Create utility slash commands — print-env, edit, edit-template

**Files:**
- Create: `plugins/make/commands/print-env.md`
- Create: `plugins/make/commands/edit.md`
- Create: `plugins/make/commands/edit-template.md`

**Step 1: Write print-env command**

Write `plugins/make/commands/print-env.md`:

```markdown
---
description: "Dump environment after .env import"
allowed-tools: ["Bash(make -f .Makefile.claude print-env)"]
---

# Print Env

Run: `make -f .Makefile.claude print-env`

This shows all environment variables after the `.env` file has been sourced by Make's dotenv pattern.
```

**Step 2: Write edit command**

Write `plugins/make/commands/edit.md`:

```markdown
---
description: "Edit .Makefile.claude in PWD"
---

# Edit Makefile

Open `.Makefile.claude` in the current working directory for editing.

1. If `.Makefile.claude` does not exist, ask the user if they want to scaffold it first (copies from plugin template).
2. Read the current `.Makefile.claude`
3. Ask what changes to make
4. Edit the file
```

**Step 3: Write edit-template command**

Write `plugins/make/commands/edit-template.md`:

```markdown
---
description: "Edit .Makefile.claude-template in PWD"
allowed-tools: ["Bash(cp ${CLAUDE_PLUGIN_ROOT}/Makefile.claude-template .Makefile.claude-template)"]
---

# Edit Template

Edit the project-local `.Makefile.claude-template`.

1. If `.Makefile.claude-template` does not exist in PWD:
   - Copy from plugin dist: `cp "${CLAUDE_PLUGIN_ROOT}/Makefile.claude-template" .Makefile.claude-template`
   - Tell user: "Created .Makefile.claude-template from plugin default. Edit to customize."
2. Read `.Makefile.claude-template`
3. Ask what changes to make
4. Edit the file

NOTE: The template is used when scaffolding new `.Makefile.claude` files. Editing the template does not affect an existing `.Makefile.claude` — delete or move it first, then re-scaffold.
```

**Step 4: Commit**

```bash
git add plugins/make/commands/print-env.md plugins/make/commands/edit.md plugins/make/commands/edit-template.md
git commit -m "Add print-env, edit, edit-template slash commands"
```

---

### Task 6: Adapt the stop hook for beads

**Files:**
- Modify: `plugins/make/hooks/stop-hook.sh`
- Modify: `plugins/make/hooks/hooks.json`

**Step 1: Rewrite stop-hook.sh**

The existing ralph-loop stop hook reads a flat prompt from `.claude/ralph-loop.local.md` and feeds it back. The new hook:
- Reads state from `.claude/make-loop.local.md`
- Runs `bd ready` to find unblocked tasks
- If tasks remain: builds a prompt from the next ready task and feeds it back
- If no tasks: deactivates loop, runs `bd sync`, allows exit

Replace `plugins/make/hooks/stop-hook.sh` with:

```bash
#!/bin/bash

# Make Plugin Stop Hook
# Iterates on bd ready tasks when loop is active
# Adapted from ralph-loop stop hook

set -euo pipefail

HOOK_INPUT=$(cat)
STATE_FILE=".claude/make-loop.local.md"

if [[ ! -f "$STATE_FILE" ]]; then
  exit 0
fi

# Parse frontmatter
FRONTMATTER=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$STATE_FILE")
ITERATION=$(echo "$FRONTMATTER" | grep '^iteration:' | sed 's/iteration: *//')
MAX_ITERATIONS=$(echo "$FRONTMATTER" | grep '^max_iterations:' | sed 's/max_iterations: *//')
COMPLETION_PROMISE=$(echo "$FRONTMATTER" | grep '^completion_promise:' | sed 's/completion_promise: *//' | sed 's/^"\(.*\)"$/\1/')

# Validate
if [[ ! "$ITERATION" =~ ^[0-9]+$ ]] || [[ ! "$MAX_ITERATIONS" =~ ^[0-9]+$ ]]; then
  echo "Warning: make-loop state corrupted, stopping loop" >&2
  rm "$STATE_FILE"
  exit 0
fi

# Check max iterations
if [[ $MAX_ITERATIONS -gt 0 ]] && [[ $ITERATION -ge $MAX_ITERATIONS ]]; then
  echo "Max iterations ($MAX_ITERATIONS) reached."
  bd sync 2>/dev/null || true
  rm "$STATE_FILE"
  exit 0
fi

# Check completion promise in transcript
if [[ "$COMPLETION_PROMISE" != "null" ]] && [[ -n "$COMPLETION_PROMISE" ]]; then
  TRANSCRIPT_PATH=$(echo "$HOOK_INPUT" | jq -r '.transcript_path')
  if [[ -f "$TRANSCRIPT_PATH" ]]; then
    LAST_LINE=$(grep '"role":"assistant"' "$TRANSCRIPT_PATH" | tail -1)
    if [[ -n "$LAST_LINE" ]]; then
      LAST_OUTPUT=$(echo "$LAST_LINE" | jq -r '.message.content | map(select(.type == "text")) | map(.text) | join("\n")' 2>/dev/null || echo "")
      PROMISE_TEXT=$(echo "$LAST_OUTPUT" | perl -0777 -pe 's/.*?<promise>(.*?)<\/promise>.*/$1/s; s/^\s+|\s+$//g; s/\s+/ /g' 2>/dev/null || echo "")
      if [[ -n "$PROMISE_TEXT" ]] && [[ "$PROMISE_TEXT" = "$COMPLETION_PROMISE" ]]; then
        echo "Detected <promise>$COMPLETION_PROMISE</promise> — loop complete."
        bd sync 2>/dev/null || true
        rm "$STATE_FILE"
        exit 0
      fi
    fi
  fi
fi

# Check bd ready for next task
READY_TASKS=$(bd ready --json 2>/dev/null || echo "[]")
TASK_COUNT=$(echo "$READY_TASKS" | jq 'length' 2>/dev/null || echo "0")

if [[ "$TASK_COUNT" -eq 0 ]]; then
  echo "All beads complete — no tasks remaining."
  bd sync 2>/dev/null || true
  rm "$STATE_FILE"
  exit 0
fi

# Get next task
NEXT_ID=$(echo "$READY_TASKS" | jq -r '.[0].id')
NEXT_TITLE=$(echo "$READY_TASKS" | jq -r '.[0].title')
NEXT_DESC=$(echo "$READY_TASKS" | jq -r '.[0].description // ""')

# Get the base prompt from state file
BASE_PROMPT=$(awk '/^---$/{i++; next} i>=2' "$STATE_FILE")

# Update iteration
NEXT_ITERATION=$((ITERATION + 1))
TEMP_FILE="${STATE_FILE}.tmp.$$"
sed "s/^iteration: .*/iteration: $NEXT_ITERATION/" "$STATE_FILE" > "$TEMP_FILE"
mv "$TEMP_FILE" "$STATE_FILE"

# Build prompt with next task context
TASK_PROMPT="$BASE_PROMPT

---
CURRENT TASK: $NEXT_ID — $NEXT_TITLE
$NEXT_DESC

Claim this task with: bd update $NEXT_ID --claim
When done: bd update $NEXT_ID --status done
Then check bd ready for the next task."

SYSTEM_MSG="make loop iteration $NEXT_ITERATION | $TASK_COUNT tasks remaining | next: $NEXT_ID $NEXT_TITLE"

jq -n \
  --arg prompt "$TASK_PROMPT" \
  --arg msg "$SYSTEM_MSG" \
  '{
    "decision": "block",
    "reason": $prompt,
    "systemMessage": $msg
  }'

exit 0
```

**Step 2: Update hooks.json** (no change needed — Stop hook path is the same)

Verify `plugins/make/hooks/hooks.json` still points to `${CLAUDE_PLUGIN_ROOT}/hooks/stop-hook.sh`. It does — no change needed.

**Step 3: Make executable and test syntax**

Run: `chmod +x plugins/make/hooks/stop-hook.sh && bash -n plugins/make/hooks/stop-hook.sh`
Expected: No syntax errors.

**Step 4: Commit**

```bash
git add plugins/make/hooks/stop-hook.sh
git commit -m "Adapt stop hook for beads integration (bd ready iteration)"
```

---

### Task 7: Adapt the setup script for make-loop

**Files:**
- Rename + modify: `plugins/make/scripts/setup-ralph-loop.sh` -> `plugins/make/scripts/setup-make-loop.sh`

**Step 1: Create setup-make-loop.sh**

Copy the structure from `setup-ralph-loop.sh` but:
- Rename state file to `.claude/make-loop.local.md`
- Update messaging to reference make/beads instead of ralph
- Default prompt becomes "Work through beads tasks" if none provided
- Add `bd ready` check at startup

Write `plugins/make/scripts/setup-make-loop.sh`:

```bash
#!/bin/bash

# Make Loop Setup Script
# Creates state file for task execution loop

set -euo pipefail

PROMPT_PARTS=()
MAX_ITERATIONS=0
COMPLETION_PROMISE="null"

while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      cat << 'HELP_EOF'
make run - Task execution loop via beads

USAGE:
  /make:run [PROMPT...] [OPTIONS]

ARGUMENTS:
  PROMPT...    Base prompt for each iteration (default: "Work through beads tasks")

OPTIONS:
  --max-iterations <n>           Max iterations before auto-stop (default: unlimited)
  --completion-promise '<text>'  Promise phrase to signal completion
  -h, --help                     Show this help

DESCRIPTION:
  Starts a task execution loop. The stop hook iterates on `bd ready`,
  feeding the next unblocked task each iteration. Loop ends when all
  beads are done, max iterations reached, or promise detected.

EXAMPLES:
  /make:run --max-iterations 20
  /make:run --completion-promise 'ALL DONE' --max-iterations 50
  /make:run Implement the API from the plan --max-iterations 30
HELP_EOF
      exit 0
      ;;
    --max-iterations)
      [[ -n "${2:-}" ]] && [[ "$2" =~ ^[0-9]+$ ]] || { echo "Error: --max-iterations requires a number" >&2; exit 1; }
      MAX_ITERATIONS="$2"
      shift 2
      ;;
    --completion-promise)
      [[ -n "${2:-}" ]] || { echo "Error: --completion-promise requires text" >&2; exit 1; }
      COMPLETION_PROMISE="$2"
      shift 2
      ;;
    *)
      PROMPT_PARTS+=("$1")
      shift
      ;;
  esac
done

PROMPT="${PROMPT_PARTS[*]:-Work through beads tasks}"

# Check beads is available
if ! command -v bd &>/dev/null; then
  echo "Error: bd (beads) CLI not found. Install: npm install -g @beads/bd" >&2
  exit 1
fi

# Check for ready tasks
READY_COUNT=$(bd ready --json 2>/dev/null | jq 'length' 2>/dev/null || echo "0")
if [[ "$READY_COUNT" -eq 0 ]]; then
  echo "Warning: No ready beads found. Create tasks first with /make:tasks" >&2
  echo "Continuing anyway — tasks may be created during the loop." >&2
fi

# Create state file
mkdir -p .claude

if [[ -n "$COMPLETION_PROMISE" ]] && [[ "$COMPLETION_PROMISE" != "null" ]]; then
  COMPLETION_PROMISE_YAML="\"$COMPLETION_PROMISE\""
else
  COMPLETION_PROMISE_YAML="null"
fi

cat > .claude/make-loop.local.md <<EOF
---
active: true
iteration: 1
max_iterations: $MAX_ITERATIONS
completion_promise: $COMPLETION_PROMISE_YAML
started_at: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
---

$PROMPT
EOF

cat <<EOF
Task loop activated.

Iteration: 1
Ready tasks: $READY_COUNT
Max iterations: $(if [[ $MAX_ITERATIONS -gt 0 ]]; then echo $MAX_ITERATIONS; else echo "unlimited"; fi)
Completion promise: $(if [[ "$COMPLETION_PROMISE" != "null" ]]; then echo "$COMPLETION_PROMISE"; else echo "none"; fi)

The stop hook will iterate on bd ready, feeding tasks until done.
To stop: /make:break
EOF

echo ""
echo "$PROMPT"
```

**Step 2: Delete old script**

Run: `rm plugins/make/scripts/setup-ralph-loop.sh`

**Step 3: Make executable and test syntax**

Run: `chmod +x plugins/make/scripts/setup-make-loop.sh && bash -n plugins/make/scripts/setup-make-loop.sh`
Expected: No syntax errors.

**Step 4: Commit**

```bash
git add plugins/make/scripts/setup-make-loop.sh
git rm plugins/make/scripts/setup-ralph-loop.sh
git commit -m "Replace ralph setup script with make-loop setup (beads-driven)"
```

---

### Task 8: Remove old ralph-loop commands

**Files:**
- Delete: `plugins/make/commands/ralph-loop.md`
- Delete: `plugins/make/commands/cancel-ralph.md`

**Step 1: Remove old commands**

Run:
```bash
git rm plugins/make/commands/ralph-loop.md plugins/make/commands/cancel-ralph.md
```

**Step 2: Commit**

```bash
git commit -m "Remove ralph-loop commands (replaced by make:run, make:break)"
```

---

### Task 9: Rewrite help command

**Files:**
- Modify: `plugins/make/commands/help.md`

**Step 1: Replace help.md**

Write `plugins/make/commands/help.md`:

```markdown
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
```

**Step 2: Commit**

```bash
git add plugins/make/commands/help.md
git commit -m "Rewrite help command for make plugin"
```

---

### Task 10: Add SessionStart and PostToolUse hooks

**Files:**
- Modify: `plugins/make/hooks/hooks.json`
- Create: `plugins/make/hooks/session-start.md`
- Create: `plugins/make/hooks/post-commit-log.md`

**Step 1: Write SessionStart prompt hook**

Write `plugins/make/hooks/session-start.md`:

```markdown
Check for beads state in this project:

1. If `bd` CLI is available, run `bd ready` to see unblocked tasks
2. If there are in-progress beads, run `bd list --status in_progress` to show them
3. If `.claude/make-loop.local.md` exists, note that a task loop was active

Briefly mention what's pending so the user has context. Do not take action — just surface state.
```

**Step 2: Write PostToolUse prompt hook for auto-log**

Write `plugins/make/hooks/post-commit-log.md`:

```markdown
A git commit was just made. If there is a currently claimed bead (in_progress status), log this commit as a comment on that bead using:

bd comment <bead-id> "Committed: <first line of commit message>"

This keeps the bead's history self-documenting. If no bead is claimed, skip silently.
```

**Step 3: Update hooks.json**

Replace `plugins/make/hooks/hooks.json` with:

```json
{
  "description": "Make plugin hooks: task loop, session resume, auto-log",
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/stop-hook.sh"
          }
        ]
      }
    ],
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "prompt",
            "prompt_file": "${CLAUDE_PLUGIN_ROOT}/hooks/session-start.md"
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": {
          "tool_name": "Bash",
          "command_pattern": "git commit"
        },
        "hooks": [
          {
            "type": "prompt",
            "prompt_file": "${CLAUDE_PLUGIN_ROOT}/hooks/post-commit-log.md"
          }
        ]
      }
    ]
  }
}
```

**Step 4: Validate JSON**

Run: `jq . plugins/make/hooks/hooks.json`
Expected: Valid JSON output.

**Step 5: Commit**

```bash
git add plugins/make/hooks/hooks.json plugins/make/hooks/session-start.md plugins/make/hooks/post-commit-log.md
git commit -m "Add SessionStart and PostToolUse hooks for context resume and auto-log"
```

---

### Task 11: Update README and add to marketplace

**Files:**
- Modify: `plugins/make/README.md`
- Modify: `.claude-plugin/marketplace.json`

**Step 1: Rewrite README.md**

Replace `plugins/make/README.md` with documentation covering:
- What the plugin is (1 paragraph)
- Installation (`/plugin marketplace add rrtca/claude-plugins` + `/plugin install make@claude-plugins`)
- Quick start workflow
- Command reference table
- Makefile pattern (`.Makefile.claude`, symlink, dotenv)
- Beads integration summary

**Step 2: Add make to marketplace.json**

Add this entry to the `plugins` array in `.claude-plugin/marketplace.json`:

```json
{
  "name": "make",
  "description": "Universal project workflow plugin. Enforces plan-driven development via Makefile + dotenv + beads. Scaffolds .Makefile.claude, manages tasks as beads, executes via task loop.",
  "author": {
    "name": "rrtca"
  },
  "source": "./plugins/make",
  "category": "development",
  "homepage": "https://github.com/rrtca/claude-plugins/tree/main/plugins/make"
}
```

**Step 3: Validate marketplace JSON**

Run: `jq . .claude-plugin/marketplace.json`
Expected: Valid JSON.

**Step 4: Commit**

```bash
git add plugins/make/README.md .claude-plugin/marketplace.json
git commit -m "Update README and add make plugin to marketplace"
```

---

## Summary

| Task | What | Files |
|---|---|---|
| 1 | Plugin identity | plugin.json |
| 2 | .Makefile.claude template | Makefile.claude-template |
| 3 | plan-md + tasks commands | 2 new commands |
| 4 | run + break + hold + reset commands | 4 new commands |
| 5 | print-env + edit + edit-template commands | 3 new commands |
| 6 | Stop hook for beads | stop-hook.sh |
| 7 | Setup script for make-loop | setup-make-loop.sh |
| 8 | Remove old ralph commands | delete 2 files |
| 9 | Rewrite help | help.md |
| 10 | SessionStart + PostToolUse hooks | hooks.json + 2 prompt files |
| 11 | README + marketplace | README.md + marketplace.json |

Total: 11 tasks, 11 commits, one per task.
