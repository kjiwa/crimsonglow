#!/bin/sh
# Downloads the mail backup for <address> and its mbsyncrc into
# ~/crimsonglow-mail/ and prints per-folder message counts. With --push, also
# uploads the Maildir to the live mailbox with `mbsync restore-<address>`.
# Uses ReadOnlyAccess to download and AdministratorAccess (SSM password read)
# to push, unless AWS_PROFILE is set.

set -eu

# shellcheck source=common.sh
. "$(dirname "$0")/common.sh"

readonly ARCHIVE_BUCKET="crimsonglow-archive"
readonly MAIL_DIR="$HOME/crimsonglow-mail"

_download() {
  mkdir -p "$MAIL_DIR/$1"
  aws s3 cp --only-show-errors "s3://$ARCHIVE_BUCKET/mbsyncrc" "$MAIL_DIR/mbsyncrc"
  aws s3 sync --only-show-errors "s3://$ARCHIVE_BUCKET/migadu/$1" "$MAIL_DIR/$1"
}

_print_counts() {
  find "$MAIL_DIR/$1" -type d -name cur | sort | while IFS= read -r _print_counts_cur; do
    _print_counts_folder=$(dirname "$_print_counts_cur")
    _print_counts_n=$(find "$_print_counts_folder/cur" "$_print_counts_folder/new" -type f 2>/dev/null | wc -l)
    printf '%8d  %s\n' "$_print_counts_n" "${_print_counts_folder#"$MAIL_DIR/$1/"}"
  done
}

main() {
  _main_push=0
  if [ "${1:-}" = "--push" ]; then
    _main_push=1
    shift
  fi
  if [ "$#" -ne 1 ]; then
    echo "usage: $(basename "$0") [--push] <address>" >&2
    exit 1
  fi
  _main_address="$1"

  _main_account=$(account_id)
  [ -n "$_main_account" ] || die "account_id not found in $TFVARS"
  if [ "$_main_push" -eq 1 ]; then
    _main_role=AdministratorAccess
  else
    _main_role=ReadOnlyAccess
  fi
  AWS_PROFILE="${AWS_PROFILE:-$_main_role-$_main_account}"
  export AWS_PROFILE
  ensure_login

  _download "$_main_address"
  _print_counts "$_main_address"

  if [ "$_main_push" -eq 1 ]; then
    mbsync -c "$MAIL_DIR/mbsyncrc" "restore-$_main_address"
  fi
}

main "$@"
