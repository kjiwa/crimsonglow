#!/bin/sh
# terraform -chdir=terraform with the AWS profile chosen from the subcommand:
# AdministratorAccess for state-changing ones, ReadOnlyAccess otherwise.
# AWS_PROFILE overrides. Refreshes the CI variables after a successful apply.

set -eu

# shellcheck source=common.sh
. "$(dirname "$0")/common.sh"

_role_for() {
  case "$1" in
    apply | import | state | force-unlock | taint | untaint | destroy | refresh | workspace)
      echo AdministratorAccess
      ;;
    *)
      echo ReadOnlyAccess
      ;;
  esac
}

main() {
  [ "$#" -ge 1 ] || die "usage: $(basename "$0") <terraform subcommand> [args]"
  _main_subcommand="$1"
  shift

  use_profile "$(_role_for "$_main_subcommand")"

  if [ "$_main_subcommand" = plan ] && [ "$AWS_PROFILE" = "ReadOnlyAccess-$(account_id)" ]; then
    set -- -lock=false "$@"
  fi

  terraform -chdir="$(dirname "$0")/../terraform" "$_main_subcommand" "$@"

  if [ "$_main_subcommand" = apply ]; then
    "$(dirname "$0")/ci-vars.sh"
  fi
}

main "$@"
