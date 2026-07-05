---
name: herdr-worktree-task
description: Kick off a coding task in a new git worktree as its own herdr space, then launch a coding agent (Claude, Codex, or Cursor) in a single pane in skip-permissions mode. Use when the user, mid-conversation, asks to spin off / kick off / hand off a change, fix, or task into its own worktree + agent from the current herdr session (e.g. "kick this off in a new worktree", "have an agent build this", "spin up a worktree for X").
allowed-tools: Bash, Read, Write, AskUserQuestion
---

# herdr-worktree-task

Spin off the change you're discussing into its own git worktree in [herdr](https://herdr.dev)
and start a coding agent working on it there — provider-agnostic (Claude Code, Codex, or
Cursor), always in that provider's skip-permissions mode, in a single pane.

## How herdr groups worktrees (know this so you set expectations correctly)

herdr **always anchors a new worktree to its repo's *parent* workspace** — it literally says
"new and open worktree actions start from the repo parent workspace." So every worktree you
create shows up grouped under that repo's node in the sidebar, **regardless of which workspace
you launch it from**. There is no option to nest a worktree under an arbitrary/other workspace,
and `--workspace` on `worktree create` only selects *which repo* (via that workspace's cwd) —
it does **not** re-parent the result.

Consequence: if you want new worktrees to appear under the space you actually work in, make
that space the repo's parent workspace (i.e. work out of the primary checkout's workspace),
rather than a second workspace opened on the same checkout.

## Prerequisites

You must be running inside a herdr pane:

```bash
[ -n "$HERDR_ENV" ] && [ -n "$HERDR_PANE_ID" ] && command -v herdr >/dev/null \
  && echo "in herdr: pane=$HERDR_PANE_ID" || echo "NOT in a herdr pane"
```

If this isn't a herdr pane, stop and tell the user.

## Step 0 — ask the user what to launch (BEFORE creating anything)

Confirm these (use `AskUserQuestion` if available). Don't guess — model and effort change cost
and quality:

1. **Agent provider** — Claude Code, Codex, or Cursor. Only offer providers whose CLI is
   installed (`command -v claude codex cursor-agent`).
2. **Model** — the specific model to run the task with.
3. **Reasoning effort** — low / medium / high (and `max`/`xhigh` where supported).

Skip-permissions mode is **always on** — don't ask about it.

## Step 1 — create the worktree

```bash
herdr worktree create --cwd <repo-root> \
  --branch fix/your-branch --base <base> \
  --label "Short task label" --no-focus --json
```

- **Base**: the repo's integration branch. Confirm it — some repos use `dev`, most use `main`
  (`git -C <repo> symbolic-ref --short refs/remotes/origin/HEAD`).
- **Label**: the task, so parallel worktrees are distinguishable.
- Capture from the JSON `result`: `worktree.path` (→ `WT`, the checkout dir) and
  **`root_pane.pane_id`** (→ `ROOT_PANE`, the shell pane herdr just opened — you'll run the
  agent *in this pane*, see Step 4).

## Step 2 — assemble the context for the spawned agent (do NOT skip)

**The agent you launch starts with a blank context. It cannot see this conversation.** Write a
self-contained task spec to a file **outside the worktree** (so it isn't committed) and have the
agent read it. A good spec has:

- **Goal** — one or two sentences.
- **Concrete pointers** — the exact files, symbols, and `file:line` anchors you already found in
  this conversation. Highest-value part: it saves the fresh agent from re-discovering what you
  already know.
- **Constraints** — conventions, what NOT to touch, back-compat/interface boundaries.
- **Acceptance criteria** and **quality gates** (the exact scoped commands to run; note any that
  need infra the sandbox may lack).
- **Skills/docs** — relevant repo `AGENTS.md`/`CLAUDE.md` and skills to load.
- **Deliverable** — state explicitly: **commit locally only**, or **push + open a PR** (and
  against which base). If you don't say, the agent may only commit locally.
- **Autonomy** — tell it not to ask questions; make reasonable decisions and finish.

## Step 3 — pre-empt provider-specific startup blockers (autonomous runs)

A skip-permissions flag governs *tool* approvals; it does **not** dismiss first-run
**trust/onboarding** prompts, which hang an unattended session.

- **Claude Code** — the folder-trust dialog and (for repos whose `CLAUDE.md` uses `@file`
  includes, e.g. an `@AGENTS.md` include) the external-includes approval. Pre-seed both in
  `~/.claude.json` for the worktree path before launch:

  ```bash
  WT="<worktree path from step 1>"
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

- **Codex / Cursor** — may show their own first-run prompt; rely on the post-launch pane check
  in Step 5 and clear it with `herdr pane send-keys` if needed.

Also make sure herdr can track the agent's status: `herdr integration install <provider>`
(`claude` | `codex` | `cursor`) — a no-op if already installed.

## Step 4 — launch the agent IN the worktree's root pane (single pane)

Run the agent *inside* the pane herdr already opened (`ROOT_PANE`), NOT via `herdr agent start`
— `agent start` spawns a *second* pane, leaving the workspace with two. Use `pane run`, which
types the command + Enter into the existing pane:

```bash
# Claude:
herdr pane run <ROOT_PANE> "claude --model <model> --dangerously-skip-permissions"
# Codex:
herdr pane run <ROOT_PANE> "codex --yolo -m <model> -c model_reasoning_effort=\"<effort>\""
# Cursor:
herdr pane run <ROOT_PANE> "cursor-agent --force -m <model>"
```

Map the Step 0 answers to the provider's flags. **Aliases don't expand** — pass the real binary
+ flags. Flags vary by version; if one is rejected, check `<cli> --help` — the invariant is the
provider's full skip-approvals mode, never a mode that pauses for input.

| Provider | CLI | Skip-permissions (always) | Model | Reasoning effort |
|---|---|---|---|---|
| Claude Code | `claude` | `--dangerously-skip-permissions` | `--model <opus\|sonnet\|haiku\|fable\|id>` | send `/effort <level>` as first input (Step 5) |
| Codex | `codex` | `--yolo` | `-m <id>` | `-c model_reasoning_effort="<low\|medium\|high>"` |
| Cursor | `cursor-agent` | `--force` | `-m <id>` | (model-dependent) |

From here on, **target the agent by its pane id** (`ROOT_PANE`) — with `pane run` you didn't give
it an `agent start` name.

## Step 5 — hand the agent its task

`herdr agent send` types text but does **not** submit — submit with a separate Enter. Targets
accept pane ids.

```bash
herdr agent wait <ROOT_PANE> --status idle --timeout 60000
herdr pane read <ROOT_PANE> --source visible --lines 20     # confirm prompt, no dialog
# Claude only, if a specific effort was requested:
herdr agent send <ROOT_PANE> "/effort <level>"; herdr pane send-keys <ROOT_PANE> Enter
# Then the task:
herdr agent send <ROOT_PANE> "Read and fully execute the task spec at <spec file path>. You're in a dedicated worktree on branch <branch> — work only here; <commit locally | push + open a PR against <base>>. Don't ask questions."
herdr pane send-keys <ROOT_PANE> Enter
```

Verify: `herdr agent get <ROOT_PANE>` should report `agent_status: working`. Note the pane id can
change if the worktree's shell exits and herdr renumbers — re-resolve with
`herdr pane list --workspace <new-workspace-id>` if a send fails with `pane_not_found`.

## Step 6 — report back

Tell the user: the new space label + branch + worktree path, the provider/model/effort used, and
how to watch it — `herdr agent attach <ROOT_PANE>` (or focus the new workspace, which will be
grouped under the repo's node). The spawned agent runs as its own herdr session, so **this**
session gets no completion notification — if a PR was requested, offer to poll for it.

## Gotchas recap

- **Worktrees group under the repo's parent workspace** — herdr rule; you can't nest one under an arbitrary workspace, and `--workspace`/`--cwd` only pick the repo.
- **Launch in the root pane** (`pane run <ROOT_PANE>`), not `agent start`, or you get two panes.
- **Ask model + effort first** (Step 0) — they change cost and quality.
- **Context is the contract** (Step 2) — the fresh agent can't see this conversation; hand it every anchor.
- **Skip-permissions ≠ trust** — pre-empt each provider's first-run/trust prompt (Step 3).
- **Aliases don't expand**; pass the real binary + flags.
- **`agent send` doesn't submit** — follow with `herdr pane send-keys <pane> Enter`.
- **State the deliverable** (commit-local vs PR) in the spec, or the agent may only commit locally.
