# Mail

Mail is hosted by Migadu. This repository owns three things around it: the DNS records, the
webmail at `mail.crimsonglow.ca`, and a nightly backup. How they fit into AWS:
[`ARCHITECTURE.md`](ARCHITECTURE.md).

## Webmail

`mail.crimsonglow.ca` serves [Alps](https://github.com/migadu/alps), Migadu's own webmail, from
a Lambda function behind an API Gateway HTTP API. The Lambda Web Adapter runs the Alps binary;
Its config is [`alps.toml.tftpl`](../terraform/webmail/alps.toml.tftpl), rendered by Terraform; [`webmail/run.sh`](../webmail/run.sh) writes it at start. Sign-in
goes to Migadu's IMAP and SMTP servers, calendars and contacts to Migadu's CalDAV and CardDAV
server; Alps stores a user's settings in IMAP metadata, so the function holds no state beyond the
login key (Terraform-generated, in state).

Alps has no theme layer. [`scripts/webmail-build.sh`](../scripts/webmail-build.sh) checks out the
commit in [`webmail/alps.ref`](../webmail/alps.ref), and [`webmail/theme.mjs`](../webmail/theme.mjs)
rewrites its colours, fonts, title and logo from the site's design tokens
([`site/_sass/tokens.scss`](../site/_sass/tokens.scss)) and font faces
([`site/_sass/fonts.scss`](../site/_sass/fonts.scss)), published together as `site-tokens.css`.
[`webmail/paths.mjs`](../webmail/paths.mjs) adds a layer of URL encoding to mailbox and DAV path
segments, because API Gateway decodes the path once more than Alps expects and names containing
`/`, such as `[Gmail]/All Mail`, would otherwise 404. A token or font change reaches the webmail on the next deploy. To update Alps,
change `alps.ref` and run `make webmail`; the patches fail loudly if upstream moved something it edits.

Limits:

- A request over about 4.5 MB in total is rejected by API Gateway with a 413: attachments are
  base64-encoded on upload and Lambda caps payloads at 6 MB. Send larger files from Migadu's
  webmail or any IMAP client.
- Two-factor sign-in is WebAuthn only (passkey or security key); Alps has no TOTP. Keys are
  stored in the mailbox's IMAP metadata. Alps asks for it at its own login; IMAP and SMTP
  clients are never asked.
- Rate limits and sessions are per Lambda environment. The stage throttles total load, and the
  login cookie rebuilds a session on any environment.

Rotate the login key (signs everyone out):

```sh
scripts/tf.sh apply -replace=random_bytes.login_key
```

## Backup

A nightly CodeBuild job (`mail-backup`, started by EventBridge Scheduler) pulls each mailbox in
`mailboxes` ([`terraform.tfvars`](../terraform/terraform.tfvars)) with `mbsync` into the
`crimsonglow-archive` bucket under `migadu/<address>/`, as a Maildir. The pull never expunges, and a
folder deleted on the server keeps its archived copy (only an empty one is dropped); history
lives in S3 versions. The rendered `mbsyncrc` sits at the bucket root. A CloudWatch alarm emails
`alert_emails` when the backup stops succeeding and again when it recovers; retention and alarm
timing are in [`ARCHITECTURE.md`](ARCHITECTURE.md#mail-backup).

After adding a mailbox, store its IMAP password (kept in SSM, never in Terraform state), then
apply:

```sh
scripts/mail-password.sh <address>
scripts/tf.sh apply
```

## Restore

Needs `isync` (`mbsync`) and the AWS CLI:

```sh
scripts/mail-restore.sh <address>         # download to ~/crimsonglow-mail/, print folder counts
scripts/mail-restore.sh --push <address>  # also upload to <address>, which must be empty or new
```

- `--push` is for a lost or new mailbox. It asks you to confirm the target is empty, because
  `mbsync` does not de-duplicate and a second push doubles the mail. It also ignores the backup's
  sync state, so it re-creates deleted folders. To recover a few messages from a mailbox that
  still exists, open the Maildir in a client and copy them.
- Read offline: point any Maildir-capable client at `~/crimsonglow-mail/<address>/`.
- Another provider: edit `Host` and `User` (and `PassCmd`) in the downloaded
  `~/crimsonglow-mail/mbsyncrc`, then run `scripts/mail-restore.sh --push`.
