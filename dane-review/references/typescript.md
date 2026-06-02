# TypeScript / backend-TS review taste

Progressive-disclosure file: read when reviewing `.ts` (non-React) or backend code.
TS-language and backend-TS patterns Dane reliably flags. Phrasing → `voice.md`.

## Type modeling — make illegal states unrepresentable

- **Discriminated unions / mutual exclusion.** Multiple optional flags/args where only
  some combos are valid; a flag on a union that applies to one variant; `icon` vs
  `imgSrc` props that shouldn't coexist; runtime throws guarding bad input.
  > "we should probably make these open commands mutually exclusive in the types somewhere. confusing for the caller that if both are passed one will override (whichever comes first in the else if chain)"
- **Exhaustive switch + `exhaustiveGuard` / type-safe maps over if-else chains.** A
  ternary/if-else over an enum/union (`entityType`, run status, `hostType`, tab type); a
  new enum member that could be silently mis-assigned. He wants future additions to
  *force* a decision.
  > "nit: if we added another entry to the enum… we would silently create a bug here. instead could we assign `enrichmentMetaKey` with a switch and exhaustive guard to force anyone who adds to that type to make that decision?"
  > "would be better to use a type safe map similar to what we have elsewhere in the codebase. this ensures that if we add more types in the future we are forced to consider if a tab would need to include that new type"
- **Avoid `any` / untyped casts; parse with a schema.** An `any`; an `(x as
  Record<string,unknown>)` cast where a `.parse` exists; `id as FolderId` casts or raw
  `id.startsWith('f_')` where a branded type / type-guard would do.
  > "can we use a more specific type than `any`? if not it will require a lint override"
- **Redundant union member.** A type added to a union where it's already included via
  another member.

## Schema & validation

- **Schema reuse — single source of truth.** A hand-written schema duplicating fields of
  an existing one; a TS union plus a separate `z.enum` kept in sync; a `TableSummary`
  mirroring `Table`; a field widened to `z.string()` instead of a proper shared type.
  > "could we define this as a `pick` from `Tool`? This will require us to move `tool-schemas.ts` to shared-backend"
- **Validation/contract semantics — boundary values & predicate correctness.**
  `nonnegative` → `positive` (drops 0); `IS NOT NULL` where empty-vs-nonempty array is
  the real intent.
  > "weird edge case for sure but worth taking a look at. in theory someone might actually want a 0 budget"

## API / contract / signature design

- **Don't mix concerns; consolidate; normalize.** A prop/setter added to a schema
  unrelated to its domain; many single-purpose get/set endpoints; two arrays kept
  index-aligned; a subcommand diverging from sibling pagination.
  > "I don't think this is the right interface. we're mixing concerns between default functions and salesforce… there's a pretty good argument that we should just create a new CRUD endpoint for mcp user settings in general"
- **Signature: arg shape, naming, required vs optional, batch vs per-item.** Params
  mapped to wrong names or better as a destructured object; `callbackInfos` as a per-item
  array vs one batch callback; an optional callback better on the function signature.
  > "the implementation is correct in the sense that name and category are passed to the correct args for segment. However, they're named wrong. I think we want this signature instead:"
- **Constant / magic-value placement & canonical source.** A `DEFAULT_X` exported from a
  prod file but used only by tests; a hardcoded `*_PRESET_ID` for behavior a maintained
  feature should own.
  > "it's kinda confusing that we define this constant in the main service file and then exclusively use it for tests. it implies we have a default 500 credit mcp limit which we don't"

## Performance (backend)

- **Eliminate N+1 / extra DB round-trips; add bulk fetchers.** An awaited query inside a
  loop/`.map`; sequential `.find()`s that could join; callers passing many ids with no
  bulk service function.
  > "if it's more than a few we should definitely get rid of this N+1 query and add something like a `getToolsByIdsOrThrow` to the tool service. probably makes sense to add a bulk tool access check as well"
- **Don't transform/recompute at scale in memory.** A row-by-row transform over a very
  large result set in JS rather than at the DB level.
  > "this is a large transformation to be doing across possibly 10's of thousands of rows in memory… can you share more on why this is necessary?"

## Data layer & concurrency

- **Race condition / idempotency / uniqueness.** A create/upsert that reads-then-writes
  without a unique constraint; a migration removing one; a missing idempotency key.
  > "consider the case where two concurrent createTool or upsertTool calls occur for the same action, we could have duplicates. this is racey unless we bring back the uniqueness constraint"
- **Data model / migration intent & lifecycle.** A new nullable column; relaxing a
  uniqueness constraint; a schema baking in a design the RFC rejected.
  > "is this temporary as part of migration and then we'll backfill all of them with a budget eventually?"
- **Manage derived columns via ORM hook / DB trigger**, not a manual inline
  `entity.someUpdatedAt = new Date()`.
  > "can we have this managed with an orm hook instead? … this way we ensure if another function modifies it the timestamp is still correct"
- **Data structure fit.** A `Record`/map keyed by ids never looked up (only iterated); a
  per-user value whose storage key isn't scoped to the user id.
  > "do we need this subscription pattern to be a map? we don't use the unsubscribe function… only as a boolean to check if we called `subscribeToSourceConfigChanges`"

## Smaller TS style nits

- **Prefer ternary + `const` over `let` with later assignment.**
  > "also would prefer ternary here so we can just make it a const"
- **Prefer a default parameter over an in-body fallback** (`searchParams = {}` in the
  signature, not `if (!searchParams) searchParams = {}`).
- **Avoid hand-rolled regex / reinventing stdlib** (use `new Date()` + `toLocaleString`
  to parse dates, not manual regex).
- **Correctness bug — wrong variable / missing case / downstream breakage.** A
  rename/refactor swapping a similar-looking id/price; an upsert delegating only to
  create; a default that overwrites prior data. (Often stated *as a question*.)
  > "I think this should be `trialBillingPlanPriceId`? otherwise if you had a 2000 credit trial you would get bumped down to 1000 credits"

## Authorization & observability

- **Gating / authorization placement & redundancy.** An `assertWorkspaceCanUse…` where
  the real gate is per-entity enablement; an inline guard duplicating an assert helper.
  > "this is asserting that the workspace has more than 0 sync table limit, shouldn't it be gating on if the table is enabled for sync? … the real gating happens at the table sync enablement level"
- **Logging/observability — team tag & message quality.** `getLogger` team set wrong;
  noisy `logger.info` on routine paths.
  > "should be rep tools"
