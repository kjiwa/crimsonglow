#!/bin/sh
# Confirms every redirect target in .htaccess resolves to a real file under
# _site/. A redirect map rots invisibly: rename or remove a post and its
# RewriteRule still matches and still fires a 301 -- just now into a 404 --
# and nothing else in `make check` would notice, since neither Jekyll nor
# html-proofer knows .htaccess exists. This script closes that gap.

set -eu

cd "$(dirname "$0")/.."

[ -d _site ] || {
  echo "check-redirects: _site/ does not exist. Run 'make build' first." >&2
  exit 1
}

# Parse the source .htaccess, not _site/.htaccess. The two are byte-identical
# -- the file has no YAML front matter, so Jekyll copies it verbatim -- but
# the source is what's tracked in git and what a human actually edits, and it
# exists even before a build has run.
#
# The target is field 3 on both RewriteRule (directive, pattern, target) and
# ErrorDocument 404 (directive, code, target) lines. [[:space:]] is a POSIX
# bracket expression; \s is a GNU grep extension some BSD greps (macOS) lack.
targets=$(grep -E '^[[:space:]]*(RewriteRule|ErrorDocument[[:space:]]+404)' \
  .htaccess | awk '{print $3}')

status=0
for target in $targets; do
  # %1, %{REQUEST_URI}, etc. are backreferences/server variables that forward
  # a client-supplied path onward -- there's no static target here to assert.
  case "$target" in
    *%*) continue ;;
  esac

  # Strip the apex prefix, if any, to get a docroot-relative path. A path
  # ending in / (like the /~kjiwa/ lobby redirect) means its own index.html.
  path=${target#https://crimsonglow.ca}
  case "$path" in
    */) path="${path}index.html" ;;
  esac

  file="_site$path"
  if [ ! -f "$file" ]; then
    echo "check-redirects: $target -> $file does not exist" >&2
    status=1
  fi
done

exit "$status"
