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
