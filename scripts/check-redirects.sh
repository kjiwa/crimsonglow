#!/bin/sh
# Confirms every redirect target in site/_data/redirects.yml resolves to a real
# file under site/_site/. A redirect map rots invisibly: rename or remove a post
# and its entry still fires a 301 -- just now into a 404 -- and nothing else in
# `make check` would notice, since html-proofer only sees links in built pages.

set -eu

# shellcheck source=common.sh
. "$(dirname "$0")/common.sh"

main() {
  _main_site="$(dirname "$0")/../site/_site"

  [ -d "$_main_site" ] || die "$_main_site does not exist. Run 'make build' first."

  _main_status=0
  for _main_target in $(redirect_pairs | cut -d ' ' -f 2); do
    _main_file="$_main_site$_main_target"
    if [ ! -f "$_main_file" ]; then
      echo "check-redirects: $_main_target -> $_main_file does not exist" >&2
      _main_status=1
    fi
  done

  return "$_main_status"
}

main "$@"
