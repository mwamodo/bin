# Working files

Write working files (notes, handoff briefs, screenshots, probe scripts, test logs, HTML reports) into the Obsidian vault at `~/notes/scratchpads/<project>/`, in a task-named subfolder. The session scratchpad and `/tmp` hold only throwaway intermediates.

- Name the folder after the project: the same name as its folder in `~/notes/work/` when there is one, in lowercase (`gbpn`). The repo, its worktrees and Orca workspaces all use that one folder (`gbpn-ai` → `gbpn`). Use the existing folder; create a new one only when none fits.
- Add every new file or folder to that project folder's `index.md`: what it is, the date, and whether it's safe to clean up.
- Leave everything else in the vault untouched. The user does all cleanup. Notes outside `scratchpads/`, such as `work/gbpn/GBPN.md`, are the user's: edit them only when asked.

# Passing on reviews

When you pass on a code review from a subagent or another session, list every finding, one line each, and save the full list in the task's vault folder. Whoever fixes the code sees only what you pass on.

# Decisions built on a false premise

When checking shows that the reason behind a user's decision isn't true, stop and ask before building that part, and say what you found.

# Checking UI changes

Open every UI change in a browser yourself before handing it off or marking a PR ready: Orca's built-in browser (`orca skills get orca-cli` explains the commands) or the user's Chrome through the claude-in-chrome tools. Walk each affected screen and state, and put screenshots in the PR's Evidence section. If you can't open it, keep the PR a draft and list what's unchecked.
