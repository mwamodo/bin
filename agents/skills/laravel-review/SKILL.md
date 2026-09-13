---
name: laravel-review
description: Review Laravel changes in a working tree, a commit, changes since a commit, a branch, or a PR. Establish the exact snapshot, publish an upfront risk assessment, and scale review depth while reporting findings and confidence separately. Also use for risk-only assessment of a Laravel change; a whole-repository audit is a separate scope.
---

# Laravel change review

Review the requested change in its actual application context. Establish scope and invariants, publish preliminary risk, then review to the required depth. Risk describes consequences; findings describe defects; confidence describes evidence.

Resources:
- `scripts/collect-evidence.sh` invokes the Python 3 standard-library collector. It returns complete JSON evidence, never risk verdicts.
- `references/risk-rubric.md` defines factors, overrides, uncertainty, and the opening report header. Read before scoring.
- `references/review-passes.md` supplies concern-specific checks. Read before reviewing; select concerns by behavior and depth by risk.

## 1. Resolve scope and context

Read applicable repository instructions, relevant architecture/invariants, and the actual framework/package versions. Preserve the user's review-only or no-test constraints. Do not change application files, commit, or publish a PR review as part of inspection unless requested.

Resolve the collector's absolute path relative to this SKILL.md. Run it from the target repository, or supply `--repo /absolute/repository`. Keep evidence in a temporary location outside that repository using `--output /absolute/evidence.json`.

| Request | Collector mode | Meaning |
|---|---|---|
| Review my changes, with dirty working tree | `uncommitted` | Staged, unstaged, and non-ignored untracked changes, kept as separate layers |
| Review only staged / unstaged changes | `staged` / `unstaged` | Explicit layer; unstaged excludes untracked files |
| Review this commit | `commit <ref>` | The selected commit versus its first parent; root commits versus the empty tree |
| Review changes since X | `since <ref>` | That ancestor through current HEAD; excludes local changes |
| Review this branch against X | `branch <base>` | Merge-base of base and current HEAD through HEAD |
| Review between two points | `range <base> <head>` | Exact endpoint comparison |
| Review a PR URL or number | `pr <url-or-number>` | Resolve the requested PR's actual base/head; never substitute local HEAD. Use `--pr-repo HOST/OWNER/REPO` when needed |

Do not silently choose between a single commit and changes since it. Use explicit wording/context; ask when genuinely ambiguous. State first-parent comparison for a merge commit; use a user-specified comparison when supplied. If there is no target and no dirty working tree, ask what to review.

PR mode requires `gh` and locally available base/head objects. If objects are missing, fetch from the exact PR repository or use an isolated checkout without disturbing user changes, then rerun. If metadata/access remains unavailable, report unresolved scope rather than reviewing the current branch. Read the PR description and relevant linked requirements separately; descriptions and commit messages are claims to validate, not unquestionable specifications.

The JSON scope contains immutable base/head SHAs and a snapshot ID. For committed changes, read callers, config, tests, and other surrounding source at `scope.head` (for example `git show <head>:<path>` or an isolated checkout). Do not use unrelated files from the current branch or dirty working tree as evidence about that revision. For staged context use the index (`git show :<path>`); for unstaged context use working files. Distinguish the staged-to-be-committed outcome from the final working outcome when edits cancel across layers.

## 2. Layer 1: collect evidence

Run the collector and check success before interpreting its JSON. An error is an incomplete collection, never an empty or clean review. `empty: true` means there are genuinely no changes in the resolved scope; report that scope and stop without inventing a risk score.

Read the full `changes` inventory and patches. JSON contains `layer`, `path`, old/new-side line evidence, complete flags, and explicit content gaps. Tool output can truncate even though the saved JSON does not: inspect the saved evidence in batches and account for every change. Renames are deliberately represented as deletion/addition; relate their callers and behavior during partitioning.

Flags and path hints only direct attention. Whitespace, documentation, translation, generated-file, and sensitive-path categories never authorize a Low shortcut. Inspect every change for semantic or operational effects, including strings, templates, executable language files, deployment instructions, and removed safeguards. Abbreviate review only after establishing bounded consequences and no unresolved content.

Inspect binary assets with suitable viewers; inspect generated changes through their actual source/build provenance. Lockfiles are reviewable dependency changes: establish changed versions, transitive effects, and relevant compatibility/security evidence. Mark a partition unclassified only where actual content/effects remain unresolved, and state what evidence would resolve it.

## 3. Partition and score (Layer 2)

Group files and hunks by coherent behavior change; account for every `(layer, path)` and investigate interactions between groups. Large diffs increase coverage work; do not sum unrelated partitions into a larger risk score.

Read the rubric. Gather enough unchanged context to substantiate reach, safeguards, recovery, and contracts before choosing values. Use factor anchor IDs with concrete source evidence; address every flag ID by incorporating it, recording it as a confidence input, or dismissing it with a reason. Related identical flags can share one disposition if their IDs remain accounted for.

Score each partition, apply overrides, and assess interacting partitions together. Overall risk is the highest applicable level only when the scope can be classified. Otherwise put “Overall risk: unclassified” or the supported range in the opening header; report the known portion's floor separately. Do not hide unknown scope behind a Low label or a later confidence note.

Immediately publish the preliminary rubric header before deep review. Continue automatically at the appropriate depth. For an explicit risk-only request, stop after the assessment, evidence, and uncertainty; do not launch a full review.

## 4. Review and verify

Read the review-pass reference. Changed behavior selects relevant concerns from every pass, even at Low/Moderate; risk selects tracing depth, verification, and independence. Follow the application's conventions and installed versions; reuse available Laravel/testing guidance without inventing prerequisites. Distinguish defects, documented convention violations, and optional design improvements. Do not report formatting already enforced by tooling as substantive findings.

Perform proportionate verification in a confirmed safe environment, starting with focused existing tests and applicable configured checks. Do not ask again for verification already authorized or implied by the review. Honor explicit no-test instructions. For historical/PR snapshots use matching isolated code and test configuration. Never run tests/migrations against a live or unverified database. Record unavailable checks and their implications; do not substitute an offer to test for verification that can already be done safely.

For High/Critical, when delegation is available, dispatch a bounded independent reviewer on the consequential paths. Give it the immutable scope, requirements, invariants, relevant raw source/tests, and a specific question; withhold the first reviewer's findings and verdict to avoid priming. For Critical include a challenge of failure containment/recovery. The primary reviewer must verify and reconcile findings, not vote or average scores. A fresh pass in the same context is not independent. If delegation is unavailable, perform the strongest feasible self-check and disclose the missing independent pass in the header's review-depth line and final confidence.

Findings alone do not mechanically change risk. New evidence about impact, reach, interactions, recovery, or contracts requires rescoring and, if needed, immediate expansion of review depth. A clean review alone does not lower inherent risk.

## 5. Finalize against the same snapshot

Run the collector as `verify /absolute/evidence.json` from the reviewed repository (or pass `--repo`). It rechecks original refs/PR metadata and the relevant working/index snapshot. A mismatch requires fresh evidence, reassessment, and review of affected changes/interactions. If the target keeps changing or access prevents verification, report the reviewed snapshot and incomplete current-state status explicitly.

Report in this order:
1. Final rubric header, including any uncertainty and why risk changed from preliminary.
2. Confirmed findings ranked by consequence: `[Blocking]`, `[Should fix]`, then material optional improvements. Each needs the exact snapshot/layer and file/side/line, trigger, expected versus actual behavior, consequence, evidence, and minimal correction. Keep unresolved suspicions separate. No finding count quota.
3. Verification performed and review confidence: traced boundaries, actual checks/results, independent coverage, and each material gap with evidence needed to close it.
4. Compact scoring receipt: partition membership, factor anchor IDs/evidence, overrides, flag dispositions, and coverage gaps. Put a large receipt in an accessible artifact rather than ahead of important findings.

A Low clean change can be brief, but still states scope, risk basis, findings, verification, and confidence. Completion applies only to the inspected snapshot and documented scope.

## Maintenance

`REVIEW_SENSITIVE_PATTERN` optionally overrides the collector's Python regular expression for path hints; the legacy `REVIEW_SENSITIVE_GLOBS` name remains accepted. Patterns never assign points.

Run `python3 scripts/test_collect_evidence.py` after collector edits. Calibrate rubric decisions against independently assessed representative changes, including harmless sensitive-path edits, correct high-risk changes, known defects, and incomplete evidence. Prefer demonstrated corrections over accumulating generic checklist rules.
