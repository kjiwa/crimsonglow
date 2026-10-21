#!/bin/sh
# Maintains the open link-rot issue for the weekly link-check workflow, using gh with
# GH_TOKEN. `open` files or updates it with the output file's contents; `close` closes
# it if one is open.

set -eu

# shellcheck source=common.sh
. "$(dirname "$0")/common.sh"

LABEL=link-rot
readonly LABEL

_open_issue_number() {
  gh issue list --label "$LABEL" --state open --json number --jq '.[0].number // empty'
}

_open() {
  _open_output="$1"
  _open_run_url="$2"
  _open_body="Weekly link check found broken external links as of $(date -u +%Y-%m-%d).

\`\`\`
$(cat "$_open_output")
\`\`\`

Run: $_open_run_url"

  gh label create "$LABEL" --color d73a4a --force \
    --description "External link rot found by the weekly link-check workflow"

  _open_existing=$(_open_issue_number)
  if [ -n "$_open_existing" ]; then
    gh issue comment "$_open_existing" --body "$_open_body"
  else
    gh issue create --title "Link check: broken external links" \
      --label "$LABEL" --body "$_open_body"
  fi
}

_close() {
  _close_existing=$(_open_issue_number)
  if [ -n "$_close_existing" ]; then
    gh issue comment "$_close_existing" \
      --body "Link check passed on $(date -u +%Y-%m-%d) -- closing."
    gh issue close "$_close_existing"
  fi
}

main() {
  case "${1:-}" in
    open)
      [ "$#" -eq 3 ] || die "usage: open <output-file> <run-url>"
      _open "$2" "$3"
      ;;
    close)
      _close
      ;;
    *)
      die "usage: $(basename "$0") open <output-file> <run-url> | close"
      ;;
  esac
}

main "$@"
