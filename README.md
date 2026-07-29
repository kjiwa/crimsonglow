# crimsonglow.ca

Jekyll source for [crimsonglow.ca](https://crimsonglow.ca), hosted on ICDSoft.

## Layout

The build output mirrors the site's Apache document root, not just the `~kjiwa`
content directory:

```
_site/
├── .htaccess        # ErrorDocument + www/root redirects
├── robots.txt       # must live at the host root to be honoured by crawlers
├── sitemap.xml      # same
└── ~kjiwa/          # everything else — the actual site content
    ├── index.html
    ├── 404.html
    ├── feed.xml
    ├── assets/
    └── YYYY/MM/*.html   # posts
```

Source mirrors this: page/asset content lives under [`~kjiwa/`](~kjiwa/), while
`_posts/`, `_layouts/`, `_includes/`, `_data/`, and `_sass/` stay at the repo
root because Jekyll requires them there.

## Prerequisites

- Ruby, matching [`.ruby-version`](.ruby-version), and Bundler. `Gemfile.lock`
  is checked in for `arm64-darwin`, `x86_64-linux`, and `aarch64-linux`, so
  `bundle install` works on Apple Silicon Macs and mainstream glibc Linux
  (Debian/Ubuntu/Fedora/Arch) without a `bundle lock --add-platform` step.
  musl-based distros (e.g. Alpine) aren't covered.
- To regenerate the social share card only: ImageMagick 6 or 7, `python3`, and
  a bold + regular Arial-metric-compatible font (Arial itself, or Liberation
  Sans / Arimo — see [tools/og-card.sh](tools/og-card.sh) for details and
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

- To deploy: [`lftp`](https://lftp.yar.ru/) (`brew install lftp` / `apt install
  lftp` / `dnf install lftp` / `pacman -S lftp`).

## Build

```sh
make build   # bundle exec jekyll build
make check   # build, then validate internal links/images with html-proofer
```

`make check` is exactly what [CI](.github/workflows/ci.yml) runs on every push
and pull request, so a green `make check` locally means CI will be green too.

To regenerate the social share card (`~kjiwa/assets/og-card.png`):

```sh
make og-card   # tools/og-card.sh
```

To preview, don't use `bundle exec jekyll serve` — Jekyll's own dev server
hides every path starting with `~` by design
([serve.rb](https://github.com/jekyll/jekyll/blob/main/lib/jekyll/commands/serve.rb),
`file_handler_opts`, `NondisclosureName => [".ht*", "~*"]`), so `/~kjiwa/`
always 404s under it regardless of what's actually in `_site/`. This looks
like an upstream typo (WEBrick's own default is `"*~"`, for backup files
ending in `~`, not `"~*"`) but there's no CLI flag to override it. Serve the
built output with a plain static server instead:

```sh
make serve   # python3 -m http.server -d _site 8000, http://localhost:8000/~kjiwa/
```

## Deploy

Deploying is manual, on purpose: ICDSoft only allows key-based SFTP for the
main Control Panel user, so automating this from CI would mean putting a
full-hosting-account credential in a GitHub secret. Instead,
[`tools/deploy.sh`](tools/deploy.sh) automates the upload itself — you just run
it locally.

One-time setup — add a `Host` block to `~/.ssh/config` (no credentials live in
this repo):

```
Host crimsonglow
  HostName <your-icdsoft-host>
  User <your-icdsoft-username>
  IdentityFile ~/.ssh/<your-key>
```

Then:

```sh
make deploy-dry-run   # see what would transfer, without changing anything remote
make deploy           # build, validate, and upload _site/ to the document root
```

`tools/deploy.sh` uses `lftp mirror --reverse`, which transfers dotfiles by
default — this is what makes sure `.htaccess` actually reaches the server;
many FTP/SFTP GUI clients hide dotfiles and silently skip it. It also refuses
to run against an uncommitted or unpushed working tree (skip with `--force`),
and never deletes remote-only files unless you pass `--delete` — see the
script's header comment for details and overrides
(`CRIMSONGLOW_SSH_HOST`, `CRIMSONGLOW_DOCROOT`).

Note: `~kjiwa` needs quoting or a `./` prefix in the shell (e.g. `cd "./~kjiwa"`)
— a bare `~kjiwa` is tilde-expanded to a home directory, not treated as a
relative path. `tools/deploy.sh` already handles this; it only matters if
you're poking around `_site/` by hand.
