#!/usr/bin/env bash
# Symlink skills from this repo into Claude Code and Codex.
# Usage: ./install.sh [skill-name ...]   (no args = link all skills in this repo)
set -eu

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude/skills"
CODEX_DIR="${CODEX_HOME:-$HOME/.codex}/skills"
mkdir -p "$CLAUDE_DIR" "$CODEX_DIR"

link_one() {
  s="$1"; src="$ROOT/$s"
  [ -f "$src/SKILL.md" ] || { echo "skip $s (no SKILL.md)"; return; }
  for dest in "$CLAUDE_DIR/$s" "$CODEX_DIR/$s"; do
    if [ -L "$dest" ] || { [ -e "$dest" ] && [ ! -d "$dest" ]; }; then rm -f "$dest"; fi
    if [ -d "$dest" ] && [ ! -L "$dest" ]; then echo "WARN: $dest is a real dir, skipping"; continue; fi
    ln -s "$src" "$dest" && echo "linked $dest -> $src"
  done
}

if [ "$#" -gt 0 ]; then
  for s in "$@"; do link_one "$s"; done
else
  for d in "$ROOT"/*/; do
    s="$(basename "$d")"
    [ -f "$d/SKILL.md" ] && link_one "$s"
  done
fi
echo "done — restart Codex to pick up newly linked skills."
