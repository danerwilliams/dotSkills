---
name: herdr-worktree-task
description: Kick off a coding task in a new git worktree as a herdr space nested UNDER the current conversation's space, then launch a coding agent (Claude, Codex, or Cursor) in it in skip-permissions mode. Use when the user, mid-conversation, asks to spin off / kick off / hand off a change, fix, or task into its own worktree + agent from the current herdr session (e.g. "kick this off in a new worktree", "have an agent build this", "spin up a worktree for X").
allowed-tools: Bash, Read, Write, AskUserQuestion
---

# herdr-worktree-task

Spin off the change you're discussing into its own git worktree that shows up in
[herdr](https://herdr.dev) **nested under the space you're currently in**, and start a
coding agent working on it there — provider-agnostic (Claude Code, Codex, or Cursor),
always in that provider's skip-permissions mode.

## Why this skill exists (the one non-obvious thing)

herdr groups worktrees in the sidebar by their `source_workspace_id`, and **that field
follows the `--workspace` flag** you pass to `herdr worktree create`. If you instead
create with `--cwd <repo root>`, the source resolves to whichever workspace is bound to
the repo's *main* checkout (usually the first one opened on that repo), so every worktree
piles under that node regardless of which conversation spawned it.

**Rule: create with `--workspace <current workspace id>`, never `--cwd`.**

## Prerequisites

You must be running inside a herdr pane:

```bash
[ -n "$HERDR_ENV" ] && [ -n "$HERDR_PANE_ID" ] && command -v herdr >/dev/null \
  && echo "in herdr: pane=$HERDR_PANE_ID" || echo "NOT in a herdr pane"
```

If this isn't a herdr pane, stop and tell the user — this skill can only nest a worktree
under the current space when it runs inside that space.

## Step 0 — ask the user what to launch (do this BEFORE creating anything)

Confirm these with the user (use `AskUserQuestion` if available; otherwise ask in text).
Don't guess — model and effort materially change cost and quality:

1. **Agent provider** — if not already stated: Claude Code, Codex, or Cursor. Only offer
   providers whose CLI is installed (`command -v claude codex cursor-agent`).
2. **Model** — the specific model to run the task with.
3. **Reasoning effort** — e.g. low / medium / high (and `max`/`xhigh` where the provider
   supports it). Match to task difficulty.

Skip-permissions mode is **always on** — don't ask about it. Map the answers to the
provider's flags using the table in the "Launch" step.

## Step 1 — resolve the current conversation's workspace id

```bash
WS=$(herdr pane get "$HERDR_PANE_ID" \
  | python3 -c "import sys,json;print(json.load(sys.stdin)['result']['pane']['workspace_id'])")
echo "current workspace: $WS"
```

## Step 2 — decide branch, base, label

- **Branch**: a conventional name, e.g. `fix/public-api-timeouts`.
- **Base**: the repo's integration branch. Confirm it — some repos use `dev`, most use
  `main`. If unsure: `git -C <repo> symbolic-ref --short refs/remotes/origin/HEAD`.
- **Label**: the task, so parallel worktrees are distinguishable, e.g. `"API: timeouts"`.

## Step 3 — create the worktree, anchored under the current space

```bash
herdr worktree create --workspace "$WS" \
  --branch fix/your-branch --base dev \
  --label "Short task label" --no-focus --json
```

Capture from the JSON `result`: `workspace.workspace_id` (→ `NEW_WS`), `worktree.path`
(→ `WT`, the checkout dir), and `root_pane.pane_id` (the default shell pane).

## Step 4 — assemble the context for the spawned agent (do NOT skip this)

**The agent you launch starts with a blank context. It cannot see this conversation.**
Everything it needs must be in the task spec. Write a self-contained spec to a file
**outside the worktree** (so it isn't committed) and have the agent read it. A good spec has:

- **Goal** — one or two sentences on what to build/fix and why.
- **Concrete pointers** — the exact files, symbols, and `file:line` anchors you already
  found in this conversation. This is the highest-value part: it saves the fresh agent from
  re-discovering what you already know. Include relevant function/service names.
- **Constraints** — style/convention rules, what NOT to touch, backward-compat concerns,
  any contract/interface boundaries.
- **Acceptance criteria** — what "done" looks like, concretely.
- **Quality gates** — the exact scoped commands to run (tsc/lint/format/tests) and that
  they must pass; note any that need infra the sandbox may lack.
- **Skills/docs** — point to relevant repo `AGENTS.md`/`CLAUDE.md` and any skills to load.
- **Deliverable** — state explicitly: **commit locally only**, or **push + open a PR**
  (and against which base, following the repo's PR template). If you don't say, the agent
  may only commit locally.
- **Autonomy** — tell it not to ask questions; make reasonable decisions and finish.

Keep it tight and factual. The spec is the contract; the agent's output quality is capped
by how good this context is.

## Step 5 — pre-empt provider-specific startup blockers (autonomous runs)

A skip-permissions flag governs *tool* approvals; it does **not** dismiss first-run
**trust/onboarding** prompts, which will hang an unattended session. Handle per provider:

- **Claude Code** — the folder-trust dialog and (for repos whose `CLAUDE.md` uses `@file`
  includes, e.g. an `@AGENTS.md` include) the external-includes approval. Pre-seed both
  in `~/.claude.json` for the worktree path before launch:

  ```bash
  WT="<worktree path from step 3>"
  python3 - "$WT" <<'PY'
  import json, os, sys
  p = os.path.expanduser('~/.claude.json'); wt = sys.argv[1]
  d = json.load(open(p)); projects = d.setdefault('projects', {})
  base = next((v for k, v in projects.items() if wt.startswith(k) or k.endswith('/'+wt.split('/')[-1])), {})
  e = dict(base); e.update({
    'hasTrustDialogAccepted': True,
    'projectOnboardingSeenCount': max(1, base.get('projectOnboardingSeenCount', 0) or 1),
    'hasClaudeMdExternalIncludesApproved': True,
    'hasClaudeMdExternalIncludesWarningShown': True,
  })
  projects[wt] = e
  tmp = p + '.tmp'; json.dump(d, open(tmp, 'w'), indent=2); os.replace(tmp, p)
  print('seeded trust for', wt)
  PY
  ```

- **Codex / Cursor** — may show their own first-run trust prompt in a new directory. There's
  no reliable pre-seed, so rely on the post-launch check in Step 7: read the pane, and if a
  trust/confirm prompt is showing, answer it with `herdr pane send-keys` before sending the
  task.

Also make sure herdr can track the agent's status: `herdr integration install <provider>`
(`claude` | `codex` | `cursor`) — a no-op if already installed.

## Step 6 — launch the agent in skip-permissions mode

Map the Step 0 answers to the provider's flags. **Aliases don't expand** here (herdr execs
argv directly), so always pass the real binary + flags:

| Provider | CLI | Skip-permissions (always) | Model | Reasoning effort |
|---|---|---|---|---|
| Claude Code | `claude` | `--dangerously-skip-permissions` | `--model <opus\|sonnet\|haiku\|fable\|id>` | send `/effort <level>` as the first input (Step 7) |
| Codex | `codex` | `--yolo` (bypass approvals + sandbox) | `-m <id>` | `-c model_reasoning_effort="<low\|medium\|high>"` |
| Cursor | `cursor-agent` | `--force` | `-m <id>` | (model-dependent; set via `-m`) |

Flags can vary by version — if one is rejected, check `<cli> --help` and adjust; the
invariant is **the provider's full skip-approvals mode**, never a mode that pauses for input.

```bash
# Example — Claude:
herdr agent start <name> --cwd "$WT" --workspace "$NEW_WS" --no-focus \
  -- claude --dangerously-skip-permissions --model <model>
# Example — Codex:
herdr agent start <name> --cwd "$WT" --workspace "$NEW_WS" --no-focus \
  -- codex --yolo -m <model> -c model_reasoning_effort="<effort>"
# Example — Cursor:
herdr agent start <name> --cwd "$WT" --workspace "$NEW_WS" --no-focus \
  -- cursor-agent --force -m <model>
```

Note: `herdr agent start` opens a **new** pane beside the worktree's root shell (so the
space shows 2 panes). To reuse the root pane instead: `herdr pane run <root_pane_id> "<cmd>"`.

## Step 7 — hand the agent its task

`herdr agent send` types text but does **not** submit — submit with a separate Enter.

```bash
herdr agent wait <name> --status idle --timeout 60000
herdr pane read <agent-pane-id> --source visible --lines 20   # confirm prompt, no dialog
# Claude only, if a specific effort was requested:
herdr agent send <name> "/effort <level>"; herdr pane send-keys <agent-pane-id> Enter
# Then the task:
herdr agent send <name> "Read and fully execute the task spec at <spec file path>. You're in a dedicated worktree on branch <branch> — work only here; <commit locally | push + open a PR against <base>>. Don't ask questions."
herdr pane send-keys <agent-pane-id> Enter
```

Verify: `herdr agent get <name>` should report `agent_status: working`.

## Step 8 — report back

Tell the user: the new space label + branch + worktree path, the provider/model/effort used,
and how to watch it — `herdr agent attach <name>` (or focus the new workspace). Two caveats:

- The spawned agent runs as its own herdr session, so **this** session gets no completion
  notification. If a PR was requested, offer to poll for it and report the URL.
- An existing worktree can't be re-parented in place; if it nested wrong, recreate it with
  `--workspace` once its agent is idle.

## Gotchas recap

- **`--workspace`, not `--cwd`** — the whole point; `--cwd` re-anchors to the repo's main checkout.
- **Ask model + effort first** (Step 0) — they change cost and quality; don't assume.
- **Context is the contract** (Step 4) — the fresh agent can't see this conversation; hand it every anchor.
- **Skip-permissions ≠ trust** — pre-empt each provider's first-run/trust prompt (Step 5).
- **Aliases don't expand** in `agent start -- <argv>`; pass the real binary + flags.
- **`agent send` doesn't submit** — follow with `herdr pane send-keys <pane> Enter`.
- **State the deliverable** (commit-local vs PR) in the spec, or the agent may only commit locally.
