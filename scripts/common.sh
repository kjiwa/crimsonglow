#!/bin/sh
# Shared helpers, sourced by the other scripts. Not executable on its own.

# shellcheck disable=SC2034  # used by the sourcing scripts
SITE_ORIGIN="https://crimsonglow.ca"
readonly SITE_ORIGIN

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

# $2 overrides Accept-Encoding. ICDSoft's HTTP/2 resets a HEAD for feed.xml that
# offers gzip alongside other encodings, so the feed is fetched uncompressed.
fetch_headers() {
  curl_site -I -H "Accept-Encoding: ${2:-gzip, deflate, br, zstd}" \
    -w '\nhttp_status: %{http_code}\n' "$1"
}

fetch_body() {
  curl_site "$1"
}
