A git commit was just made. If there is a currently claimed bead (in_progress status), log this commit as a comment on that bead using:

bd comment <bead-id> "Committed: <first line of commit message>"

This keeps the bead's history self-documenting. If no bead is claimed, skip silently.
