---
name: handoff
description: Compact the current conversation into a handoff document for another agent to pick up.
argument-hint: "[--task <task>]"
arguments: 
    - name: task
      type: string
      description: what will the next sessions be used for?
      required: false
disable-model-invocation: true
---

Write a handoff document summarising the current conversation so a fresh agent can continue the work. Save it as `handoff-<YYYY-MM-DD>.md` in the task's folder in the vault, `~/notes/scratchpads/<project>/<task>/`, named as the global working-files rules say (the project's `~/notes/work/` folder name, in lowercase). Add `-b`, `-c` for a second or third handoff on the same day. List it in that project folder's `index.md`. Never save it in the current workspace.

Include a "suggested skills" section in the document, naming which skills the next agent should call the Skill tool for.

Do not duplicate content already captured in other artifacts (specs, plans, ADRs, issues, commits, diffs). Reference them by path or URL instead.

Redact any sensitive information, such as API keys, passwords, or personally identifiable information.

If the user passed --task, treat it as what the next session will focus on and tailor the doc accordingly.
