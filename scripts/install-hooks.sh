#!/usr/bin/env bash
# Installs the pre-commit guard into this repo's .git/hooks.
# Uses a symlink so the hook stays in sync with the version-controlled script;
# falls back to a copy on filesystems that don't support symlinks (some Windows).
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
src="$repo_root/scripts/pre-commit"
dest="$repo_root/.git/hooks/pre-commit"

chmod +x "$src"
if ln -sf "$src" "$dest" 2>/dev/null; then
  echo "Installed pre-commit hook (symlink -> scripts/pre-commit)"
else
  cp "$src" "$dest" && chmod +x "$dest"
  echo "Installed pre-commit hook (copy). Re-run after editing scripts/pre-commit."
fi
