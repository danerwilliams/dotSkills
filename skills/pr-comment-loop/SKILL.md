---
name: pr-comment-loop
description: >-
  Loop over every review, inline comment, and bot comment on a pull request until the
  bots stop finding things: for each comment either dismiss it with a reply or accept it
  and fix it in a new commit, respond directly to inline threads (and blockquote + @-tag
  the author on PR-body/review comments), push, wait out the bot buffer, and re-check.
  Every AI-posted reply is signed [Model, Effort, Harness]. Use when asked to "address
  the PR comments", "respond to the review", "clear the bot comments", "resolve coderabbit
  / greptile feedback", or "loop on the PR until it's clean". Writes replies in Dane's
  voice (see the dane-review skill).
allowed-tools: Bash, Read, Edit, Write, AskUserQuestion
---

# PR comment loop

Work a PR to zero unaddressed comments. Each pass: fetch every comment you haven't
answered → for each, **dismiss** (reply with why) or **accept** (fix in a new commit +
reply) → push → wait out the bot buffer → re-fetch. Stop when a post-buffer fetch shows
no unaddressed **bot** comments left.

Two hard rules:
- **Every reply you post is attributed** — it ends with `[Model, Effort, Harness]` so it's
  obvious Dane didn't hand-type it. The script appends this for you.
- **Write in Dane's voice.** Load the `dane-review` skill's `references/voice.md` and use it.
  If that skill isn't available, apply the cheat-sheet at the bottom of this file.

## Setup (once, before the loop)

1. **Resolve the PR.** If not given, `gh pr view --json number,headRefName,url`. If the
   branch has no PR or it's ambiguous, ask.
2. **Confirm attribution values** — you pass these to every reply:
   - `--model` — your model name, e.g. `Opus 4.8`, `Sonnet 5`, `GPT-5`.
   - `--effort` — your reasoning-effort setting (`low`/`medium`/`high`/`xhigh`/`max`);
     use `?` only if you genuinely can't tell.
   - `--harness` — the tool you run in: `Claude Code`, `Codex`, or `Cursor`.
   Set them once as shell vars so every call is consistent:
   ```bash
   PR=<n>; SIG=(--model "Opus 4.8" --effort "high" --harness "Claude Code")
   ```
3. **Make sure you're on the PR's branch** with a clean tree (fixes land as new commits
   on it). `git status`, `gh pr checkout $PR` if needed.

`scripts/pr-loop.sh` needs `gh` (authenticated) and `jq`.

## The loop

```
repeat (cap at 5 passes):
  items = fetch
  if items.total == 0: done
  pushed = false
  for each item: decide → reply → (if accepted) edit files
  if any accepted: commit + push; pushed = true
  post-pass check:
    if not pushed:                      # only dismissals — nothing will trigger new bot review
        done
    wait ~5 min (bot buffer), then loop # re-fetch; continue only if botCount > 0
```

### Step 1 — fetch

```bash
scripts/pr-loop.sh fetch "$PR"   # add -R owner/repo to target another repo
```

Returns `{ repo, pr, me, botCount, total, items:[...] }`. Each item is a comment **not
authored by you** and **not yet answered** (already-answered ones are detected by the
hidden marker in your prior reply, so re-runs never double-post). Fields: `kind`
(`inline`|`body`|`review`), `id`, `reply_target`, `author`, `isBot`, `body`, `url`, plus
`path`/`line`/`diff_hunk` for inline and `state` for reviews.

- `total == 0` → nothing to do, you're done.
- `botCount` is what drives whether the loop continues after a push (see Step 5).

### Step 2 — decide per comment: dismiss or accept

Read the comment against the actual diff and surrounding code (same rigor as `dane-review`
— cross-reference the codebase, don't just trust the bot). Land in one of three:

- **Accept** — it's right (or right enough and cheap). Fix it in the working tree; you'll
  commit in Step 4. Reply confirming, briefly.
- **Dismiss** — it's wrong, a false positive, out of scope, or a deliberate choice. Reply
  saying why, in Dane's voice — a concrete reason, not a brush-off. Never dismiss a
  plausible **correctness** flag without actually checking it.
- **Escalate** — genuinely ambiguous, risky, or a judgment call that's Dane's to make
  (product behavior, an architectural fork, anything you'd be guessing at). **Do not
  fabricate a decision.** Ask Dane (`AskUserQuestion` / your harness's prompt); if he's
  not around, reply deferring it (`not blocking, will follow up` / @-mention the owner) and
  flag it in your final summary. Bots stating an opinion you'd reasonably push back on →
  dismiss with the pushback; only escalate real forks.

Keep replies as short as the point allows — most are one line. Match the data in the
comment; don't invent hook/util names or rationale you can't verify (the biggest tell).

### Step 3 — reply

**Inline comments** → reply directly in the thread:
```bash
scripts/pr-loop.sh reply "$PR" <reply_target> "${SIG[@]}" -b "your reply"
```

**PR-body comments and review summaries** (`kind` `body`/`review`) have no thread to reply
in, so post a conversation comment that **blockquotes the point and @-tags the author**:
```bash
scripts/pr-loop.sh body "$PR" --reply-to <reply_target> "${SIG[@]}" -b "$(cat <<'EOF'
> the line you're answering, quoted

@author-login <your reply>
EOF
)"
```
Only @-tag when there's a real author to reach (a person, or a bot that reads mentions);
skip the @ if it's meaningless. Inline replies don't need the blockquote/@ — they're
already threaded under the comment.

The script appends `\n\n[Model, Effort, Harness]` and a hidden
`<!-- pr-comment-loop reply-to=<id> -->` marker to every body. **Never post replies by
hand** — bypassing the script drops the marker and the next fetch will re-surface the
comment and double-post.

Optional: after replying, resolve the thread so bots see it's handled —
`gh api graphql` `resolveReviewThread` (needs the thread's node id via the `reviewThreads`
GraphQL query). Skip if it's fiddly; the marker already prevents re-processing on your end.

### Step 4 — commit accepted fixes

Batch the pass's fixes into commits (one focused commit, or a few by theme — match the
repo's convention; use `gt` instead of `git` if Graphite is enabled). Conventional-commit
messages. Then push so the bots re-review:
```bash
git push        # or: gt submit
```

### Step 5 — buffer, then loop

- **No fixes this pass (only dismissals/replies)** → nothing new for bots to react to.
  You're done; go to Wrap-up.
- **You pushed** → wait **~5 minutes** for bots to finish re-reviewing, then re-fetch.
  - Waiting: foreground `sleep` is blocked in Claude Code — run `sleep 300` with
    `run_in_background`, or use `ScheduleWakeup(300)`. In Codex/Cursor a plain `sleep 300`
    is fine. The 5-min window is the assumed bot-posting SLA; lengthen it for slower bots.
  - After the wait, `fetch` again. If `botCount > 0`, run another pass. If bots are quiet
    (only human/no unaddressed comments), stop — you've cleared the automated feedback.

**Safety cap:** stop after 5 passes even if bots keep talking, and report. If a bot keeps
re-raising something you already dismissed (as a *new* comment id each time), don't loop
forever — dismiss once more noting it's a repeat, and surface it to Dane.

## Wrap-up

Report concisely: PR link, passes run, per pass how many accepted vs dismissed, the
commits pushed, and anything escalated/left for Dane.

## Voice cheat-sheet (fallback if `dane-review` isn't loaded)

- lowercase, chat-like, brief; no terminal punctuation on short ones. wrap every
  identifier/path/flag in `backticks`.
- frame pushback as a question or soft suggestion ("could we…", "is this a real case?"),
  hedge ("i think", "imo", "not blocking, but"), but state real bugs/correctness plainly.
- pair a critique with a concrete alternative + the why; never vague, never invented.
- on accept: terse confirm ("good catch, done", "fixed 🙏"). on dismiss: one concrete
  reason. don't pad. praise real catches; retract fast if you misread.
- `nit:` only for genuinely minor style; most notes need no label.
