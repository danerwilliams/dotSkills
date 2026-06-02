#!/usr/bin/env bash
# Post a PR review comment in Dane's voice, AFTER Dane has approved the drafted text.
# Modes:
#   inline <pr> <path> <line> [-b "body"] [-R owner/repo]   inline code-line comment (RIGHT side)
#   body   <pr>               [-b "body"] [-R owner/repo]   top-level conversation comment
#   reply  <pr> <comment_id>  [-b "body"] [-R owner/repo]   reply within an existing inline thread
# Repo: auto-detected from the current git remote via `gh`; override with -R owner/repo.
# Body: pass with -b "..."  OR pipe via stdin. Always preview before running.
set -u
REPO=""

mode="${1:-}"; shift || true
read_body() { if [ -n "${BODY:-}" ]; then printf '%s' "$BODY"; else cat; fi; }
BODY=""
parse_opts() { while [ $# -gt 0 ]; do case "$1" in
  -b) BODY="$2"; shift 2;;
  -R|--repo) REPO="$2"; shift 2;;
  *) shift;;
esac; done; }
resolve_repo() {
  [ -n "$REPO" ] || REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null)"
  [ -n "$REPO" ] || { echo "could not determine repo; pass -R owner/repo" >&2; exit 2; }
}

case "$mode" in
  inline)
    pr="$1"; path="$2"; line="$3"; shift 3; parse_opts "$@"; resolve_repo
    body="$(read_body)"
    sha="$(gh api "/repos/$REPO/pulls/$pr" --jq '.head.sha')"
    gh api "/repos/$REPO/pulls/$pr/comments" -X POST \
      -f body="$body" -f commit_id="$sha" -f path="$path" -F line="$line" -f side=RIGHT \
      --jq '"posted: " + .html_url'
    ;;
  body)
    pr="$1"; shift; parse_opts "$@"; resolve_repo
    body="$(read_body)"
    gh pr comment "$pr" --repo "$REPO" --body "$body"
    ;;
  reply)
    pr="$1"; cid="$2"; shift 2; parse_opts "$@"; resolve_repo
    body="$(read_body)"
    gh api "/repos/$REPO/pulls/$pr/comments/$cid/replies" -X POST \
      -f body="$body" --jq '"posted: " + .html_url'
    ;;
  *)
    echo "usage: post-comment.sh inline|body|reply ... (see header)" >&2; exit 2;;
esac
