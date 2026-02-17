---
description: "Run a Makefile target"
argument-hint: "[target-name]"
allowed-tools: ["Bash(make -f .Makefile.claude*)"]
---

# Do

Run a target from `.Makefile.claude` in the current working directory.

If `$ARGUMENTS` is provided, run that target:

```!
make -f .Makefile.claude $ARGUMENTS
```

If no arguments, run `make -f .Makefile.claude` with no target (defaults to `help` per the template, which lists all `## commented` targets).
