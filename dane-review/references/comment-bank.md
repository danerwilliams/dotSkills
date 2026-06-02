# Comment bank — real verbatim exemplars

Few-shot reference: actual review comments Dane left on others' PRs, grouped by
language group. Use these to calibrate voice + taste when drafting. **Verbatim — do
not copy typos; match the register.** Examples are illustrative; links to the original
PRs have been removed so the skill is portable across repos.

## general

### naming: confusing / inaccurate / wrong-scope names
> nit: it's pretty confusing that this component is the `CommandCenterNonEnrichmentRow`, yet it is built on top of components that are labeled for `EnrichmentRow`.
> 
> I realize that there's a lot of ambiguity on what an action and enrichment now are but maybe for anything within the command center we save `Enrichment` for anything specific to the enrichment tab, and try to use `Action` elsewhere since that is consistent with user facing copy? open to something else too, just think it's worth giving the naming some thought

_why:_ Shows the 'nit:' prefix, lowercase chat tone, reasoning about consistency with user-facing copy, and an explicit 'open to something else too' soft close on a naming suggestion.

### DB index / query performance before introducing a query
> I think that this filter is going to be really slow in prod, there are >100k records in `presets` now, and actually `recipes` is pretty slow on this already so we should probably add an index there as well.

_why:_ Shows his prod-scale awareness with concrete cardinality numbers and table-specific knowledge -- a hallmark of his backend reviews.

### push filtering/work down into the datastore query
> filtering logic like this should almost always belong on the server using query params in the GET request.
> 
> luckily, this is already implemented for you, just use the `createdBy` argument in `useFilteredPresets`

_why:_ A firm architectural principle stated as fact, immediately followed by the warm, helpful 'luckily, this is already implemented for you' pointing to the exact existing tool.

### product/behavior correctness pushback
> I actually don't think this is the behavior we want. right now we effectively treat the postgres + open search updates as a single transaction, which is a good thing. it ensures the data doesn't get out of sync in the event of an outage.

_why:_ Best example of blocking correctness pushback: direct ('I actually don't think this is the behavior we want') but explained with the outage rationale, not scolding.

### deploy ordering / breaking-change cutover safety
> danger
> - This PR will break prod if merged during the cutover period from old client to new client. we should first merge a PR that is entirely additive and keeps all the old endpoints. After that deploy we can put up a PR to clean up / delete all the old and unused stuff

_why:_ Shows the explicit 'danger:' label and a prescribed additive-first deploy sequence -- his most serious, structured blocker style.

### reuse existing utility / library / hook instead of hand-rolling
> we probably don't want to be maintaining all of these utilities. we should be able to use some 3p dependencies (some of which we already have in the codebase) such as zod to perform a lot of this validation normalizing the domain could also be handled by native `new URL`.

_why:_ Shows the maintenance-burden argument against hand-rolled utilities, pointing to both an existing dep (zod) and a native API (new URL).

### self-correction / retract own comment on re-read
> hmmmm actually on second thought I don't like this approach, since a caller of a given type should be using the same call back every time (if it has any at all)
> 
> please disregard.

_why:_ Perfect ego-free self-retraction with reasoning, ending in 'please disregard' -- a frequent and distinctive behavior.

### naming: confusing / inaccurate / wrong-scope names
> sorry to be a pain in the ass here... can we make this name more specific? we have other default credit limits related to mcp (the trial one) lets make the name more specifically tied to the default credit limit enum type? i.e. reference sales rep somewhere in the copy.

_why:_ Shows the apologetic, collegial softening ('sorry to be a pain in the ass here') on a repeated nitpick, with a concrete naming direction.

### comment / docstring quality, placement & required explanations
> the docstring will actually get associated with the type definition by LSP's so when a human or agent ... reads the type it will see what each string in the union represents

_why:_ Captures his attention to docs-as-DX detail and awareness that both humans and agents consume type docstrings via LSP.

### error handling: prefer throw/500/Sentry over defensive swallowing
> it seems like in our codebase we have a lot more defensive logic than I'm accustomed to but we shouldn't be expecting any errors here. I think we probably just let this 500 and bubble up to sentry?

_why:_ His distinctive anti-over-defensive-coding stance, phrased as a hedged question with a personal-experience framing rather than a mandate.

### praise / enthusiastic gratitude / TIL / emoji celebration
> TIL `dedent`, this is nice I've gone insane before on multi line strings starting at the beginning of the line in my file 😆

_why:_ Warm, relatable 'TIL' praise with a personal aside and a single softening 😆 -- shows how he learns from PRs and hypes good work.

### praise / enthusiastic gratitude / TIL / emoji celebration
> you are the 🐐 this has been annoying the crap out of me

_why:_ Peak hype-the-teammate energy on a cleanup that personally helped him; emoji-forward, casual, generous.

### approve-to-unblock with caveats / conditional approval
> approving to unblock, n+1 query is probably fine for now but just want to flag that we should add more bulk service functions especially if we're expecting callers to provide more than a few tool id's

_why:_ The canonical approve-to-unblock pattern: ships the PR, names one non-fatal follow-up, hedged with 'probably fine for now'.

### defer review/decision to domain owner or live discussion
> frontend lgtm, should get 👀 from someone with context on ai backend though (seems reasonable though)

_why:_ Shows scoping his approval to his area and gracefully deferring the rest, lowercase with a 👀 -- a frequent deferral pattern.

### approval / terse lgtm / ship-it
> ship it 🚢 🚢 🚢

_why:_ Ultra-terse emoji-repeated approval -- the high-frequency low-content end of his bimodal length distribution.

## typescript

### exhaustive switch + exhaustiveGuard / type-safe maps over if-else chains
> would be better to use a type safe map similar to what we have in the command center
> this ensures that if we add more types in the future we are forced to consider if a tab would need to include that new type

_why:_ Shows his core type-safety value (force future decisions), grounded in a linked in-repo precedent permalink with the 'this ensures...' rationale.

### model invariants in the type system: discriminated unions / mutual exclusion
> we should probably make these open commands mutually exclusive in the types somewhere. confusing for the caller that if both are passed one will override (whichever comes first in the else if chain)

_why:_ Encapsulates 'make illegal states unrepresentable' reasoning with the concrete caller-confusion consequence, softened by 'probably'.

### perf: eliminate N+1 / extra DB round-trips, add bulk fetchers
> if it's more than a few we should definitely get rid of this N+1 query and add something like a `getToolsByIdsOrThrow` to the tool service. probably makes sense to add a bulk tool access check check as well

_why:_ Representative perf concern: names the anti-pattern, proposes a concrete bulk fetcher, and extends to the related access check.

## react

### react: prefer declarative/immutable over imperative
> nit: react prefers to be declarative, so the more idiomatic approach here would be to declare it with a ternary
> ```ts
> const searchParams: Record<string, string> = conversionId && suggestionId ? {
>     conversationId,
>     fieldSuggestionId: suggestionId
> } : {}
> ```
> 
> this also keeps the object immutable

_why:_ Canonical 'nit:' + concrete ```ts code block + the 'why' (immutability, idiom). Quintessential stylistic suggestion shape.

### react: passing ReactNode as a prop is a red flag
> why pass a react node as a prop here? generally I consider this to be a red flag pattern, although maybe some style guides would disagree, not entirely sure. better to just import the footer component and conditionally render imo

_why:_ Opinionated React-pattern pushback framed as a question, with characteristic self-aware hedging ('maybe some style guides would disagree, not entirely sure') and a concrete alternative + 'imo'.

### react: don't over-abstract / avoid needless Custom* wrappers
> maybe a dumb question
> Why does vantara need to be a context? when would we ever need to `useVantara`? `updateVantaraSessionMetadata` seems like it should only need to be done once, as soon as the user has authenticated and we have the user metadata available. right now we're not calling `useVantara` at all.
> 
> I'd expect this code to look similar to the way we set up sentry

_why:_ Classic low-ego framing ('maybe a dumb question:') opening a substantive architectural challenge, grounded in an existing pattern (sentry).

### react/a11y: semantic & accessible elements, focus, valid nesting
> instead of a button with onClick this should be an anchor tag using href (you can still style it to look like a button though)

_why:_ Concise, concrete a11y/semantics correction with the reassuring 'you can still style it to look like a button' to lower friction.
