#!/bin/sh
# Uploads webmail/dist/alps.zip as the code of $WEBMAIL_FUNCTION and waits for the
# update to finish, using ambient AWS credentials.

set -eu

# shellcheck source=common.sh
. "$(dirname "$0")/common.sh"

ZIP="$(dirname "$0")/../webmail/dist/alps.zip"
readonly ZIP

main() {
  : "${WEBMAIL_FUNCTION:?WEBMAIL_FUNCTION is required}"
  [ -f "$ZIP" ] || { echo "$ZIP is missing; run make webmail" >&2; exit 1; }

  aws lambda update-function-code --function-name "$WEBMAIL_FUNCTION" \
    --zip-file "fileb://$ZIP" --query CodeSha256 --output text
  aws lambda wait function-updated --function-name "$WEBMAIL_FUNCTION"
}

main "$@"
