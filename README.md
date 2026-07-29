# crimsonglow.ca

Jekyll source for [crimsonglow.ca](https://crimsonglow.ca), hosted on ICDSoft.

## Layout

The build output mirrors the site's Apache document root, not just the `~kjiwa`
content directory:

```
_site/
├── .htaccess          # ErrorDocument + www/root redirects
├── robots.txt          # must live at the host root to be honoured by crawlers
├── sitemap.xml          # same
└── ~kjiwa/              # everything else — the actual site content
    ├── index.html
    ├── 404.html
    ├── feed.xml
    ├── assets/
    └── YYYY/MM/*.html    # posts
```

Source mirrors this: page/asset content lives under [`~kjiwa/`](~kjiwa/), while
`_posts/`, `_layouts/`, `_includes/`, and `_sass/` stay at the repo root because
Jekyll requires them there (none of them are emitted directly).

`site.baseurl` is intentionally empty — `page.url` already includes `/~kjiwa/`
via the `permalink` in [`_config.yml`](_config.yml). Templates that need to link
to the site root use `site.home` (`/~kjiwa`) instead.

## Build

```sh
bundle exec jekyll build
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
python3 -m http.server -d _site 8000   # http://localhost:8000/~kjiwa/
```

## Deploy

Upload the contents of `_site/` to the **document root** of the hosting
account — not into `~kjiwa/`. Make sure `.htaccess` actually transfers; many
FTP/SFTP clients hide dotfiles by default and will silently skip it.

Note: `~kjiwa` needs quoting or a `./` prefix in the shell (e.g. `cd "./~kjiwa"`)
— a bare `~kjiwa` is tilde-expanded to a home directory, not treated as a
relative path.
