#!/usr/bin/env bash
# Extract Dane's review comments on OTHER people's PRs in a given repo.
# Captures three comment types (inline review, review summary, conversation),
# excludes Dane-authored PRs, and writes one JSON object per line.
# Usage: fetch-comments.sh <owner/repo> [out_dir]
# Re-runnable: refreshes a corpus that can be used to re-derive the dane-review skill.
set -u

REPO="${1:?usage: fetch-comments.sh <owner/repo> [out_dir]}"
ME="${REVIEW_AUTHOR:-danerwilliams}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="${2:-$HERE/../corpus}"
mkdir -p "$OUT_DIR"
CORPUS="$OUT_DIR/comments.jsonl"
PRS_FILE="$OUT_DIR/prs.json"
: > "$CORPUS"

command -v gh >/dev/null || { echo "gh not found" >&2; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "gh not authenticated" >&2; exit 1; }

echo "[1/4] Collecting PR list (commented-on UNION reviewed, excluding your own)..." >&2
{
  gh api --paginate "/search/issues?q=repo:$REPO+type:pr+commenter:$ME+-author:$ME&per_page=100" \
    --jq '.items[] | {number, title, author: .user.login}'
  gh api --paginate "/search/issues?q=repo:$REPO+type:pr+reviewed-by:$ME+-author:$ME&per_page=100" \
    --jq '.items[] | {number, title, author: .user.login}'
} | jq -s 'unique_by(.number)' > "$PRS_FILE"

N=$(jq 'length' "$PRS_FILE")
echo "      $N unique PRs" >&2

echo "[2/4] Fetching comments per PR..." >&2
i=0
jq -c '.[]' "$PRS_FILE" | while read -r pr_json; do
  i=$((i+1))
  pr=$(jq -r '.number' <<<"$pr_json")
  title=$(jq -r '.title' <<<"$pr_json")
  author=$(jq -r '.author' <<<"$pr_json")
  printf '\r      %d/%d (PR #%s)            ' "$i" "$N" "$pr" >&2

  # (a) inline review comments (code-line comments)
  gh api --paginate "/repos/$REPO/pulls/$pr/comments?per_page=100" \
    --jq ".[] | select(.user.login==\"$ME\") | {pr:$pr, type:\"inline\", path:.path, diff_hunk:.diff_hunk, in_reply_to:(.in_reply_to_id//null), body:.body, url:.html_url, created_at:.created_at}" 2>/dev/null \
    | jq -c --arg t "$title" --arg a "$author" '. + {pr_title:$t, pr_author:$a}' >> "$CORPUS"

  # (b) review summary bodies (the text of an Approve / Request-changes / Comment review)
  gh api --paginate "/repos/$REPO/pulls/$pr/reviews?per_page=100" \
    --jq ".[] | select(.user.login==\"$ME\") | select((.body//\"\")!=\"\") | {pr:$pr, type:\"review\", state:.state, body:.body, url:.html_url, created_at:.submitted_at}" 2>/dev/null \
    | jq -c --arg t "$title" --arg a "$author" '. + {pr_title:$t, pr_author:$a}' >> "$CORPUS"

  # (c) conversation comments (top-level PR timeline)
  gh api --paginate "/repos/$REPO/issues/$pr/comments?per_page=100" \
    --jq ".[] | select(.user.login==\"$ME\") | {pr:$pr, type:\"conversation\", body:.body, url:.html_url, created_at:.created_at}" 2>/dev/null \
    | jq -c --arg t "$title" --arg a "$author" '. + {pr_title:$t, pr_author:$a}' >> "$CORPUS"
done
echo "" >&2

echo "[3/4] Tagging language by file extension..." >&2
jq -c -f "$HERE/addlang.jq" "$CORPUS" > "$CORPUS.tmp" && mv "$CORPUS.tmp" "$CORPUS"

echo "[4/4] Summary:" >&2
echo "  total comments: $(wc -l < "$CORPUS" | tr -d ' ')" >&2
echo "  by type:" >&2
jq -r '.type' "$CORPUS" | sort | uniq -c | sed 's/^/    /' >&2
echo "  inline by lang:" >&2
jq -r 'select(.type=="inline") | .lang' "$CORPUS" | sort | uniq -c | sort -rn | sed 's/^/    /' >&2
echo "DONE. Corpus: $CORPUS" >&2
