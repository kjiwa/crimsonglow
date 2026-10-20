# crimsonglow.ca

Jekyll source for [crimsonglow.ca](https://crimsonglow.ca), served from AWS (S3 + CloudFront); migrating from ICDSoft.

## Layout

```
site/                  Jekyll source; _site/ is the built output
├── _config.yml  _data/  _includes/  _layouts/  _posts/  _sass/
├── _data/redirects.yml  # legacy path -> target; single source for the JS fallback and the edge router
├── robots.txt           # must live at the host root to be honoured by crawlers
└── ~kjiwa/              # page and asset content, served at /~kjiwa/
terraform/             # AWS infrastructure (S3, CloudFront, Route 53, IAM, webmail, mail backup)
webmail/               # Alps webmail: pinned upstream ref, theme patch, Lambda launcher
scripts/               # POSIX sh checks and tooling
```

Jekyll requires `_posts/`, `_layouts/`, `_includes/`, `_data/`, and `_sass/` at
its source root, which is why they sit beside `~kjiwa/` inside `site/`.

## Prerequisites

- Ruby, matching [`site/.ruby-version`](site/.ruby-version), and Bundler. `site/Gemfile.lock`
  is checked in for `arm64-darwin`, `x86_64-linux`, and `aarch64-linux`, so
  `bundle install` works on Apple Silicon Macs and mainstream glibc Linux
  (Debian/Ubuntu/Fedora/Arch) without a `bundle lock --add-platform` step.
  musl-based distros (e.g. Alpine) aren't covered.
- To regenerate the social share card only: ImageMagick 6 or 7, `python3`, and
  a bold + regular Arial-metric-compatible font (Arial itself, or Liberation
  Sans / Arimo — see [scripts/og-card.sh](scripts/og-card.sh) for details and
  override variables).

  ```sh
  # macOS
  brew install imagemagick

  # Debian / Ubuntu
  sudo apt install imagemagick fonts-liberation

  # Fedora / RHEL
  sudo dnf install ImageMagick liberation-sans-fonts

  # Arch
  sudo pacman -S imagemagick ttf-liberation
  ```

- To build the webmail bundle only: Go and Node, matching the versions in
  [`ci.yml`](.github/workflows/ci.yml), plus `git` and `zip`.
- To lint scripts: [`shellcheck`](https://www.shellcheck.net/).
- For live checks: `curl`, `dig`.

## Build

```sh
make build   # bundle exec jekyll build
make lint    # shellcheck scripts/*.sh
make webmail # build webmail/dist/alps.zip (needs the built site for its design tokens)
make check   # build, then validate redirect targets and internal links/images
```

`make lint check` is exactly what [CI](.github/workflows/ci.yml) runs on every push
and pull request.

To verify headers and routing (status and `Location` of every redirect, the 404
page) on the live site:

```sh
make check-live   # scripts/check-headers.sh, scripts/check-routes.sh, scripts/check-mail.sh
```

Set `CHECK_CONNECT_TO=<host>` to probe a different origin (for example a
CloudFront distribution domain) before DNS points at it.

`make check-live` is deliberately separate from `make check` and CI because it
queries the live host over the network.

To regenerate the social share card (`~kjiwa/assets/og-card.png`):

```sh
make og-card   # scripts/og-card.sh
```

To preview, don't use `bundle exec jekyll serve` — Jekyll's own dev server
hides every path starting with `~` by design
([serve.rb](https://github.com/jekyll/jekyll/blob/main/lib/jekyll/commands/serve.rb),
`file_handler_opts`, `NondisclosureName => [".ht*", "~*"]`), so `/~kjiwa/`
always 404s under it regardless of what's actually in `site/_site/`. This looks
like an upstream typo (WEBrick's own default is `"*~"`, for backup files
ending in `~`, not `"~*"`) but there's no CLI flag to override it. Serve the
built output with a plain static server instead:

```sh
make serve   # python3 -m http.server -d site/_site 8000, http://localhost:8000/~kjiwa/
```

## Deploy

Pushes to `main` deploy through the `deploy` job in
[`ci.yml`](.github/workflows/ci.yml), which assumes an AWS role by GitHub OIDC,
syncs `site/_site` to S3, invalidates CloudFront, and uploads the webmail bundle
to its Lambda function. The infrastructure lives
in [`terraform/`](terraform/). The AWS account ID in `terraform.tfvars` is
committed on purpose: AWS does not treat it as secret, and the only role's trust
policy admits just this repository's `main` branch through GitHub OIDC.

Note: `~kjiwa` needs quoting or a `./` prefix in the shell (e.g. `cd "./~kjiwa"`)
-- a bare `~kjiwa` is tilde-expanded to a home directory, not treated as a
relative path. This only matters if you're poking around `site/` by hand.

## Webmail

`mail.crimsonglow.ca` serves [Alps](https://github.com/migadu/alps), Migadu's own
webmail, from a Lambda function behind an API Gateway HTTP API (CloudFront cannot
front it: its origin access control needs a body hash on every POST). The Lambda
Web Adapter runs the Alps binary; [`webmail/run.sh`](webmail/run.sh) writes its
config from the function's environment. Sign-in goes to Migadu's IMAP and SMTP
servers; Alps stores a user's settings in IMAP metadata, so the function holds no
state beyond the login key (Terraform-generated, in state).

Alps has no theme layer. [`scripts/webmail-build.sh`](scripts/webmail-build.sh)
checks out the commit in [`webmail/alps.ref`](webmail/alps.ref) and
[`webmail/theme.mjs`](webmail/theme.mjs) rewrites its colours, font, title and logo
from the site's design tokens ([`site/_sass/tokens.scss`](site/_sass/tokens.scss),
published as `site-tokens.css`), so a token change reaches the webmail on the next
deploy. To update Alps, change `alps.ref` and run `make webmail`; the patch fails
loudly if upstream moved something it edits.

- Attachments are limited by Lambda's 6 MB request and response payload, about 4 MB
  of file once encoded.
- Rate limits and sessions are per Lambda environment; the stage throttles total
  load, and the login cookie rebuilds a session on any environment.
- Rotate the login key (signs everyone out) with
  `scripts/tf.sh apply -replace=random_bytes.login_key`.

## Mail backup and restore

Migadu does not promise to keep a terminated account's mail, so a nightly
CodeBuild job (`mail-backup`, started by EventBridge Scheduler) pulls each
mailbox in `mailboxes` ([`terraform.tfvars`](terraform/terraform.tfvars)) with
`mbsync` into the `crimsonglow-archive` bucket under `migadu/<address>/`, as a
Maildir. The pull never expunges or removes; history lives in S3 versions,
kept 365 days. The rendered `mbsyncrc` sits at the bucket root. A CloudWatch
alarm emails `alert_emails` when no build succeeds for two days.

After adding a mailbox, store its IMAP password (kept in SSM, never in
Terraform state), then apply:

```sh
scripts/mail-password.sh <address>
scripts/tf.sh apply
```

Restore needs `isync` (`mbsync`) and the AWS CLI:

```sh
scripts/mail-restore.sh <address>         # download to ~/crimsonglow-mail/, print folder counts
scripts/mail-restore.sh --push <address>  # also upload to <address>, which must be empty or new
```

- `--push` is for a lost or new mailbox: it asks you to confirm the target is empty,
  because `mbsync` does not de-duplicate and a second push doubles the mail. It also
  ignores the backup's sync state, so it re-creates deleted folders. To recover a few
  messages from a mailbox that still exists, open the Maildir in a client and copy them.
- Read offline: point any Maildir-capable client at `~/crimsonglow-mail/<address>/`.
- Another provider: edit `Host` and `User` (and `PassCmd`) in the downloaded
  `~/crimsonglow-mail/mbsyncrc`, then run `scripts/mail-restore.sh --push`.

## License

Code (scripts, Terraform, Jekyll layouts, styles, and build configuration) is
MIT licensed, Copyright (c) 2026 Kamil Jiwa; see [LICENSE](LICENSE).

Written content (posts and pages under `site/_posts/` and `site/~kjiwa/`) is
licensed CC BY 4.0, Copyright (c) 2004-2026 Kamil Jiwa; see
[LICENSE-CONTENT](LICENSE-CONTENT).
