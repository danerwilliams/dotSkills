# General review taste (language-agnostic)

What Dane flags regardless of language, ordered roughly by frequency. Each entry is
a **trigger** to scan for, plus how he phrases it. Raise candidates; let Dane decide.
Draft any comment in his voice (`voice.md`).

## Naming & clarity

- **Confusing / inaccurate / wrong-scope names.** A name contradicts what the thing
  is/does (`CommandCenterNonEnrichmentRow` built on `EnrichmentRow` components); a
  `Type` suffix on a non-type; a prop that overloads an existing domain concept; a
  function named for one consumer but used by all surfaces; a constant that collides
  with another.
  > "nit: it's pretty confusing that this component is the `CommandCenterNonEnrichmentRow`, yet it is built on top of components labeled for `EnrichmentRow`… open to something else too, just think it's worth giving the naming some thought"
  > "could we rename to something like `isAllowedToolsEnrichmentAction`? the claygent specific naming felt out of place"
- **Enum-ify magic strings to encourage reuse.** An API takes `category`/`name` as a
  bare `string` where a finite set exists in practice.
  > "nit: I wonder if it's worth switching category and name to string enums so that people are more likely to reuse an existing one"

## DRY / reuse / single source of truth

- **Extract repeated logic into a shared helper/hook.** Two near-identical helpers; a
  block repeating an earlier section; same logic in two files; a flag-fetch+parse
  repeated across functions. Name the existing duplicate's location.
  > "extract to helper?"
- **Reuse an existing util / library / native API instead of hand-rolling.** Hand-rolled
  debounce/timeout, manual refetch, custom domain/date parsing, hardcoded TLD lists.
  > "should we use `useDebounce` instead of managing it ourselves?"
  > "we probably don't want to be maintaining all of these utilities… use some 3p deps (zod), and normalizing the domain could be handled by native `new URL`"
- **Single source of truth / dedup data.** Data computed separately from its canonical
  source; a denormalized field added where a downstream join would do.
  > "can we actually join in the tool access info… and use that as source of truth for N surfaces (mcp, api, etc.)"

## Dead code & scope

- **Delete dead / leftover / commented-out code.** Commented-out blocks, an exported
  function with no caller, a `_`-prefixed "preserved for future use" handler. Don't
  keep it "for later" — recover from git history.
  > "remove?"
- **Unintended / out-of-scope / unrelated changes.** A value changes unrelated to the
  PR's stated purpose; files with nothing to do with the title.
  > "was this supposed to change?"
  > "this diff seems like it has a bunch of unrelated stuff in it?"

## Comments & docs

- **Add a missing explanation** for non-obvious logic, special-case branches, or
  legacy/fallback paths.
  > "add comment to explain that we need to refetch to see if a conversation id has been added"
- **Fix misleading comment/doc wording** (an ambiguous word like "context" read as
  React context; a docstring that belongs on the type so LSP shows it).
- **Link a Linear ticket** for any `// TODO:` or noted future work.
  > "link a linear ticket?"
- **User-facing copy shouldn't leak implementation detail** (`(POST /tables/query)` in
  a help string).
  > "bad description, the CLI consumer doesn't need to know about the underlying implementation of this flag"

## Error handling & resilience

- **Prefer throw / 500 / Sentry over defensive swallowing.** A try/catch that logs and
  continues on a should-never-happen path. (But keep *intentional* defensive code that
  states its reason.)
  > "we shouldn't be expecting any errors here. I think we probably just let this 500 and bubble up to sentry?"
- **Resilient concurrent/async patterns.** `Promise.all` over independently-failable
  tasks; a floating promise / `.then()` without `.catch()`; error-propagating work in a
  hot write path.
  > "we should probably use `allSettledAndLogRejected` here instead"

## Performance & data access

- **Add a DB index before introducing a query** on a known-large table (presets >100k,
  recipes); use `CONCURRENTLY` on hot tables.
  > "I think that this filter is going to be really slow in prod, there are >100k records in `presets`… we should probably add an index"
- **Push filtering/work down into the datastore.** A `useMemo`/`.filter()`/dedup over a
  fetched list the query could express.
  > "filtering logic like this should almost always belong on the server using query params… luckily, this is already implemented for you, just use the `createdBy` argument in `useFilteredPresets`"

## Correctness & product behavior

- **Product/behavior correctness pushback.** A change alters user-visible behavior or a
  correctness guarantee (data-sync transaction, role permissions, what's shown).
  > "I actually don't think this is the behavior we want. right now we treat the postgres + open search updates as a single transaction… it ensures the data doesn't get out of sync in the event of an outage"
- **Question unused/mystery params, flags & impossible cases.** An underscore-unused
  param; a boolean toggled with no explanation; an `if (userId === null)` on a join
  table where it can't be null.
  > "why are we passing this at all if it's going to be unused?"
- **Feature-flag gating / visibility safety.** A new entity with `isPublic: true`; flag
  removal exposing behavior to all; UI that should appear in both variants.
  > "where is this being gated now? from what I can tell we're going to generate alpha plays for all new workspaces now"
- **Event-handler / trigger coverage.** A trigger added to some mutation events but a
  sibling mutation (`restoreRecords`) doesn't fire it.
- **Cross-system / out-of-band sync awareness.** New record/preset types feeding
  background sync / semantic-search jobs.

## Deploy & cutover safety

- **Deploy ordering / breaking-change cutover.** A refactor replacing endpoints/clients
  in one shot; merge-order-dependent PRs. Use the `danger:` label + an additive-first
  sequence.
  > "danger: This PR will break prod if merged during the cutover… we should first merge a PR that is entirely additive and keeps all the old endpoints. After that deploy we can clean up the old stuff"

## Process & verification

- **PR title / conventional-commit accuracy** ("feat" for a refactor).
- **Add integration/endpoint tests** for new GET/PUT endpoints.
  > "can we add integration tests for this endpoint?"
- **CI/lint should be comprehensive**, not scoped to one tool.
  > "can we make this more comprehensive than just prettier? … this check should basically be a 'make sure there are no autofixes available' check"
- **Loop in design / domain owner on UX** (self-authored loading/styling, novel UI).
  > "can you ask john doe and / or jane doe about a loading state here?"
- **Request a screen recording / live verification** when the UX outcome isn't obvious
  from code, or it touches auth/checkout permutations.
  > "mind sending me a screen recording just to verify that I'm on the same page as you?"

## Integration / platform / security (general, not TS-specific)

- **Design/security questions on integration specifics.** Static OAuth registration vs
  DCR; IP-range/redirect-uri inconsistency; functionality a vendor API already provides.
  > "is copilot going to be registering statically? if they're using DCR (which all our existing clients do) then we should have an IP range to be consistent"
- **Question whether the change belongs in code at all** (something better expressed as
  data/config).
  > "why does this require a change in code? the waterfall configurations are defined in the database and edited from the admin panel"
- **Question a version bump's motivation.** "was there a specific feature we really
  wanted out of the 5.9 rc that stable 5.8 did not have?"

## Tooling / DX / agent config

- **Script organization & maintainability.** A complex inline shell one-liner in
  package.json → extract to a `.sh` file; a raw `yarn tsx path/…` that should be a yarn
  command; consolidate into a single unified devtool/storybook entry point.
- **Agent/docs config:** prefer `@`-import syntax so files load **lazily not eagerly**;
  question a new cursor rule duplicating `AGENTS.md`/`CLAUDE.md` that's auto-picked-up.
  > "should we be using import syntax here?"
- **Prompt / LLM-tool description quality.** Be more aggressive/consistent in tool
  description prompting.

## Review *stances* (decision behaviors — phrasing in `voice.md`)

These shape how Dane *responds*, not what he hunts for:
- **Approve-to-unblock with a flagged caveat** when an issue is non-fatal. Don't gate.
- **Defer to the named domain owner / discuss live** when it's outside his area.
  > "frontend lgtm, should get 👀 from someone with context on ai backend though"
- **Reason aloud / shower thoughts** — seed a future improvement, explicitly non-blocking.
- **Self-retract fast** when he realizes he misread ("on second thought… please disregard").
- **Concede to a peer/bot's review on second pass** and amplify it with his own concrete
  fix (distinct from retracting his own take).
- **Cite an automated reviewer** (codex/claude) or ask `@claude` to deep-dive a risky area.
