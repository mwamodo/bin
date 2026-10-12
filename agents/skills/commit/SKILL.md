---
name: commit
description: "Use this skill before creating a git commit"
---

Create a git commit for the current changes using a concise conventional commits-style subject.

## Commit format

`<type>(<scope>): <summary>`

Examples:
- `feat(auth): add magic link login`
- `fix(parser): handle empty input`
- `docs(readme): clarify install steps`

### Rules

- `type` is REQUIRED.
  - Common values: `feat`, `fix`, `docs`, `refactor`, `chore`, `test`, `perf`
- `scope` is OPTIONAL.
  - Use a short noun describing the affected area, such as `api`, `ui`, `auth`, `parser`
- `summary` is REQUIRED.
  - Imperative mood
  - No trailing period
  - Maximum 72 characters
  - Describe what changed, not why it was requested
- `sign commits`

## Body

The body is OPTIONAL.

If needed:
- Add a blank line after the subject
- Use short paragraphs or compact bullets
- Focus on important context, tradeoffs, or grouped changes
- Do NOT add footers or metadata

## Hard constraints

- Only create a commit. Do NOT push.
- Do NOT add sign-offs.
- Do NOT add breaking change markers or footers.
- Do NOT include unrelated files.
- If the intended commit scope is ambiguous, ask the user before committing.

## Interpreting caller input

Treat any caller-provided arguments as commit guidance.

### Freeform instructions

Use them to shape:
- commit type
- scope
- summary
- optional body

### File paths or globs

If specific files or globs are provided:
- Limit inspection, staging, and commit creation to those files only
- Do NOT include any other modified files unless the user explicitly asks

### Mixed input

If both files and instructions are provided, honor both.

## Procedure

1. Parse the prompt for:
   - specific file paths or globs
   - extra instructions about intent, scope, or wording

2. Inspect the repo state:
   - run `git status --short`
   - review diffs for the intended files only
   - if no files were specified, review all current changes

3. Optionally inspect recent commit subjects for style consistency:
   - `git log -n 50 --pretty=format:%s`

4. Decide whether the commit boundary is clear.
   - If unrelated or ambiguous changes are present, ask the user which files should be included
   - Prefer asking over guessing

5. Stage only the intended files.
   - If no files were specified, stage all relevant current changes
   - Never stage unrelated files just because they are modified

6. Write the commit message.
   - Subject must follow Conventional Commits format
   - Add a body only when it materially improves clarity

7. Create the commit:
   - `git commit -S -m "<subject>"`
   - or:
     - `git commit -S -m "<subject>" -m "<body>"`

## Decision guidance

- Use `feat` for user-visible functionality
- Use `fix` for bug fixes or correctness changes
- Use `refactor` for structural changes without behavior change
- Use `docs` for documentation-only changes
- Use `test` for test-only changes
- Use `chore` for maintenance, tooling, or housekeeping
- Use `perf` for performance improvements

When uncertain between multiple valid types, choose the most specific one supported by the diff.

## Safety checks before committing

Before running `git commit`, verify:
- the staged diff matches the intended scope
- no unrelated files are staged
- the subject is <= 72 characters
- the summary is imperative and has no trailing period
- the message does not include footers, sign-offs, or push instructions
