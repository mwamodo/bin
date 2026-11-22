---
name: handoff
description: Compact the current conversation into a handoff document for another agent to pick up.
argument-hint: "[--task <task>] [--new | --block <block:id>]"
arguments: 
    - name: task
      type: string
      description: what will the next sessions be used for?
      required: false
    - name: new
      type: boolean
      description: start a fresh agent in a new Rex tab and hand it the document
      required: false
    - name: block
      type: string
      description: hand the document to the agent running in this Rex block
      required: false
disable-model-invocation: true
---

Write a handoff document summarising the current conversation so a fresh agent can continue the work. Save it as `handoff-<YYYY-MM-DD>.md` in the task's folder in the vault, `~/notes/scratchpads/<project>/<task>/`, named as the global working-files rules say (the project's `~/notes/work/` folder name, in lowercase). Add `-b`, `-c` for a second or third handoff on the same day. List it in that project folder's `index.md`. Never save it in the current workspace.

Include a "suggested skills" section in the document, naming which skills the next agent should call the Skill tool for.

Do not duplicate content already captured in other artifacts (specs, plans, ADRs, issues, commits, diffs). Reference them by path or URL instead.

Redact any sensitive information, such as API keys, passwords, or personally identifiable information.

If the user passed --task, treat it as what the next session will focus on and tailor the doc accordingly.

## Hand it over

Once the document is saved, deliver it through Rex as the flags say. The prompt for the next agent is one line: `Read <absolute path of the handoff document> and continue the work it describes.`

- **No flag:** report the document's path.
- **`--new`:** open a tab in your session, in the project directory (the repo or worktree the work lives in), running the agent CLI you run in (`claude` for Claude Code, `codex` for Codex) with the prompt as its argument:

  ```sh
  rex window new -s "$REX_SESSION" handoff -c "$project_dir" --json -- claude "$prompt"
  ```

  Capture the new tab's `.block_ids[0]` once the agent has started, and confirm it is working on the prompt.
- **`--block <block:id>`:** capture the target first (`rex capture -b <id> --trim | tail -n 40`) and confirm an agent sits idle at its input prompt there, in a block other than your own `$REX_BLOCK`. When the capture shows a bare shell or a busy agent, stop and tell the user what it shows. Then type the prompt and submit it:

  ```sh
  rex send -b <id> "$prompt" && rex send-key -b <id> enter
  ```

  Capture again and confirm the agent took the prompt.

When both flags are passed, ask the user which one they mean. When Rex is unreachable (`rex whoami --json` fails), report the document's path and say it wasn't handed over.
