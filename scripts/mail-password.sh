#!/bin/sh
# Stores a mailbox's IMAP password in SSM at /mail/<address>/password for the
# nightly backup. Terraform never sees the password, so it stays out of state.
# Uses AdministratorAccess unless AWS_PROFILE is set.

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
  if [ "$#" -ne 1 ]; then
    echo "usage: $(basename "$0") <address>" >&2
    exit 1
  fi
  _main_address="$1"

  _main_account=$(account_id)
  [ -n "$_main_account" ] || die "account_id not found in $TFVARS"
  AWS_PROFILE="${AWS_PROFILE:-AdministratorAccess-$_main_account}"
  export AWS_PROFILE
  ensure_login

  umask 077
  trap _cleanup EXIT INT TERM
  TMPFILE=$(mktemp)
  _read_password "$_main_address"

  aws ssm put-parameter --type SecureString --overwrite \
    --name "/mail/$_main_address/password" --value "file://$TMPFILE" >/dev/null
  echo "stored /mail/$_main_address/password"
}

main "$@"
