#!/bin/sh
# Lambda entrypoint: writes the Alps config rendered by Terraform into the function's
# environment, then starts Alps for the Lambda Web Adapter to proxy to.

set -eu

CONFIG=/tmp/alps.toml
readonly CONFIG

main() {
  : "${ALPS_CONFIG:?ALPS_CONFIG is required}"

  umask 077
  printf '%s\n' "$ALPS_CONFIG" >"$CONFIG"

  exec "$(dirname "$0")/alps" -config "$CONFIG"
}

main "$@"
