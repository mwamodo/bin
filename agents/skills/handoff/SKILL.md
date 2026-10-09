---
name: handoff
description: Compact the current conversation into a handoff document for another agent to pick up.
argument-hint: [--task] [--terminal_id]
arguments: 
    - name: terminal_id
      type: string
      description: handoff to the agent in this terminal id
      required: false
    - name: task
      type: string
      description: what will the next sessions be used for?
      required: false
disable-model-invocation: true
---

Write a handoff document summarising the current conversation so a fresh agent can continue the work. Save to `~/notes/scratchpads/handoffs` - not the current workspace.

Include a "suggested skills" section in the document, naming which skills the next agent should call the Skill tool for.

Do not duplicate content already captured in other artifacts (specs, plans, ADRs, issues, commits, diffs). Reference them by path or URL instead.

Redact any sensitive information, such as API keys, passwords, or personally identifiable information.

If the user passed arguments, 

1. treat the --task as a description of what the next session will focus on and tailor the doc accordingly.
2. if --terminal_id has been passed use orca to hand the handoff document to the agent in the passed terminal_id