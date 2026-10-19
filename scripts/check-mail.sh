#!/bin/sh
# Asserts the mail DNS records that point the domain at Migadu, and that
# mail.<domain> redirects to webmail with a certificate that validates.

set -eu

# shellcheck source=common.sh
. "$(dirname "$0")/common.sh"

readonly MAIL_DOMAIN="crimsonglow.ca"
readonly WEBMAIL_URL="https://webmail.migadu.com/"

assert_dns() {
  _assert_dns_type="$1"
  _assert_dns_name="$2"
  _assert_dns_pattern="$3"

  if ! dig +short "$_assert_dns_type" "$_assert_dns_name" | grep -qE "$_assert_dns_pattern"; then
    echo "check-mail: $_assert_dns_type $_assert_dns_name does not match '$_assert_dns_pattern'" >&2
    return 1
  fi
  return 0
}

main() {
  _main_status=0

  assert_dns MX "$MAIL_DOMAIN" '^10 aspmx1\.migadu\.com\.$' || _main_status=1
  assert_dns MX "$MAIL_DOMAIN" '^20 aspmx2\.migadu\.com\.$' || _main_status=1
  assert_dns TXT "$MAIL_DOMAIN" '^"v=spf1 include:spf\.migadu\.com -all"$' || _main_status=1
  assert_dns TXT "_dmarc.$MAIL_DOMAIN" '^"v=DMARC1;' || _main_status=1
  for _main_key in key1 key2 key3; do
    assert_dns CNAME "$_main_key._domainkey.$MAIL_DOMAIN" \
      "^$_main_key\\.$MAIL_DOMAIN\\._domainkey\\.migadu\\.com\\.\$" || _main_status=1
  done

  _main_headers=$(curl_site -I "https://mail.$MAIL_DOMAIN/" -w '\nhttp_status: %{http_code}\n')
  if ! printf '%s\n' "$_main_headers" | grep -q '^http_status: 301$' ||
    ! printf '%s\n' "$_main_headers" | tr -d '\r' | grep -qi "^location: $WEBMAIL_URL\$"; then
    echo "check-mail: https://mail.$MAIL_DOMAIN/ expected 301 to $WEBMAIL_URL" >&2
    _main_status=1
  fi

  return "$_main_status"
}

main "$@"
