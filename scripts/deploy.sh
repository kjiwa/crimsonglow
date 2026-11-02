#!/bin/sh
# Syncs site/_site to $SITE_BUCKET and invalidates $DISTRIBUTION_ID, using
# ambient AWS credentials. --dry-run lists the changes and skips invalidation.

set -eu

SITE_DIR="$(dirname "$0")/../site/_site"
readonly SITE_DIR

# shellcheck source=common.sh
. "$(dirname "$0")/common.sh"

_sync_pages() {
  aws s3 sync "$SITE_DIR" "s3://$SITE_BUCKET/" --delete "$@" \
    --exclude '*' --include '*.html' --include '*.xml' --include '*.txt' \
    --cache-control "$HTML_CACHE_CONTROL"
}

_sync_assets() {
  aws s3 sync "$SITE_DIR" "s3://$SITE_BUCKET/" --delete "$@" \
    --exclude '*.html' --exclude '*.xml' --exclude '*.txt' \
    --cache-control "$ASSET_CACHE_CONTROL"
}

main() {
  _main_dry_run=""
  case "${1:-}" in
    "") ;;
    --dry-run) _main_dry_run="--dryrun" ;;
    *) die "usage: $(basename "$0") [--dry-run]" ;;
  esac

  : "${SITE_BUCKET:?SITE_BUCKET is required}"
  : "${DISTRIBUTION_ID:?DISTRIBUTION_ID is required}"

  _sync_assets ${_main_dry_run:+"$_main_dry_run"}
  _sync_pages ${_main_dry_run:+"$_main_dry_run"}

  if [ -z "$_main_dry_run" ]; then
    aws cloudfront create-invalidation --distribution-id "$DISTRIBUTION_ID" --paths '/*'
  fi
}

main "$@"
