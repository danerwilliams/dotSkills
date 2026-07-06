#!/usr/bin/env bash
# Drive a review-response loop on a PR: fetch unaddressed comments, post replies that
# carry an AI attribution signature + a hidden tracking marker so the next fetch knows
# what's already handled.
#
# Modes:
#   fetch <pr> [-R owner/repo]
#       Print JSON: { repo, pr, me, botCount, total, items: [...] }.
#       items = review/body/inline comments NOT authored by you and NOT yet replied to
#       (detected via the hidden marker in an existing reply). Each item has an `isBot`
#       flag; loop termination keys off unaddressed *bot* comments.
#
#   reply <pr> <comment_id> -b "text" --model M --effort E --harness H [-R owner/repo]
#       Reply INSIDE an inline review-comment thread (direct threaded reply).
#
#   body  <pr> --reply-to <id> -b "text" --model M --effort E --harness H [-R owner/repo]
#       Post a top-level conversation comment (use for PR-body / review-summary replies;
#       put the `> blockquote` + `@author` mention in -b yourself). --reply-to is the id
#       of the comment you're answering, embedded in the marker for handled-tracking.
#
# Every posted body gets `\n\n[M, E, H]\n<!-- pr-comment-loop reply-to=<id> -->` appended.
# Repo auto-detected from the git remote via gh; override with -R.
set -u

REPO="" BODY="" MODEL="" EFFORT="" HARNESS="" REPLY_TO=""
mode="${1:-}"; shift || true

parse_opts() { while [ $# -gt 0 ]; do case "$1" in
  -b|--body)     BODY="$2"; shift 2;;
  -R|--repo)     REPO="$2"; shift 2;;
  --model)       MODEL="$2"; shift 2;;
  --effort)      EFFORT="$2"; shift 2;;
  --harness)     HARNESS="$2"; shift 2;;
  --reply-to)    REPLY_TO="$2"; shift 2;;
  *) shift;;
esac; done; }

resolve_repo() {
  [ -n "$REPO" ] || REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null)"
  [ -n "$REPO" ] || { echo "could not determine repo; pass -R owner/repo" >&2; exit 2; }
}

# Append attribution signature + hidden tracking marker. $1 = reply-to id.
compose_body() {
  [ -n "$BODY" ] || { echo "empty body; pass -b" >&2; exit 2; }
  [ -n "$MODEL" ] && [ -n "$HARNESS" ] || { echo "missing --model/--harness" >&2; exit 2; }
  printf '%s\n\n[%s, %s, %s]\n<!-- pr-comment-loop reply-to=%s -->' \
    "$BODY" "$MODEL" "${EFFORT:-?}" "$HARNESS" "$1"
}

case "$mode" in
  fetch)
    pr="$1"; shift || true; parse_opts "$@"; resolve_repo
    me="$(gh api user -q .login)"
    inline="$(gh api --paginate "/repos/$REPO/pulls/$pr/comments"   --jq '.[]' 2>/dev/null | jq -s '.')"
    issue="$( gh api --paginate "/repos/$REPO/issues/$pr/comments"  --jq '.[]' 2>/dev/null | jq -s '.')"
    reviews="$(gh api --paginate "/repos/$REPO/pulls/$pr/reviews"   --jq '.[]' 2>/dev/null | jq -s '.')"
    jq -n --argjson inline "${inline:-[]}" --argjson issue "${issue:-[]}" \
          --argjson reviews "${reviews:-[]}" --arg me "$me" --arg repo "$REPO" --arg pr "$pr" '
      def isbot(u): ((u.type // "") == "Bot") or (((u.login // "") | test("\\[bot\\]$")));
      def unhandled($h): (.id) as $id | ($h | index($id) | not);
      ( ($inline + $issue) | map(.body // "") | join("\n") ) as $all
      | ( [ $all | scan("reply-to=([0-9]+)") ] | map(.[0] | tonumber) ) as $handled
      | ( $inline
          | map(select((.in_reply_to_id == null) and (.user.login != $me) and unhandled($handled)))
          | map({kind:"inline", id, reply_target:.id, author:.user.login, isBot:isbot(.user),
                 path, line:(.line // .original_line), diff_hunk, body, url:.html_url}) ) as $I
      | ( $issue
          | map(select((.user.login != $me) and unhandled($handled)))
          | map({kind:"body", id, reply_target:.id, author:.user.login, isBot:isbot(.user),
                 body, url:.html_url}) ) as $B
      | ( $reviews
          | map(select((.state != "APPROVED") and ((.body // "") != "")
                       and (.user.login != $me) and unhandled($handled)))
          | map({kind:"review", id, reply_target:.id, author:.user.login, isBot:isbot(.user),
                 state, body, url:.html_url}) ) as $R
      | ($I + $B + $R) as $items
      | {repo:$repo, pr:($pr|tonumber), me:$me,
         botCount: ([$items[] | select(.isBot)] | length),
         total: ($items | length), items:$items}'
    ;;

  reply)
    pr="$1"; cid="$2"; shift 2 || true; parse_opts "$@"; resolve_repo
    gh api "/repos/$REPO/pulls/$pr/comments/$cid/replies" -X POST \
      -f body="$(compose_body "$cid")" --jq '"posted: " + .html_url'
    ;;

  body)
    pr="$1"; shift || true; parse_opts "$@"; resolve_repo
    [ -n "$REPLY_TO" ] || { echo "body mode needs --reply-to <id>" >&2; exit 2; }
    gh pr comment "$pr" --repo "$REPO" --body "$(compose_body "$REPLY_TO")"
    ;;

  *)
    echo "usage: pr-loop.sh fetch|reply|body ... (see header)" >&2; exit 2;;
esac
