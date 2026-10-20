#!/bin/sh
# Lambda entrypoint: writes the Alps config from the function's environment, then
# starts Alps for the Lambda Web Adapter to proxy to.

set -eu

CONFIG=/tmp/alps.toml
readonly CONFIG

main() {
  : "${LOGIN_KEY:?LOGIN_KEY is required}"
  : "${ALPS_HOST:?ALPS_HOST is required}"
  : "${AWS_LWA_PORT:?AWS_LWA_PORT is required}"

  cat >"$CONFIG" <<EOF
[server]
addr = "127.0.0.1:$AWS_LWA_PORT"
login_key = "$LOGIN_KEY"
trusted_origins = ["https://$ALPS_HOST"]
trusted_proxies = ["127.0.0.1/32"]
temp_dir = "/tmp"

[webauthn]
rpid = "$ALPS_HOST"
origins = ["https://$ALPS_HOST"]

[provider]
type = "imap"

[provider.imap]
server = "imaps://imap.migadu.com:993"

[smtp]
server = "smtps://smtp.migadu.com:465"

[plugin.caldav]
enabled = true
server = "https://cdav.migadu.com"

[plugin.carddav]
enabled = true
server = "https://cdav.migadu.com"
EOF

  exec "$(dirname "$0")/alps" -config "$CONFIG"
}

main "$@"
