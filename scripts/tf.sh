#!/bin/sh
# terraform -chdir=terraform with the AWS profile chosen from the subcommand:
# AdministratorAccess for state-changing ones, ReadOnlyAccess otherwise.
# AWS_PROFILE overrides. Refreshes the CI variables after a successful apply.

set -eu

# shellcheck source=common.sh
. "$(dirname "$0")/common.sh"

_profile_for() {
  _profile_for_account="$1"
  case "$2" in
    apply | import | state | force-unlock | taint | untaint | destroy | refresh | workspace)
      echo "AdministratorAccess-$_profile_for_account"
      ;;
    *)
      echo "ReadOnlyAccess-$_profile_for_account"
      ;;
  esac
}

main() {
  if [ "$#" -lt 1 ]; then
    echo "usage: $(basename "$0") <terraform subcommand> [args]" >&2
    exit 1
  fi
  _main_subcommand="$1"
  shift

  _main_account=$(account_id)
  if [ -z "$_main_account" ]; then
    die "account_id not found in $TFVARS"
  fi

  AWS_PROFILE="${AWS_PROFILE:-$(_profile_for "$_main_account" "$_main_subcommand")}"
  export AWS_PROFILE
  ensure_login

  if [ "$_main_subcommand" = plan ] && [ "$AWS_PROFILE" = "ReadOnlyAccess-$_main_account" ]; then
    set -- -lock=false "$@"
  fi

  terraform -chdir="$(dirname "$0")/../terraform" "$_main_subcommand" "$@"

  if [ "$_main_subcommand" = apply ]; then
    "$(dirname "$0")/ci-vars.sh"
  fi
}

main "$@"
