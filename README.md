# crimsonglow.ca

Source for [crimsonglow.ca](https://crimsonglow.ca): a Jekyll site, an Alps webmail, a nightly
mailbox backup, and the Terraform that runs them on AWS.

## Repository

| Path | Holds |
|---|---|
| [`site/`](site/) | Jekyll source; `_site/` is the built output |
| [`terraform/`](terraform/) | AWS infrastructure: S3, CloudFront, Route 53, IAM, webmail, mail backup |
| [`webmail/`](webmail/) | Alps webmail: pinned upstream ref, theme and path patches, Lambda launcher |
| [`scripts/`](scripts/) | POSIX `sh` checks and tooling |
| [`docs/`](docs/) | [`ARCHITECTURE.md`](docs/ARCHITECTURE.md): what is deployed. [`MAIL.md`](docs/MAIL.md): webmail, backup, restore |
| [`.github/`](.github/) | CI, deploy, weekly link check, Terraform checks, Dependabot |
| [`LICENSE`](LICENSE), [`LICENSE-CONTENT`](LICENSE-CONTENT) | Code under MIT, written content under CC BY 4.0 |

Inside `site/`:

| Path | Holds |
|---|---|
| `_posts/`, `_layouts/`, `_includes/`, `_data/`, `_sass/` | Required at the Jekyll source root, so they sit beside `~kjiwa/` |
| `_sass/tokens.scss` | Design tokens: the one source of colours and font stacks for the site and the webmail |
| `_data/redirects.yml` | Legacy path to target; the single source for the JavaScript fallback and the edge router |
| `robots.txt` | Must live at the host root to be honoured by crawlers |
| `~kjiwa/` | Pages and assets, served at `/~kjiwa/` |

In a shell, quote it or prefix it (`cd "./~kjiwa"`): a bare `~kjiwa` expands to a home directory.

## Prerequisites

- Ruby matching [`site/.ruby-version`](site/.ruby-version), and Bundler. `site/Gemfile.lock`
  covers `arm64-darwin`, `x86_64-linux` and `aarch64-linux`, so `bundle install` works on Apple
  Silicon and mainstream glibc Linux without `bundle lock --add-platform`. musl distros such as
  Alpine are not covered.
- [`shellcheck`](https://www.shellcheck.net/) to lint scripts.
- Go and Node, matching [`ci.yml`](.github/workflows/ci.yml), plus `git` and `zip`, to build the
  webmail bundle.
- `curl` and `dig` for the live checks.
- ImageMagick 6 or 7, `python3` and an Arial-metric font to regenerate the social share card
  only; see [`scripts/og-card.sh`](scripts/og-card.sh) for fonts and override variables.

  ```sh
  brew install imagemagick                                # macOS
  sudo apt install imagemagick fonts-liberation           # Debian, Ubuntu
  sudo dnf install ImageMagick liberation-sans-fonts      # Fedora, RHEL
  sudo pacman -S imagemagick ttf-liberation               # Arch
  ```

## Commands

| Command | Does |
|---|---|
| `make build` | Build the site with Jekyll |
| `make check` | Build, then validate redirect targets and internal links and images |
| `make lint` | Run `shellcheck` over `scripts/*.sh` |
| `make webmail` | Build `webmail/dist/alps.zip`; run `make build` first, it reads the built design tokens |
| `make check-live` | Query the live host: headers, routes, mail DNS. Not part of CI; set `CHECK_CONNECT_TO=<host>` to probe another origin, such as a CloudFront domain, before DNS points at it |
| `make link-check` | `check` plus external links; the weekly workflow runs it |
| `make og-card` | Regenerate `site/~kjiwa/assets/og-card.png` |
| `make serve` | Serve `site/_site` at <http://localhost:8000/~kjiwa/> |

[CI](.github/workflows/ci.yml) runs `make lint check` and `make webmail` on every push and pull
request, so run all three before you open one. Preview with `make serve`, not `jekyll serve`: Jekyll's dev server hides every path
starting with `~` by design (`NondisclosureName => [".ht*", "~*"]` in
[`serve.rb`](https://github.com/jekyll/jekyll/blob/main/lib/jekyll/commands/serve.rb)), so
`/~kjiwa/` would always 404.

To screenshot every page at phone, laptop and desktop widths in light and dark under the
production CSP, with [Playwright](https://playwright.dev) and a built site:

```sh
PLAYWRIGHT_MODULE=/path/to/node_modules/playwright/index.mjs \
  node scripts/screenshots.mjs site/_site <out-dir>
```

## Deploy

A push to `main` runs the checks, then the `deploy` job syncs `site/_site` to S3, invalidates
CloudFront and uploads the webmail bundle, authenticated by GitHub OIDC with no stored keys. The
Terraform is applied by hand with `scripts/tf.sh`, which also refreshes the GitHub variables CI
reads (`scripts/ci-vars.sh`); `scripts/deploy.sh --dry-run` previews a site sync. Topology, roles
and reasons:
[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md). The AWS account ID in `terraform.tfvars` is
committed on purpose: AWS does not treat it as secret, and the deploy role's trust policy admits
just this repository's `main` branch.

## License

Code (scripts, Terraform, Jekyll layouts, styles, build configuration) is MIT licensed,
Copyright (c) 2026 Kamil Jiwa; see [LICENSE](LICENSE). Written content (posts and pages under
`site/_posts/` and `site/~kjiwa/`) is CC BY 4.0, Copyright (c) 2004-2026 Kamil Jiwa; see
[LICENSE-CONTENT](LICENSE-CONTENT).
