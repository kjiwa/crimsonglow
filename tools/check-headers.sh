#!/bin/sh
# Asserts compression and cache headers on the live site.
#
# Usage: tools/check-headers.sh [BASE_URL]

set -eu

check_endpoint() {
  _check_url="$1"
  _check_want_encoding="$2"
  _check_want_cache="$3"
  _check_want_type="$4"

  _check_headers=$(curl -sSI -H "Accept-Encoding: gzip, deflate, br, zstd" "$_check_url" 2>&1) || {
    echo "check-headers: failed to connect to $_check_url" >&2
    return 1
  }

  _check_status=$(printf '%s\n' "$_check_headers" | head -n 1 | tr -d '\r')
  case "$_check_status" in
    *" 200"*) ;;
    *)
      echo "check-headers: $_check_url returned unexpected status: $_check_status" >&2
      return 1
      ;;
  esac

  _check_failed=0

  if [ -n "$_check_want_encoding" ]; then
    _check_enc=$(printf '%s\n' "$_check_headers" | tr -d '\r' | awk 'tolower($1) == "content-encoding:" {print $2}')
    if [ -z "$_check_enc" ]; then
      echo "check-headers: $_check_url missing content-encoding header" >&2
      _check_failed=1
    fi
  fi

  if [ -n "$_check_want_cache" ]; then
    _check_cache=$(printf '%s\n' "$_check_headers" | tr -d '\r' | awk -F': ' 'tolower($1) == "cache-control" {print $2}')
    case "$_check_cache" in
      *"$_check_want_cache"*) ;;
      *)
        echo "check-headers: $_check_url cache-control mismatch (got: '$_check_cache', expected substring: '$_check_want_cache')" >&2
        _check_failed=1
        ;;
    esac
  fi

  if [ -n "$_check_want_type" ]; then
    _check_type=$(printf '%s\n' "$_check_headers" | tr -d '\r' | awk -F': ' 'tolower($1) == "content-type" {print $2}')
    case "$_check_type" in
      *"$_check_want_type"*) ;;
      *)
        echo "check-headers: $_check_url content-type mismatch (got: '$_check_type', expected substring: '$_check_want_type')" >&2
        _check_failed=1
        ;;
    esac
  fi

  return "$_check_failed"
}

main() {
  command -v curl >/dev/null 2>&1 || {
    echo "check-headers: curl not found" >&2
    exit 1
  }

  readonly BASE_URL="${1:-${CRIMSONGLOW_URL:-https://crimsonglow.ca}}"
  readonly HTML_URL="${BASE_URL}/~kjiwa/2010/09/dos-boot-sector.html"
  readonly ASSET_URL="${BASE_URL}/~kjiwa/assets/og-card.png"

  _main_status=0

  if ! check_endpoint "$HTML_URL" "1" "max-age=600" "text/html"; then
    _main_status=1
  fi

  if ! check_endpoint "$ASSET_URL" "" "max-age=2592000" "image/png"; then
    _main_status=1
  fi

  if [ "$_main_status" -eq 0 ]; then
    echo "check-headers: all header assertions passed for $BASE_URL"
  fi

  exit "$_main_status"
}

main "$@"
