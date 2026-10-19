#!/bin/sh
# Shared helpers, sourced by the other scripts. Not executable on its own.

# shellcheck disable=SC2034  # used by the sourcing scripts
SITE_ORIGIN="${SITE_ORIGIN:-https://crimsonglow.ca}"
readonly SITE_ORIGIN

TFVARS="$(dirname "$0")/../terraform/terraform.tfvars"
readonly TFVARS

die() {
  echo "$(basename "$0"): $*" >&2
  exit 1
}

# Prints "<from> <to>" per line from site/_data/redirects.yml.
redirect_pairs() {
  ruby -ryaml -e 'YAML.load_file(ARGV[0]).each { |from, to| puts "#{from} #{to}" }' \
    "$(dirname "$0")/../site/_data/redirects.yml"
}

# CHECK_CONNECT_TO=<host> sends every request to that host while keeping the
# URL's own Host header and TLS name, for probing a new origin before DNS moves.
curl_site() {
  if [ -n "${CHECK_CONNECT_TO:-}" ]; then
    curl -sS --connect-to "::$CHECK_CONNECT_TO:" "$@"
  else
    curl -sS "$@"
  fi
}

# GET with the body discarded, not HEAD: CloudFront omits content-encoding on HEAD.
fetch_headers() {
  curl_site -o /dev/null -D - -H "Accept-Encoding: gzip, deflate, br, zstd" \
    -w '\nhttp_status: %{http_code}\n' "$1"
}

fetch_body() {
  curl_site "$1"
}

account_id() {
  sed -n 's/^account_id *= *"\([0-9]*\)".*/\1/p' "$TFVARS"
}

ensure_login() {
  if ! aws sts get-caller-identity >/dev/null 2>&1; then
    aws sso login
  fi
}
