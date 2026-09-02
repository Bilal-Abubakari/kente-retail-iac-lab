#!/usr/bin/env bash
# Creates the per-environment encrypted vault files from the committed .example
# templates. Run once, in WSL, after Ansible is installed.
#
# It will NOT overwrite a vault that already exists, and it fails if the vault
# password file is missing — the vault password is yours to set, lives in your
# home directory (never on the repo/Windows mount), and is never committed.
set -euo pipefail

cd "$(dirname "$0")/.."   # ansible/

# The password file must live on a native Linux FS (home), not the /mnt/c mount:
# on /mnt/c every file is mode 0777, and ansible-vault treats an *executable*
# password file as a script to run ("Exec format error"). Home (ext4) keeps 0600.
VAULT_PASS_FILE="${VAULT_PASS_FILE:-$HOME/.kente_vault_pass}"

# The repo lives on a world-writable mount, so Ansible refuses to load
# ./ansible.cfg (even via ANSIBLE_CONFIG). Pass the vault password by env var
# instead — env vars are always honored. See scripts/wsl-env.sh for the rest.
export ANSIBLE_VAULT_PASSWORD_FILE="$VAULT_PASS_FILE"

if [[ ! -f "$VAULT_PASS_FILE" ]]; then
  cat >&2 <<MSG
No vault password file found at ${VAULT_PASS_FILE}. Create one first:

    openssl rand -base64 24 > "${VAULT_PASS_FILE}" && chmod 600 "${VAULT_PASS_FILE}"

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
  # ANSIBLE_VAULT_PASSWORD_FILE (set above) already tells ansible-vault which
  # password to use; passing --vault-password-file too would create two
  # "default" vault-ids and error out.
  ansible-vault encrypt "$target" >/dev/null
  echo "+ wrote and encrypted ${target} (unique password generated)"
done

echo
echo "Done. The encrypted vault files are safe to commit; .vault_pass is not."
