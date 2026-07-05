# dotSkills

My personal [Agent Skills](https://agentskills.io), packaged as a plugin marketplace for
**Claude Code**, **OpenAI Codex**, and **Cursor**.

Each skill lives under `skills/<name>/` in the portable Agent Skills format all three tools
read: a required `SKILL.md` (YAML `name`/`description` + markdown body) plus optional
`references/` (loaded on demand) and `scripts/` (run when invoked).

## Skills

- **[dane-review](skills/dane-review/)** — draft PR review comments in my voice and
  proactively catch the small style/correctness things I tend to flag. Repo-agnostic;
  strongest on TypeScript/React.
- **[herdr-worktree-task](skills/herdr-worktree-task/)** — kick off a coding task in a new
  git worktree as a [herdr](https://herdr.dev) space nested under the current
  conversation's space, then launch an agent (Claude, Codex, or Cursor) in it in
  skip-permissions mode.

## Install

The whole repo is one plugin, `dotskills`, that bundles every skill above.

### Claude Code

```
/plugin marketplace add danerwilliams/dotSkills
/plugin install dotskills@dotskills
```

### Codex

```
codex plugin marketplace add danerwilliams/dotSkills
```

Then open **Plugins** and install **dotskills**.

### Cursor

Settings → Plugins → Add Marketplace → Import from Repo → `danerwilliams/dotSkills`, then
install **dotskills**.

## Notes

- Skills here are sanitized to be portable: no private-repo links, no other people's names.
