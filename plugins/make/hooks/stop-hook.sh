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
