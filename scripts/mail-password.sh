#!/bin/sh
# Stores a mailbox's IMAP password in SSM at /mail/<address>/password, with @
# written as _at_ because parameter names disallow it (mbsyncrc.tftpl applies
# the same mapping), for the daily backup. Terraform never sees the password, so
# it stays out of state. Uses AdministratorAccess unless AWS_PROFILE is set.

set -eu

# shellcheck source=common.sh
. "$(dirname "$0")/common.sh"

TMPFILE=""
TTY_STATE=""

_cleanup() {
  if [ -n "$TTY_STATE" ]; then
    stty "$TTY_STATE"
  fi
  if [ -n "$TMPFILE" ]; then
    rm -f "$TMPFILE"
  fi
}

_read_password() {
  TTY_STATE=$(stty -g)
  stty -echo
  printf 'IMAP password for %s: ' "$1" >&2
  IFS= read -r _read_password_value
  stty "$TTY_STATE"
  TTY_STATE=""
  echo >&2
  [ -n "$_read_password_value" ] || die "empty password"
  printf '%s' "$_read_password_value" >"$TMPFILE"
}

main() {
  [ "$#" -eq 1 ] || die "usage: $(basename "$0") <address>"
  _main_address="$1"

  use_profile AdministratorAccess

  umask 077
  trap _cleanup EXIT
  trap '_cleanup; exit 130' INT TERM
  TMPFILE=$(mktemp)
  _read_password "$_main_address"

  _main_param="/mail/$(printf '%s' "$_main_address" | sed 's/@/_at_/')/password"
  aws ssm put-parameter --type SecureString --overwrite \
    --name "$_main_param" --value "file://$TMPFILE" >/dev/null
  echo "stored $_main_param"
}

main "$@"
