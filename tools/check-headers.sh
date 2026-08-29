#!/bin/sh
# Asserts compression and cache headers on the live site. Nothing else checks
# what the server returns -- `make check` validates the build and stays
# offline-clean, so missing server-side compression and caching can go unnoticed.
# This script closes that gap.

set -eu

status=0

html_url="https://crimsonglow.ca/~kjiwa/2010/09/dos-boot-sector.html"
html_headers=$(curl -sSI -H "Accept-Encoding: gzip, deflate, br, zstd" "$html_url")

if ! echo "$html_headers" | grep -qi '^content-encoding:'; then
  echo "check-headers: $html_url missing content-encoding header" >&2
  status=1
fi

if ! echo "$html_headers" | grep -qi '^cache-control:.*max-age=600'; then
  echo "check-headers: $html_url missing cache-control max-age=600" >&2
  status=1
fi

asset_url="https://crimsonglow.ca/~kjiwa/assets/og-card.png"
asset_headers=$(curl -sSI "$asset_url")

if ! echo "$asset_headers" | grep -qi '^cache-control:.*max-age=2592000'; then
  echo "check-headers: $asset_url missing cache-control max-age=2592000" >&2
  status=1
fi

exit "$status"

