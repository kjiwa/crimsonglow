#!/bin/sh
# Confirms every redirect target in site/_data/redirects.yml is a file under site/_site/.

set -eu

# shellcheck source=common.sh
. "$(dirname "$0")/common.sh"

main() {
  _main_site="$(dirname "$0")/../site/_site"

  [ -d "$_main_site" ] || die "$_main_site does not exist. Run 'make build' first."

  _main_pairs=$(redirect_pairs)
  _main_status=0
  while read -r _main_from _main_target; do
    _main_file="$_main_site$_main_target"
    if [ ! -f "$_main_file" ]; then
      echo "check-redirects: $_main_target -> $_main_file does not exist" >&2
      _main_status=1
    fi
  done <<EOF
$_main_pairs
EOF

  return "$_main_status"
}

main "$@"
