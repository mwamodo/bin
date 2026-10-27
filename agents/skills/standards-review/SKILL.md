---
name: standards-review
description: Review the changes since a fixed point (commit, branch, tag, or merge-base) along two axes — Standards (does the code follow this repo's documented coding standards?) and Spec (does the code match what the originating issue/spec asked for?). Runs both reviews in parallel sub-agents and reports them side by side. Use when the user wants to review a branch, a PR, work-in-progress/uncommited changes, or asks to "review since X".
disable-model-invocation: true
---

Two-axis review of the diff between `HEAD` and a fixed point the user supplies:

- **Standards** — does the code conform to this repo's documented coding standards?
- **Spec** — does the code faithfully implement the originating issue / spec?

Both axes run as **parallel sub-agents** so they don't pollute each other's context, then this skill aggregates their findings.

The issue tracker should have been provided to you — run `/setup-repo` if `docs/agents/issue-tracker.md` is missing.

## Process

### 1. Pin the fixed point

Whatever the user said is the fixed point — a commit SHA, branch name, tag, `main`, `HEAD~5`, etc. "Uncommitted changes" or "work in progress" means `HEAD`. If they didn't specify one, ask for it.

Capture the diff command once: `git diff $(git merge-base <fixed-point> HEAD)`. It compares the merge-base with the working tree, so it covers both the commits since the fixed point and uncommitted edits; reviews often run before the commit. Untracked files never appear in a diff: list them with `git ls-files --others --exclude-standard` and review them as new files. Also note the list of commits via `git log <fixed-point>..HEAD --oneline` (empty when the fixed point is `HEAD`).

Before going further, confirm the fixed point resolves (`git rev-parse <fixed-point>`) and that the diff or the untracked list is non-empty. A bad ref or empty diff should fail here — not inside two parallel sub-agents.

### 2. Identify the spec source

Look for the originating spec, in this order:

1. Issue references in the commit messages (`#123`, `Closes #45`, GitLab `!67`, etc.) — fetch via the workflow in `docs/agents/issue-tracker.md`.
2. A path the user passed as an argument.
3. A spec file under `docs/`, `specs/`, or `.scratch/` matching the branch name or feature.
4. If nothing is found, ask the user where the spec is. If they say there isn't one, the **Spec** sub-agent will skip and report "no spec available".

### 3. Identify the standards sources

Anything in the repo that documents how code should be written, such as `CODING_STANDARDS.md` or `CONTRIBUTING.md`.

On top of whatever the repo documents, the Standards axis always carries the **smell baseline** below — a fixed set of Fowler code smells (_Refactoring_, ch.3) that applies even when a repo documents nothing. Two rules bind it:

- **The repo overrides.** A documented repo standard always wins; where it endorses something the baseline would flag, suppress the smell.
- **Always a judgement call.** Each smell is a labelled heuristic ("possible Feature Envy"), never a hard violation — and, like any standard here, skip anything tooling already enforces.

Each smell reads *what it is* → *how to fix*; match it against the diff:

- **Mysterious Name** — a function, variable, or type whose name doesn't reveal what it does or holds. → rename it; if no honest name comes, the design's murky.
- **Duplicated Code** — the same logic shape appears in more than one hunk or file in the change. → extract the shared shape, call it from both.
- **Feature Envy** — a method that reaches into another object's data more than its own. → move the method onto the data it envies.
- **Data Clumps** — the same few fields or params keep travelling together (a type wanting to be born). → bundle them into one type, pass that.
- **Primitive Obsession** — a primitive or string standing in for a domain concept that deserves its own type. → give the concept its own small type.
- **Repeated Switches** — the same `switch`/`if`-cascade on the same type recurs across the change. → replace with polymorphism, or one map both sites share.
- **Shotgun Surgery** — one logical change forces scattered edits across many files in the diff. → gather what changes together into one module.
- **Divergent Change** — one file or module is edited for several unrelated reasons. → split so each module changes for one reason.
- **Speculative Generality** — abstraction, parameters, or hooks added for needs the spec doesn't have. → delete it; inline back until a real need shows.
- **Message Chains** — long `a.b().c().d()` navigation the caller shouldn't depend on. → hide the walk behind one method on the first object.
- **Middle Man** — a class or function that mostly just delegates onward. → cut it, call the real target direct.
- **Refused Bequest** — a subclass or implementer that ignores or overrides most of what it inherits. → drop the inheritance, use composition.

### 4. Spawn both sub-agents in parallel

Both sub-agents return findings in one shape, worst first, at most 10 each. Give each brief this block verbatim:

```
- path/to/file.php:123 — one sentence stating the problem
  Cost: the concrete input or state that goes wrong, or what it costs
  Source: the quoted rule, smell + hunk, or spec line it rests on
```

Fewer real findings beat padding; return nothing for an axis that has nothing.

**Standards sub-agent prompt** — include:

- The full diff command, the untracked file paths, and the commit list.
- The list of standards-source files you found in step 3, **plus the smell baseline from step 3** pasted in full — the sub-agent has no other access to it.
- The brief: "Report (a) every place the change violates a documented standard, and (b) any baseline smell you spot. Flag a documented-standard violation only when you can quote both the exact rule (file + rule text) and the exact line that breaks it; leave out 'spirit of the doc' inferences. Baseline smells are always judgement calls: name the smell and quote the hunk. A documented repo standard overrides the baseline. Rules reach past the diff: for each function the change modifies, grep its callers and check them against the standards too, because an unchanged caller can break a rule the change triggers (an untouched `catch` that no longer matches a reclassified exception). Skip anything tooling enforces." Plus the finding block above.

**Spec sub-agent prompt** — include:

- The diff command, the untracked file paths, and the commit list.
- The path or fetched contents of the spec.
- The brief: "Report: (a) requirements the spec asked for that are missing or partial; (b) behaviour in the diff that wasn't asked for (scope creep); (c) requirements that look implemented but where the implementation looks wrong. For (b), audit removals as well as additions: for every line the change deletes or replaces, name the behaviour it enforced and check whether the spec asked for that behaviour to change. An unrequested removal is scope creep. Quote the spec line for each finding." Plus the finding block above.

If the spec is missing, skip the Spec sub-agent and note this in the final report.

### 5. Aggregate

Present the two reports under `## Standards` and `## Spec` headings, verbatim or lightly cleaned, keeping every finding in its block shape: whoever acts on the review often reads only this report. Do **not** merge or rerank findings — the two axes are deliberately separate (see _Why two axes_).

End with a one-line summary: total findings per axis, and the worst issue _within each axis_ (if any). Don't pick a single winner across axes — that's the reranking the separation exists to prevent.

## Why two axes

A change can pass one axis and fail the other:

- Code that follows every standard but implements the wrong thing → **Standards pass, Spec fail.**
- Code that does exactly what the issue asked but breaks the project's conventions → **Spec pass, Standards fail.**

Reporting them separately stops one axis from masking the other.
