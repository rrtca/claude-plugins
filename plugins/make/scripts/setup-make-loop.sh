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
