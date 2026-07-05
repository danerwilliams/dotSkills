# dotSkills

My personal [Agent Skills](https://agentskills.io) — the source of truth, symlinked
into both **Claude Code** (`~/.claude/skills/`) and **OpenAI Codex** (`~/.codex/skills/`).

Each top-level folder is one skill in the portable Agent Skills format both tools read:
a required `SKILL.md` (YAML `name`/`description` + markdown body) plus optional
`references/` (loaded on demand) and `scripts/` (run when invoked).

## Skills

- **[dane-review](dane-review/)** — draft PR review comments in my voice and proactively
  catch the small style/correctness things I tend to flag. Repo-agnostic; strongest on
  TypeScript/React.
- **[herdr-worktree-task](herdr-worktree-task/)** — kick off a coding task in a new git
  worktree as a [herdr](https://herdr.dev) space nested under the current conversation's
  space, then launch an agent (Claude, Codex, or Cursor) in it in skip-permissions mode.

## Install

### Claude Code marketplace

This repo is also a Claude Code plugin marketplace. Add it once, then install the bundle:

```bash
/plugin marketplace add danerwilliams/dotSkills
/plugin install dotskills@dotskills
```

The `dotskills` plugin bundles every skill here (surfaced via the `skills` paths in
`.claude-plugin/marketplace.json` — the top-level folders stay put, nothing is moved).

### Symlink (Claude Code + Codex)

From the repo root, symlink skills into both tools:

```bash
./install.sh              # link every skill here into ~/.claude/skills and ~/.codex/skills
./install.sh dane-review  # just one
```

Claude Code picks up changes in-session; **restart Codex** to pick up newly linked skills.

## Notes

- Skills here are sanitized to be portable: no private-repo links, no other people's names.
- A skill's `corpus/` holds the sanitized evidence it was distilled from — verbatim snippets
  and code context only, with links removed and people anonymized. Raw/un-sanitized build
  data is git-ignored.
