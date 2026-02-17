# Make Plugin Test Plan

Manual testing checklist. Work through in order — each section builds on the previous.

**Prereqs:**
- `bd` (beads CLI) installed: `npm install -g @anthropics/beads`
- `jq` installed
- `make` installed
- Branch `feature/make-plugin` pushed to `rrtca/claude-plugins`

---

## 1. Push the branch

```bash
cd /u/dev10k/src/claude-plugins
git push -u origin feature/make-plugin
```

---

## 2. Marketplace

Open a **new Claude Code session** in a fresh test directory:

```bash
mkdir /tmp/make-test && cd /tmp/make-test
claude
```

Then:

```
/plugin marketplace add rrtca/claude-plugins
```

- [ ] Marketplace added without error
- [ ] Can see `make` in available plugins:

```
/plugin marketplace list
```

---

## 3. Install

```
/plugin install make@claude-plugins
```

- [ ] Plugin installs without error
- [ ] Slash commands visible — type `/make:` and check tab completion shows:
  - `break`, `do`, `edit`, `edit-template`, `help`, `hold`, `plan-md`, `print-env`, `reset`, `run`, `tasks`

---

## 4. Help

```
/make:help
```

- [ ] Displays plugin description, workflow, command table
- [ ] All 11 commands listed (including `/make:do`)

---

## 5. Scaffolding

Initialize a test project:

```bash
# In the test dir (/tmp/make-test)
git init
echo "PROJECT_NAME=test" > .env
```

Then in Claude:

```
/make:edit
```

- [ ] `.Makefile.claude` created from template
- [ ] Contains dotenv import (`mkenv ?= .env`)
- [ ] Contains all targets (help, tasks, run, break, hold, reset, print-env, archive)

---

## 6. /make:do (Makefile targets)

```
/make:do
```

- [ ] Runs `make -f .Makefile.claude` with no target — shows help output listing `## commented` targets

```
/make:do print-env
```

- [ ] Runs `make -f .Makefile.claude print-env` — dumps env including `PROJECT_NAME=test`

---

## 7. /make:print-env

```
/make:print-env
```

- [ ] Shows environment variables including `PROJECT_NAME=test` from `.env`

---

## 8. Beads integration

Initialize beads:

```bash
bd init
```

Then in Claude:

```
/make:do tasks
```

- [ ] Runs `bd ready` — shows empty (no tasks yet)

---

## 9. /make:plan-md

```
/make:plan-md test-feature
```

- [ ] Claude writes a plan to `docs/plans/2026-02-17-test-feature.md`
- [ ] File exists and has reasonable structure

---

## 10. /make:tasks

```
/make:tasks test-feature
```

- [ ] Claude reads the plan and creates beads via `bd create`
- [ ] Dependencies added via `bd dep add`
- [ ] `bd ready` shows at least one unblocked task

---

## 11. /make:run (task loop)

```
/make:run --max-iterations 3
```

- [ ] Setup script creates `.claude/make-loop.local.md`
- [ ] Claude picks up first `bd ready` task
- [ ] Claims it with `bd update <id> --claim`
- [ ] Completes it with `bd update <id> --status done`
- [ ] Stop hook fires, feeds next task
- [ ] Loop stops after 3 iterations (or when tasks exhausted)

---

## 12. /make:break

Start a loop, then:

```
/make:break
```

- [ ] `.claude/make-loop.local.md` removed
- [ ] Loop stops on next exit attempt

---

## 13. /make:hold

With an active bead:

```
/make:hold <bead-id>
```

- [ ] Bead status changes to `paused`
- [ ] `bd ready` no longer shows it

---

## 14. /make:reset

```
/make:reset
```

- [ ] In-progress beads reset to `open`
- [ ] Loop state file removed if present

---

## 15. Hooks

### SessionStart hook

Start a **new Claude session** in the test project (with beads present):

```bash
cd /tmp/make-test && claude
```

- [ ] Session start shows bead summary (pending tasks, any in-progress work)

### PostToolUse hook (auto-log)

Make a change and commit:

```bash
echo "# test" > test.md
git add test.md && git commit -m "test commit"
```

- [ ] Hook fires after commit
- [ ] Claude logs commit to in-progress bead (if one is claimed)

---

## 16. /make:edit-template

```
/make:edit-template
```

- [ ] Creates `.Makefile.claude-template` in PWD (copied from plugin dist)
- [ ] Opens for editing

---

## 17. Symlink target

Delete the Makefile if it exists, then:

```bash
make -f .Makefile.claude Makefile
```

- [ ] Creates `Makefile -> .Makefile.claude` symlink
- [ ] `make help` now works (via symlink)

---

## 18. Collision safety

Create a project with an existing Makefile:

```bash
mkdir /tmp/make-collision-test && cd /tmp/make-collision-test
echo "all:" > Makefile
echo "	echo existing" >> Makefile
```

Install plugin, run `/make:edit`:

- [ ] `.Makefile.claude` created
- [ ] Existing `Makefile` is NOT overwritten
- [ ] `make -f .Makefile.claude Makefile` is a no-op (target already exists)

---

## Cleanup

```bash
rm -rf /tmp/make-test /tmp/make-collision-test
```
