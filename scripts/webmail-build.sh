#!/bin/sh
# Builds webmail/dist/alps.zip: the pinned Alps tree, restyled with the site's
# tokens and patched for API Gateway's path decoding, compiled for Lambda (linux/arm64)
# beside webmail/run.sh. Needs the built site (make build), go, node, git and zip.

set -eu

# shellcheck source=common.sh
. "$(dirname "$0")/common.sh"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
readonly ROOT
ALPS_URL="https://github.com/migadu/alps"
readonly ALPS_URL

_checkout_alps() {
  _checkout_alps_dir="$1"
  git -C "$_checkout_alps_dir" init -q
  git -C "$_checkout_alps_dir" fetch -q --depth 1 "$ALPS_URL" "$(cat "$ROOT/webmail/alps.ref")"
  git -C "$_checkout_alps_dir" checkout -q FETCH_HEAD
}

_site_title() {
  ruby -ryaml -e 'puts YAML.load_file(ARGV[0]).fetch("title")' "$ROOT/site/_config.yml"
}

_build_frontend() {
  (cd "$1/frontend" && npm ci --silent && npm run build --silent)
}

_build_binary() {
  (cd "$1" && CGO_ENABLED=0 GOOS=linux GOARCH=arm64 \
    go build -trimpath -ldflags "-s -w" -o "$2" ./cmd/alps)
}

main() {
  for _main_cmd in git go node npm ruby zip; do
    command -v "$_main_cmd" >/dev/null 2>&1 || die "$_main_cmd is required"
  done

  _main_tokens="$ROOT/site/_site/~kjiwa/assets/site-tokens.css"
  [ -f "$_main_tokens" ] || die "build the site first: make build"

  _main_work="$(mktemp -d "${TMPDIR:-/tmp}/webmail.XXXXXX")"
  trap 'rm -rf "$_main_work"' EXIT
  _main_alps="$_main_work/alps"
  _main_stage="$_main_work/stage"
  mkdir -p "$_main_alps" "$_main_stage"

  _checkout_alps "$_main_alps"
  node "$ROOT/webmail/theme.mjs" "$_main_alps" "$_main_tokens" \
    "$ROOT/site/~kjiwa/assets/favicon.svg" "Mail · $(_site_title)"
  node "$ROOT/webmail/paths.mjs" "$_main_alps"
  _build_frontend "$_main_alps"
  _build_binary "$_main_alps" "$_main_stage/alps"
  cp "$ROOT/webmail/run.sh" "$_main_stage/run.sh"

  mkdir -p "$ROOT/webmail/dist"
  rm -f "$ROOT/webmail/dist/alps.zip"
  (cd "$_main_stage" && zip -q -X "$ROOT/webmail/dist/alps.zip" alps run.sh)
}

main "$@"
