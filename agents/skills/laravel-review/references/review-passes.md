# Review passes by risk level

Use these questions to account for relevant concerns. The changed behavior selects checks from all concerns, while risk controls depth and independence. Shared traversal is fine when the evidence for each concern remains clear. Skip irrelevant items silently; record **"could not verify"** explicitly.

| Level | Required passes |
|---|---|
| Low | 1 plus applicable items from 2–6; inspect every change and confirm bounded effects |
| Moderate | 1 plus applicable items from 2–6; trace affected callers and verify relevant success/failure behavior |
| High | Applicable concerns from 1–6 with end-to-end tracing, focused verification, and a bounded independent pass |
| Critical | High requirements plus pass 7; independently challenge the consequential invariants and recovery |

Explicit routing examples: query/relationship/pagination/cache changes require performance checks even at Moderate; config/build/schema changes require deployment checks even at Low. Risk cannot excuse omitting the concern the change actually affects. Unclassified scope follows the rubric's uncertainty handling and remains visibly incomplete.

**Context expansion (mandatory before passes 2+, proportionate even at Low):** for each changed element, find what the diff doesn't show —

- Changed method/signature → callers (start with narrow `rg` searches, then inspect dynamic/interface/container dispatch where relevant).
- Changed controller → the routes that hit it, and every middleware on those routes.
- Changed model → its observers, global scopes, `$casts`/`$fillable`/`$hidden`, factories, and the API resources that serialize it.
- Changed event → all listeners (sync or queued?); changed listener → all events it hears.
- Changed migration → does the model/code agree with the new schema? Is there a deploy-order dependency (code reads a column the migration drops)?
- Changed scope/relationship → every query that inherits it.
- Changed config key → every `config()` read of it.
- Changed validation → every entry point that relies on it (is the same field writable via another route, console command, or job?).

## Pass 1 — Correctness & scope (always)

- Does the change do what the stated intent (commit message / PR description) claims — and **nothing else**? Flag unrelated edits riding along.
- Read every hunk. For each: what breaks if this line is wrong?
- Edge inputs on changed paths: null/empty, missing relations, unauthenticated user, zero/negative amounts, timezone boundaries.
- Conventions: does it match documented rules and established neighboring patterns? Separate material convention violations from defects and optional design advice. Avoid reporting style already enforced by tooling.
- Leftover debug output, commented-out code, dead code introduced.

## Pass 2 — Security

- **Authorization on every changed entry point**: route middleware, policy/`authorize()`/`Gate`, and Livewire/console/job entry points that reach the same behavior. One unauthorized endpoint outweighs everything else in the review.
- Tenant/ownership scoping: route-model binding scoped correctly? Queries filtered by owner, or relying on a global scope that this change bypasses (`withoutGlobalScope`)?
- Mass assignment: what does the request actually allow through to `fill`/`create`? `$guarded = []`, `forceFill`, `->all()` into create.
- Injection: raw SQL fragments with interpolated variables; `{!! !!}` on user-influenced data; user input into shell/file paths.
- Data exposure: API resources vs. returning models; `$hidden` respected; new fields in payloads, logs, or error messages.
- Inbound trust: webhook signature verification, signed URL checks, TLS verification not disabled.
- File uploads: mime/size validation, storage disk visibility, filename handling.
- Secrets: nothing hardcoded; `env()` only inside `config/`.

## Pass 3 — Data integrity

- Multi-write operations: does the transaction cover the intended all-or-nothing boundary? For external effects, establish ordering, idempotency, failure handling, and lock duration. A database rollback does not undo a provider action; evaluate the actual design rather than treating transaction placement alone as a defect.
- Check-then-write races: uniqueness enforced at DB level or just in validation? `lockForUpdate`/atomic `increment` where balances or counters change.
- Idempotency of anything that retries: jobs, webhook handlers, scheduled commands. What happens on double execution?
- Migrations: reversible? Destructive steps deliberate and sequenced (deploy code before/after schema as required)? Data backfill correctness on large tables (chunked?).
- Soft deletes: do changed queries/relationships leak or wrongly exclude trashed rows?
- Representation: money as integers/decimal (never float math), timezones explicit, enum/status values consistent with DB and code.

## Pass 4 — Async & failure semantics

- Queued jobs using Laravel model serialization re-retrieve models at execution. State can differ from dispatch time or records can be gone; examine stale assumptions, missing-model handling, and any intentionally captured values against the installed version.
- Retry math: `$tries`, `backoff`, `retryUntil` — what is the worst-case total effect of max retries (e.g., N emails, N charges)?
- Check transaction-aware dispatch when a job depends on committed writes. Verify the installed version's APIs and effective queue configuration. Unique jobs and overlap locks can help coordinate work; they do not by themselves prove idempotency of an external effect across crashes/retries.
- `failed()` handlers: does failure leave consistent state? Is anyone notified?
- Event listeners: sync listeners doing slow work in request path; queued listeners with the same staleness issues as jobs.
- Chained/batched jobs: partial-failure behavior.

## Pass 5 — Performance

- N+1: check the **consumers** of changed relationships — Blade loops, API resources, `->map()` over models. Eager loads present and still correct after the change?
- New/changed `where`/`orderBy` columns: is there an index that serves the actual query shape?
- Unbounded reads: `->get()` on tables that grow; use of `chunk`/`cursor`/`lazy` where sets are large.
- Cache: invalidation on the writes this change introduces; stampede risk on hot keys; stale-read consequences.
- Payload weight: columns selected, resources serialized, jobs carrying large payloads.

## Pass 6 — Deployment & compatibility

- Order of operations: can old code run against the new schema and new code against the old schema during rollout? If not, is the transition staged?
- Config/env: new keys present in `.env.example`; behavior with the key absent.
- Queue payloads in flight: will jobs serialized before deploy deserialize after (renamed classes, changed constructors)?
- Rollback story: if this deploy is reverted in 10 minutes, what state remains?

## Pass 7 — Adversarial challenge (Critical required)

Challenge the consequential paths with concrete attempts to violate their invariants. For High/Critical, SKILL.md also requires a bounded independent reviewer when available. Give that reviewer raw scope/requirements/source without earlier verdicts; a reread by the same reviewer is not independent.

- For each "verified" invariant, construct the concrete scenario that would violate it (concurrent request, retry storm, malicious payload, partial deploy) and check it is actually excluded.
- Have the independent reviewer derive risk from the source evidence before receiving the earlier scoring; reconcile differences by examining evidence, not averaging votes. If independence is unavailable, label the self-check accurately and disclose the gap.
- State plainly what was **not** verified and what evidence would close each gap.

## Verification (all levels, proportionate to behavior)

Follow repository instructions and the user's existing authorization. Start with focused tests for affected behavior and configured checks (Pint in check mode, relevant static-analysis scope); use broader suites only when the change or findings warrant them. Preserve a configured analysis scope where limiting to changed files would miss dependent types. Exercise entry points for authorization, relevant concurrency/retry behavior, and actual query behavior for performance changes.

Run safe verification already authorized or implied by review without another permission question. Honor explicit no-test limits. Confirm disposable test storage and faked/isolated external effects before potentially mutating tests; never target live or unverified services. If the environment is unsuitable, record the exact gap and its effect on confidence instead of claiming a pass. Historical/PR tests must execute the reviewed revision, not an unrelated checkout.
