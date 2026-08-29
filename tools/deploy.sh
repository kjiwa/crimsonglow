#!/bin/sh
# Uploads ./_site/ to the ICDSoft document root over SFTP. See README.md.
#
# Usage: tools/deploy.sh [--dry-run] [--delete] [--force]

set -eu

check_preflight() {
  _check_preflight_force="$1"

  # Deploys ship from the local working tree, not a clean checkout, so it's
  # easy to accidentally publish uncommitted or unpushed work. --force skips
  # these for the rare deliberate case (e.g. reverting a bad deploy).
  if [ -z "$_check_preflight_force" ]; then
    if [ -n "$(git status --porcelain)" ]; then
      echo "deploy: working tree has uncommitted changes. Commit or stash them," >&2
      echo "  or re-run with --force to deploy anyway." >&2
      return 1
    fi

    if git rev-parse --verify --quiet origin/main >/dev/null; then
      _check_preflight_local_head=$(git rev-parse HEAD)
      _check_preflight_remote_head=$(git rev-parse origin/main)
      if [ "$_check_preflight_local_head" != "$_check_preflight_remote_head" ]; then
        echo "deploy: HEAD differs from origin/main -- this hasn't been through CI." >&2
        echo "  Push first, or re-run with --force to deploy anyway." >&2
        return 1
      fi
    fi
  fi
  return 0
}

validate_ssh_host() {
  _validate_ssh_host="$1"

  # ssh resolves an unconfigured alias to itself, so `open sftp://crimsonglow`
  # degrades into a DNS lookup for the literal string "crimsonglow" and fails
  # inside lftp's retry loop below, where the real error is easy to miss under
  # --verbose --parallel=4 output. Catch it here instead, with no network call.
  _validate_ssh_target="${_validate_ssh_host#*@}"
  _validate_resolved_host=$(ssh -G "$_validate_ssh_target" 2>/dev/null | awk '/^hostname /{print $2; exit}')
  if [ "$_validate_resolved_host" = "$_validate_ssh_target" ] && ! echo "$_validate_ssh_target" | grep -q '\.'; then
    echo "deploy: '$_validate_ssh_target' is not a configured ssh host alias." >&2
    echo "  Add this to ~/.ssh/config:" >&2
    echo "    Host $_validate_ssh_target" >&2
    echo "      HostName <your-icdsoft-host>" >&2
    echo "      User <your-icdsoft-username>" >&2
    echo "      IdentityFile ~/.ssh/<your-key>" >&2
    echo "  Or set CRIMSONGLOW_SSH_HOST to a real hostname." >&2
    return 1
  fi
  return 0
}

main() {
  _main_dir="$(dirname "$0")/.."
  cd "$_main_dir"

  _main_dry_run=""
  _main_delete=""
  _main_force=""
  for _main_arg in "$@"; do
    case "$_main_arg" in
      --dry-run) _main_dry_run="--dry-run" ;;
      --delete) _main_delete="--delete" ;;
      --force) _main_force=1 ;;
      *)
        echo "deploy: unknown argument: $_main_arg" >&2
        echo "usage: tools/deploy.sh [--dry-run] [--delete] [--force]" >&2
        return 1
        ;;
    esac
  done

  if ! command -v lftp >/dev/null 2>&1; then
    echo "deploy: lftp not found. Install it (brew install lftp / apt install lftp" >&2
    echo "  / dnf install lftp / pacman -S lftp)." >&2
    return 1
  fi

  check_preflight "$_main_force"

  if [ ! -d ./_site ]; then
    echo "deploy: ./_site does not exist. Run 'make build' first." >&2
    return 1
  fi

  _main_ssh_host="${CRIMSONGLOW_SSH_HOST:-crimsonglow}"
  _main_docroot="${CRIMSONGLOW_DOCROOT:-www/www}"

  validate_ssh_host "$_main_ssh_host"

  # --- transfer -------------------------------------------------------------

  echo "deploy: mirroring ./_site/ to $_main_ssh_host:$_main_docroot" >&2
  [ -n "$_main_dry_run" ] && echo "deploy: --dry-run, nothing will actually transfer" >&2
  [ -n "$_main_delete" ] && echo "deploy: --delete is on -- remote-only files will be removed" >&2

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
    open sftp://$_main_ssh_host;
    mirror --reverse --verbose --parallel=4 $_main_dry_run $_main_delete \
      --exclude-glob .well-known/ \
      ./_site/ \"$_main_docroot\";
  "
}

main "$@"

