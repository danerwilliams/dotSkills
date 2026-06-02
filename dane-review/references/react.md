# React / frontend review taste

Progressive-disclosure file: read when reviewing `.tsx`/`.jsx` or frontend code.
Dane is opinionated about idiomatic React. He grounds many of these in the repo's
React patterns doc (e.g. a `REACT_PATTERNS.md`), if one exists — cite it when relevant.
Phrasing → `voice.md`.

## Hooks & state

- **`useRef` vs `useState` misuse — avoid the `useRef` escape hatch.** A `useRef` holding
  a boolean flag (`initializedRef`), a promises map, or state-like data that should
  trigger renders.
  > "this can just be `useState` and then our effect can return early if we've already initialized"
- **`useEffect`-watching-state anti-pattern.** A `useEffect` depending on a state/derived
  value whose body fires a side effect/callback in response to that value changing. Call
  the handler at the point of state transition instead.
  > "this is an anti pattern in our react guidelines (see the team's REACT_PATTERNS doc). can we call this handler at the points of state transition instead of watching their values in a useEffect?"
- **Don't recompute on every render / unnecessary `useMemo`.** An expensive/derived
  computation (`new Date()`, filtering) in the render path with no `useMemo` — OR a
  `useMemo` wrapping a hook return where a direct object return would do.
  > "we don't need to do all of these calculations on every re render. could we move into something like this? `const isPlanEndingSoon = useMemo(() => {…}, [])`"
- **Extract big inline `useMemo`/`useCallback` bodies; prefer pure functions.** A
  multi-statement anonymous function inlined into `useMemo`/`useCallback`; a `useCallback`
  wrapping essentially-pure logic.
  > "nit: this is a pretty big function to toss directly into useMemo in the component body. consider extracting to a pure function"
- **Prefer a dedicated hook variant / existing abstraction** over a lower-level API
  (`useEppoFeatureFlagAsBoolean` instead of the general one).
- **React Hook Form for multi-input forms** validated on submit.
  > "Feels like this should now be using react hook form. Can you please TAL at moving to RHF before merging?"

## Component structure

- **A function returning JSX should be a component** (not a local arrow returning a
  `ReactElement`, not an element assigned to a variable).
  > "A function that takes react node children as args and returns a react element should always be a component"
- **Passing `ReactNode` as a prop is a red flag.** Import the component and conditionally
  render instead.
  > "why pass a react node as a prop here? generally I consider this a red flag pattern, although maybe some style guides would disagree, not entirely sure. better to just import the footer component and conditionally render imo"
- **Extract a presentational subcomponent / avoid chained double ternary** in JSX.
  > "Would probably extract this into a component like `SearchFilterChip` so that it's more clearly labeled"
- **Don't over-abstract — avoid needless `Custom*` wrappers / unused Context.** A
  component copied into a `Custom*` variant used in one place; a Context+provider+hook
  where the hook is never called and the value is set once.
  > "`AISearchInput` is only used here, so we shouldn't make these additional components. instead we should just modify `AISearchInput`"
- **Hook too long → split by concern.** A hook accumulating many responsibilities where a
  cohesive slice could be its own hook.
  > "this is becoming a pretty long hook with a lot going on, what if we broke these out into `useAiChatSourceConfig`? I think it would improve soc"
- **Separation of concerns / deprecated vs modern boundaries** (frontend). Adding a modern
  type (`IconId`) into a type marked deprecated; a cleanup removing a string variant the
  backend actually serializes.
  > "my understanding is that `IconId` is for our modern icons whereas this `IconType` is deprecated, so we don't want to add `IconId` to the enum from an soc standpoint" (check with the owner)

## Rendering idioms

- **Prefer declarative / immutable over imperative; filter at render-time.** `let x =
  default; if (cond) x = other;` → const ternary; a `useMemo` filtering a results array to
  remove an entity when a per-item early return exists.
  > "nit: react prefers to be declarative, so the more idiomatic approach here would be to declare it with a ternary: `const searchParams = a && b ? {…} : {}`. this also keeps the object immutable"
- **Simplify JSX.** Hand-written repeated `<Skeleton/>` siblings → `Array.from({length:
  3}).map(...)`; redundant work computed only to be returned.
  > "can simplify to `{isLoading ? Array.from({ length: 3 }).map((_, index) => …`"
- **Question unnecessary cache revalidation / conditional-render correctness.** A
  `revalidateOnSuccess` listing a resource unrelated to the mutation; a provider whose
  value depends on setup that may be skipped behind a flag.
  > "why are we revalidating the sync status when flipping this flag?"
- **`index`-as-key.** An `eslint-disable react/no-array-index-key`; suggest deriving a
  stable key from the row's own properties.

## Accessibility & semantics

- **Semantic & accessible elements, focus, valid nesting.** `<Button onClick>` that
  navigates → anchor with `href`; a `<button>` nested in `<a>`; opacity-0 controls
  revealed only on group-hover with no focus-within.
  > "instead of a button with onClick this should be an anchor tag using href (you can still style it to look like a button though)"
  > "nice accessibility :-)" (he also praises good a11y)

## Styling

- **Tailwind shorthand / scale tokens over arbitrary values.** `ml-[40px]` where `ml-10`
  exists.
  > "`ml-10` ?"

## Data flow (frontend)

- **Push filtering/work to the server** rather than `useMemo`-filtering a fetched list —
  see `general-review.md` (he applies this heavily in frontend).
- **Loop in design** on self-authored loading/styling treatments — see `general-review.md`.
