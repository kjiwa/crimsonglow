#!/bin/sh
# Asserts compression, cache, and security headers on the live site. Nothing
# else checks what the server returns -- `make check` validates the build and
# stays offline-clean, so missing server-side compression, caching, or security
# headers can go unnoticed. This script closes that gap.

set -eu

assert_header() {
  _assert_header_url="$1"
  _assert_header_headers="$2"
  _assert_header_pattern="$3"
  _assert_header_label="$4"

  if ! printf '%s\n' "$_assert_header_headers" | grep -qi "$_assert_header_pattern"; then
    echo "check-headers: $_assert_header_url missing $_assert_header_label" >&2
    return 1
  fi
  return 0
}

fetch_headers() {
  curl -sSI -H "Accept-Encoding: gzip, deflate, br, zstd" \
    -w '\nhttp_status: %{http_code}\n' "$1"
}

main() {
  _main_status=0

  _main_html_url="https://crimsonglow.ca/~kjiwa/2010/09/dos-boot-sector.html"
  _main_html_headers=$(fetch_headers "$_main_html_url")

  assert_header "$_main_html_url" "$_main_html_headers" '^http_status: 200' "HTTP 200" || _main_status=1
  assert_header "$_main_html_url" "$_main_html_headers" '^content-encoding:' "content-encoding header" || _main_status=1
  assert_header "$_main_html_url" "$_main_html_headers" '^cache-control:.*max-age=600' "cache-control max-age=600" || _main_status=1
  assert_header "$_main_html_url" "$_main_html_headers" '^strict-transport-security:.*max-age=15768000[^0-9]' "strict-transport-security" || _main_status=1
  assert_header "$_main_html_url" "$_main_html_headers" '^permissions-policy:.*geolocation=\(\)' "permissions-policy" || _main_status=1
  assert_header "$_main_html_url" "$_main_html_headers" '^x-content-type-options:.*nosniff' "x-content-type-options nosniff" || _main_status=1
  assert_header "$_main_html_url" "$_main_html_headers" '^referrer-policy:.*strict-origin-when-cross-origin' "referrer-policy strict-origin-when-cross-origin" || _main_status=1
  assert_header "$_main_html_url" "$_main_html_headers" '^x-frame-options:.*sameorigin' "x-frame-options sameorigin" || _main_status=1
  assert_header "$_main_html_url" "$_main_html_headers" '^content-security-policy:.*default-src .self.' "content-security-policy" || _main_status=1

  _main_feed_url="https://crimsonglow.ca/~kjiwa/feed.xml"
  _main_feed_headers=$(fetch_headers "$_main_feed_url")
  assert_header "$_main_feed_url" "$_main_feed_headers" '^http_status: 200' "HTTP 200" || _main_status=1
  assert_header "$_main_feed_url" "$_main_feed_headers" '^cache-control:.*max-age=600' "cache-control max-age=600" || _main_status=1

  _main_asset_url="https://crimsonglow.ca/~kjiwa/assets/og-card.png"
  _main_asset_headers=$(fetch_headers "$_main_asset_url")
  assert_header "$_main_asset_url" "$_main_asset_headers" '^http_status: 200' "HTTP 200" || _main_status=1
  assert_header "$_main_asset_url" "$_main_asset_headers" '^cache-control:.*max-age=2592000' "cache-control max-age=2592000" || _main_status=1

  _main_js_url="https://crimsonglow.ca/~kjiwa/assets/legacy-redirect.js"
  _main_js_headers=$(fetch_headers "$_main_js_url")
  assert_header "$_main_js_url" "$_main_js_headers" '^http_status: 200' "HTTP 200" || _main_status=1
  assert_header "$_main_js_url" "$_main_js_headers" '^content-encoding:' "content-encoding header" || _main_status=1
  assert_header "$_main_js_url" "$_main_js_headers" '^cache-control:.*max-age=600' "cache-control max-age=600" || _main_status=1

  return "$_main_status"
}

main "$@"

