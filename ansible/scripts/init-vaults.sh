#!/usr/bin/env bash
# Creates the per-environment encrypted vault files from the committed .example
# templates. Run once, in WSL, after Ansible is installed.
#
# It will NOT overwrite a vault that already exists, and it fails if .vault_pass
# is missing — the vault password is yours to set and is never committed.
set -euo pipefail

cd "$(dirname "$0")/.."   # ansible/

if [[ ! -f .vault_pass ]]; then
  cat >&2 <<'MSG'
No .vault_pass file found. Create one first (it is gitignored):

    read -s -p "Vault password: " p && printf '%s' "$p" > .vault_pass && chmod 600 .vault_pass && echo

Then re-run this script.
MSG
  exit 1
fi

for env in dev staging; do
  example="group_vars/${env}/vault.yml.example"
  target="group_vars/${env}/vault.yml"

  if [[ -f "$target" ]]; then
    echo "= ${target} already exists — leaving it alone"
    continue
  fi

  # Generate a strong, environment-distinct password and write a real vault.
  pw="$(openssl rand -base64 24)"
  printf -- '---\nvault_db_password: "%s"\n' "$pw" > "$target"
  ansible-vault encrypt "$target" >/dev/null
  echo "+ wrote and encrypted ${target} (unique password generated)"
done

echo
echo "Done. The encrypted vault files are safe to commit; .vault_pass is not."
