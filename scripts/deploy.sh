#!/bin/sh
# Syncs site/_site to $SITE_BUCKET and invalidates $DISTRIBUTION_ID, using
# ambient AWS credentials. --dry-run lists the changes and skips invalidation.

set -eu

SITE_DIR="$(dirname "$0")/../site/_site"
readonly SITE_DIR

# Same lifetimes the Apache host used: HTML carries its stylesheet inline, so it
# stays short; asset filenames are unversioned, so max-age is their propagation
# delay.
HTML_CACHE_CONTROL="public, max-age=600"
ASSET_CACHE_CONTROL="public, max-age=2592000"
readonly HTML_CACHE_CONTROL ASSET_CACHE_CONTROL

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
  if [ "${1:-}" = "--dry-run" ]; then
    _main_dry_run="--dryrun"
  fi

  : "${SITE_BUCKET:?SITE_BUCKET is required}"
  : "${DISTRIBUTION_ID:?DISTRIBUTION_ID is required}"

  _sync_pages ${_main_dry_run:+"$_main_dry_run"}
  _sync_assets ${_main_dry_run:+"$_main_dry_run"}

  if [ -z "$_main_dry_run" ]; then
    aws cloudfront create-invalidation --distribution-id "$DISTRIBUTION_ID" --paths '/*'
  fi
}

main "$@"
