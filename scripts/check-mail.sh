#!/bin/sh
# Asserts the mail DNS records that point the domain at Migadu, and that
# mail.<domain> serves the webmail login page with a certificate that validates.

set -eu

# shellcheck source=common.sh
. "$(dirname "$0")/common.sh"

readonly MAIL_DOMAIN="crimsonglow.ca"

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

  _main_page=$(curl_site "https://mail.$MAIL_DOMAIN/" -w '\nhttp_status: %{http_code}\n')
  if ! printf '%s\n' "$_main_page" | grep -q '^http_status: 200$'; then
    echo "check-mail: https://mail.$MAIL_DOMAIN/ expected 200" >&2
    _main_status=1
  fi
  if ! printf '%s\n' "$_main_page" | grep -q '<title>~kjiwa mail</title>'; then
    echo "check-mail: https://mail.$MAIL_DOMAIN/ is not the webmail login page" >&2
    _main_status=1
  fi

  return "$_main_status"
}

main "$@"
