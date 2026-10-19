#!/bin/sh
# Asserts the exact status and Location of every routing rule the host must
# implement: lobby redirect, canonical host, scheme, trailing slash, legacy
# paths, and the 404 page. Runs against the live site, or against a candidate
# origin via CHECK_CONNECT_TO.

set -eu

# shellcheck source=common.sh
. "$(dirname "$0")/common.sh"

assert_route() {
  _assert_route_url="$1"
  _assert_route_status="$2"
  _assert_route_location="$3"

  _assert_route_headers=$(fetch_headers "$_assert_route_url")
  _assert_route_got_status=$(printf '%s\n' "$_assert_route_headers" |
    sed -n 's/^http_status: //p')
  _assert_route_got_location=$(printf '%s\n' "$_assert_route_headers" |
    tr -d '\r' | sed -n 's/^[Ll][Oo][Cc][Aa][Tt][Ii][Oo][Nn]: //p')

  if [ "$_assert_route_got_status" != "$_assert_route_status" ] ||
    [ "$_assert_route_got_location" != "$_assert_route_location" ]; then
    echo "check-routes: $_assert_route_url expected $_assert_route_status '$_assert_route_location'," \
      "got $_assert_route_got_status '$_assert_route_got_location'" >&2
    return 1
  fi
  return 0
}

assert_not_found() {
  _assert_not_found_url="$1"

  _assert_not_found_status=$(fetch_headers "$_assert_not_found_url" |
    sed -n 's/^http_status: //p')
  if [ "$_assert_not_found_status" != "404" ]; then
    echo "check-routes: $_assert_not_found_url expected 404, got $_assert_not_found_status" >&2
    return 1
  fi
  if ! fetch_body "$_assert_not_found_url" | grep -q 'Page Not Found'; then
    echo "check-routes: $_assert_not_found_url 404 body missing 'Page Not Found'" >&2
    return 1
  fi
  return 0
}

main() {
  _main_status=0
  _main_home="$SITE_ORIGIN/~kjiwa/"

  assert_route "$SITE_ORIGIN/" 301 "$_main_home" || _main_status=1
  assert_route "$SITE_ORIGIN/~kjiwa" 301 "$_main_home" || _main_status=1
  assert_route "https://www.crimsonglow.ca/~kjiwa/" 301 "$_main_home" || _main_status=1
  assert_route "http://crimsonglow.ca/~kjiwa/" 301 "$_main_home" || _main_status=1

  redirect_pairs | {
    _main_pairs_status=0
    while read -r _main_from _main_to; do
      assert_route "$SITE_ORIGIN$_main_from" 301 "$SITE_ORIGIN$_main_to" || _main_pairs_status=1
    done
    exit "$_main_pairs_status"
  } || _main_status=1

  assert_not_found "$SITE_ORIGIN/~kjiwa/no-such-page" || _main_status=1

  return "$_main_status"
}

main "$@"
