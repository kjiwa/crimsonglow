#!/bin/sh
# Uploads ./_site/ to the ICDSoft document root over SFTP. See README.md.
#
# Usage: tools/deploy.sh [--dry-run] [--delete] [--force]

set -eu

cd "$(dirname "$0")/.."

DRY_RUN=""
DELETE=""
FORCE=""
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN="--dry-run" ;;
    --delete) DELETE="--delete" ;;
    --force) FORCE=1 ;;
    *)
      echo "deploy: unknown argument: $arg" >&2
      echo "usage: tools/deploy.sh [--dry-run] [--delete] [--force]" >&2
      exit 1
      ;;
  esac
done

command -v lftp >/dev/null 2>&1 || {
  echo "deploy: lftp not found. Install it (brew install lftp / apt install lftp" >&2
  echo "  / dnf install lftp / pacman -S lftp)." >&2
  exit 1
}

# --- preflight guards ---------------------------------------------------
# Deploys ship from the local working tree, not a clean checkout, so it's
# easy to accidentally publish uncommitted or unpushed work. --force skips
# these for the rare deliberate case (e.g. reverting a bad deploy).

if [ -z "$FORCE" ]; then
  if [ -n "$(git status --porcelain)" ]; then
    echo "deploy: working tree has uncommitted changes. Commit or stash them," >&2
    echo "  or re-run with --force to deploy anyway." >&2
    exit 1
  fi

  if git rev-parse --verify --quiet origin/main >/dev/null; then
    local_head=$(git rev-parse HEAD)
    remote_head=$(git rev-parse origin/main)
    if [ "$local_head" != "$remote_head" ]; then
      echo "deploy: HEAD differs from origin/main -- this hasn't been through CI." >&2
      echo "  Push first, or re-run with --force to deploy anyway." >&2
      exit 1
    fi
  fi
fi

[ -d ./_site ] || {
  echo "deploy: ./_site does not exist. Run 'make build' first." >&2
  exit 1
}

SSH_HOST=${CRIMSONGLOW_SSH_HOST:-crimsonglow}
DOCROOT=${CRIMSONGLOW_DOCROOT:-www/www}

# ssh resolves an unconfigured alias to itself, so `open sftp://crimsonglow`
# degrades into a DNS lookup for the literal string "crimsonglow" and fails
# inside lftp's retry loop below, where the real error is easy to miss under
# --verbose --parallel=4 output. Catch it here instead, with no network call.
ssh_target=${SSH_HOST#*@}
resolved_host=$(ssh -G "$ssh_target" 2>/dev/null | awk '/^hostname /{print $2; exit}')
if [ "$resolved_host" = "$ssh_target" ] && ! echo "$ssh_target" | grep -q '\.'; then
  echo "deploy: '$ssh_target' is not a configured ssh host alias." >&2
  echo "  Add this to ~/.ssh/config:" >&2
  echo "    Host $ssh_target" >&2
  echo "      HostName <your-icdsoft-host>" >&2
  echo "      User <your-icdsoft-username>" >&2
  echo "      IdentityFile ~/.ssh/<your-key>" >&2
  echo "  Or set CRIMSONGLOW_SSH_HOST to a real hostname." >&2
  exit 1
fi

# --- transfer -------------------------------------------------------------

echo "deploy: mirroring ./_site/ to $SSH_HOST:$DOCROOT" >&2
[ -n "$DRY_RUN" ] && echo "deploy: --dry-run, nothing will actually transfer" >&2
[ -n "$DELETE" ] && echo "deploy: --delete is on -- remote-only files will be removed" >&2

# mirror --reverse transfers dotfiles (notably .htaccess) by default, unlike
# most FTP/SFTP GUI clients. Quote every _site path and keep the leading
# ./ -- the tree contains a literal ~kjiwa directory, and an unquoted ~kjiwa
# tilde-expands to a home directory in the shell.
#
# lftp retries a failed connection indefinitely by default, which turns a
# typo'd SSH host/alias into a silent hang instead of an error. Bound it.
lftp -c "
  set net:max-retries 3;
  set net:timeout 15;
  set net:reconnect-interval-base 5;
  set net:reconnect-interval-max 10;
  open sftp://$SSH_HOST;
  mirror --reverse --verbose --parallel=4 $DRY_RUN $DELETE \
    --exclude-glob .well-known/ \
    ./_site/ \"$DOCROOT\";
"
