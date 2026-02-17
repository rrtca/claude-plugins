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
