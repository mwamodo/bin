# Working files

Write working files (notes, handoff briefs, screenshots, probe scripts, test logs, HTML reports) into the Obsidian vault at `~/notes/scratchpads/<Project>/`, in a task-named subfolder. The session scratchpad and `/tmp` hold only throwaway intermediates.

- Find the project's existing folder in `~/notes/scratchpads/` first; names follow the project, not the repo (the `gbpn` repo and its worktrees use `GBPN`). Create a new folder only when none fits.
- Add every new file or folder to that project folder's `index.md`: what it is, the date, and whether it's safe to clean up.
- Leave everything else in the vault untouched. The user does all cleanup, and the folder's own notes (such as `GBPN.md`) are theirs.

# Passing on reviews

When you pass on a code review from a subagent or another session, list every finding, one line each, and save the full list in the task's vault folder. Whoever fixes the code sees only what you pass on.

# Decisions built on a false premise

When checking shows that the reason behind a user's decision isn't true, stop and ask before building that part, and say what you found.
