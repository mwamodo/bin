# Laravel change-review risk rubric

The score determines the depth of review and recommended human attention. Finding severity and review confidence are reported separately — risk is what a mistake could cost, not whether a mistake was found.

Assess what a plausible mistake in the changed behavior could cause. Support that assessment with the affected execution paths and application rules.

## Scoring procedure (binding)

1. **Score each coherent behavior change separately** (partitioning happens before this file is used — see SKILL.md). Use the highest resulting level for the overall review. Assess interacting changes together when their combination creates additional risk.
2. **Use an anchor ID for each factor value, with concrete evidence.** IDs are `I0`–`I30` for Impact, `R0`–`R20` for Reach, `X0`–`X20` for Interaction, `Rec0`–`Rec20` for Recovery, and `C0`–`C10` for Contract change; only values in the table are valid. Exact quotations are optional. If no anchor fits or evidence is missing, report a supported range or unclassified factor and explain the mismatch. Never round uncertainty down to obtain a score.
3. **Address every flag ID from the Layer 1 evidence output.** Incorporate it into a factor with a reason, retain it as a confidence input, or dismiss it with evidence. For example, a `dropIfExists` in rollback code needs checking against the rollback data-loss contract; its location alone does not dismiss it. Related flags may share one disposition when all IDs are accounted for. An unaddressed flag leaves scoring incomplete.
4. **Flags and sensitive-path matches never add points by themselves.** They direct attention to behavior. A comment edit inside a policy file scores on what the comment edit can cause: nothing.
5. **Record evidence for every nonzero factor and every override** — the changed behavior, caller, configuration, or application invariant it rests on.

## 1. Scoring factors

For each factor, choose the highest applicable value. Do not add multiple signals within the same factor.

| Factor | Max | Values |
|---|---:|---|
| **Impact — consequences of incorrect behavior** | **30** | **0:** No change to executed behavior, operational instructions, or meaningful user-facing information. **5:** Cosmetic or informational error with limited consequences. **10:** A bounded operation fails, produces incorrect results, or saves incorrect but repairable application data. **20:** Unauthorized access, sensitive information disclosure, incorrect financial results, unintended external actions, or serious disruption of a business workflow. **30:** Substantial permanent data loss, widespread sensitive disclosure, major financial damage, or prolonged failure of an essential service. |
| **Reach — how far the failure can propagate** | **20** | **0:** No production execution or operational effect. **5:** One operation and the records directly involved. **10:** Multiple callers or workflows, a shared subsystem, or a bounded team-wide operation. **20:** A shared application boundary, multiple tenants, an unbounded batch, or an application-wide deployment effect. |
| **Interaction — difficulty of reasoning about execution** | **20** | **0:** Demonstrably no execution change. **5:** A straightforward synchronous path with explicit inputs and effects. **10:** Interacting business rules, complex queries, observers, listeners, global scopes, or multiple components with implicit effects. **20:** Correctness depends on concurrency, locks, retries, duplicate or reordered events, transaction timing, or coordination between the database and an external system. |
| **Recovery — difficulty of undoing incorrect effects** | **20** | **0:** Reverting the code restores behavior without repairing state. **5:** Recovery requires a bounded retry, cache rebuild, or straightforward correction. **10:** Recovery requires compensating operations, coordinated data repair, or reconciliation with another system. **20:** Effects cannot be undone, or recovery requires substantial restoration, downtime, or reconstruction. Examples: disclosed data, delivered messages, destructive data changes. |
| **Contract change — assumptions other code or deployments depend on** | **10** | **0:** Existing interfaces, meanings, and lifecycle expectations remain intact. **5:** Adds or changes a bounded internal contract or business rule that a caller must accommodate. **10:** Changes a shared API, persisted meaning, event or job payload, integration protocol, or compatibility between deployed application versions. |

**Total = Impact + Reach + Interaction + Recovery + Contract change**

Score consequences attributable to *this change*. An application's ability to charge money does not make every edit in that application financially consequential.

Contract points measure changed promises or compatibility assumptions, not every implementation edit. Adjusting retries or correcting an ownership filter while preserving their established contracts can remain C0. Changing what input is valid changes the caller's contract and is at least C5.

Note (deliberate weighting): irreversibility contributes to both Impact (permanence of loss) and Recovery (inability to undo). An irreversible, widespread failure is *meant* to dominate the scale. Do not "fix" this by scoring one of the two at zero.

## 2. Risk levels and required review depth

| Score | Level | Minimum review work | Recommended human attention |
|---:|---|---|---|
| **0–19** | **Low** | Inspect every changed part, confirm the scope is bounded, and perform proportionate verification. | Briefly read the summary and any findings. |
| **20–39** | **Moderate** | Trace affected callers, business rules, and tests. Verify relevant success and failure cases. | Check intended behavior, findings, and verification gaps. |
| **40–69** | **High** | Trace complete affected workflows and their critical invariants. Investigate applicable authorization, persistence, integration, and failure boundaries. Include a targeted independent review when available; disclose when it is missing. | Examine critical assumptions, supporting evidence, and unresolved risks. |
| **70–100** | **Critical** | Apply High requirements, independently challenge the consequential paths, and verify deployment compatibility, failure containment, and recovery where applicable. | A knowledgeable owner should examine the critical paths and operational consequences before release. |

These are minimums. A Low classification still requires inspecting all changes in scope and addressing every relevant concern. Behavior selects security, performance, data, async, and deployment checks at any level; the level controls their depth and independent verification.

## 3. Minimum risk overrides

Apply these after calculating the score. Preserve the numerical score and explain any override.

**At least High when the change materially alters:**

- Authentication, authorization, tenant ownership, impersonation, token capabilities, or verification of trusted inbound requests (webhook signatures, signed URLs).
- Financial calculations or operations that can charge, pay, refund, or change balances.
- Safeguards against duplicate consequential effects: relevant idempotency, locking, uniqueness, and transaction behavior.
- Destructive persistence behavior, or a schema/contract transition that requires coordinated deployment to avoid corruption or service failure.

**Critical regardless of score when there is an evidenced, plausible path to:**

- Bulk or cross-customer permanent data loss or widespread sensitive disclosure.
- Unbounded financial or external effects without an established containment mechanism.
- Failure of an essential service requiring substantial restoration because ordinary rollback cannot recover it.

Overrides apply to **changed behavior and its consequences**. A comment inside a policy, a billing-page spacing adjustment, or an unused additive database column does not inherit an override from its filename.

## 4. Rules that prevent misleading scores

- **Do not sum unrelated changes.** Ten Low changes do not automatically become Critical. A larger scope increases the work needed to establish coverage, not the risk level.
- **Do not subtract points for passing tests, a trusted author, familiar code, or a previous approval.** Those may strengthen evidence; they do not erase the consequences of a mistake.
- **Do not score an unknown factor as zero.** Record the uncertainty and a supported range; use its higher supported review level until resolved. Where content/effects cannot be established with available viewers, source/build evidence, or dependency inspection, report **"unclassified"** for that partition. File type alone is not an inability to review. If any partition prevents an overall bound, the first header must say **"Overall risk: unclassified; assessed portion at least [level]"**. Known overrides still establish a minimum depth. Never report an overall Low classification while hiding unclassified scope in later notes.
- **Distinguish missing evidence from inherent complexity.** Unavailable integration tests reduce review *confidence*. A newly introduced distributed retry protocol increases *Interaction* risk. Weakened or deleted tests are confidence signals, never risk discounts — and never risk points either.
- **Reassess when scope or understanding changes.** A finding can reveal larger reach, irreversible effects, or a missing safety boundary: update the factors and expand depth immediately when that evidence warrants it. Neither finding count nor a clean result mechanically changes risk. Explain upgrades and downgrades in the final report.

## 5. Calibration examples

Assume the stated scope; actual callers and deployment behavior can change the rating.

| Change | I / R / X / Rec / C | Result |
|---|---|---|
| Correct ordinary interface wording on one screen | 5 / 5 / 0 / 0 / 0 | **10 — Low** |
| Change validation for an ordinary editable field, bounded correction if wrong | 10 / 5 / 5 / 5 / 5 | **30 — Moderate** |
| Change an invoice calculation used by several billing operations | 20 / 10 / 10 / 10 / 5 | **55 — High** |
| Change retry handling for a job that sends customer messages | 20 / 5 / 20 / 20 / 0 | **65 — High** |
| Change a shared tenant-ownership filter controlling access to sensitive records | 20 / 20 / 5 / 20 / 0 | **65 — High** (security override independently establishes the minimum) |
| Bulk migration that permanently deletes customer data and changes its persisted representation | 30 / 20 / 10 / 20 / 10 | **90 — Critical** |

## 6. Risk header format

Emit this as the **preliminary** header immediately after scoring (before deep review), and again as **final** in the report:

> **Change risk: High — 65/100, preliminary.**
> **Drivers:** Retry behavior, duplicate sends, and irreversible delivery.
> **Review depth:** Trace dispatch through provider completion; examine retries, duplicate execution, and failure recovery.
> **Your attention:** Focus on the evidence that repeated execution cannot cause unintended sends.

The final report repeats the classification, explains any change from the preliminary assessment, and separately states findings, review confidence, and incomplete verification.

Include the reviewed scope/snapshot beside either header. If uncertainty remains, replace the first line rather than appending a reassuring definite label:

> **Overall risk: unclassified — preliminary; assessed portion at least Moderate.**
> **Drivers:** The application changes are bounded, but a changed compiled asset has not been inspected or linked to reviewed source.
> **Review depth:** Review the known changes at Moderate depth and resolve the asset's effects before claiming an overall classification.
> **Your attention:** The current evidence cannot establish the risk of the complete change.

For supported numeric ranges, show the range and use the higher supported level for review. If an independent pass required by the chosen depth is unavailable, disclose that in the review-depth line as well as final confidence.
