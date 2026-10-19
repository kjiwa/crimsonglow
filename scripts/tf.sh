#!/bin/sh
# terraform -chdir=terraform with the AWS profile chosen from the subcommand:
# AdministratorAccess for state-changing ones, ReadOnlyAccess otherwise.
# AWS_PROFILE overrides. Refreshes the CI variables after a successful apply.

set -eu

TFVARS="$(dirname "$0")/../terraform/terraform.tfvars"
readonly TFVARS

_account_id() {
  sed -n 's/^account_id *= *"\([0-9]*\)".*/\1/p' "$TFVARS"
}

_profile_for() {
  _profile_for_account="$1"
  case "$2" in
    apply | import | state | force-unlock | taint | untaint | destroy)
      echo "AdministratorAccess-$_profile_for_account"
      ;;
    *)
      echo "ReadOnlyAccess-$_profile_for_account"
      ;;
  esac
}

_ensure_login() {
  if ! aws sts get-caller-identity >/dev/null 2>&1; then
    aws sso login
  fi
}

main() {
  if [ "$#" -lt 1 ]; then
    echo "usage: $(basename "$0") <terraform subcommand> [args]" >&2
    exit 1
  fi
  _main_subcommand="$1"
  shift

  _main_account=$(_account_id)
  if [ -z "$_main_account" ]; then
    echo "$(basename "$0"): account_id not found in $TFVARS" >&2
    exit 1
  fi

  AWS_PROFILE="${AWS_PROFILE:-$(_profile_for "$_main_account" "$_main_subcommand")}"
  export AWS_PROFILE
  _ensure_login

  if [ "$_main_subcommand" = plan ] && [ "$AWS_PROFILE" = "ReadOnlyAccess-$_main_account" ]; then
    set -- -lock=false "$@"
  fi

  terraform -chdir="$(dirname "$0")/../terraform" "$_main_subcommand" "$@"

  if [ "$_main_subcommand" = apply ]; then
    "$(dirname "$0")/ci-vars.sh"
  fi
}

main "$@"
