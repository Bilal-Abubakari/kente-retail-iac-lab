# Source this in WSL before running any Ansible command from the Windows mount:
#
#     source scripts/wsl-env.sh
#
# Why this exists: the repo lives on /mnt/c, which WSL exposes world-writable
# (every file mode 0777). For security, Ansible REFUSES to load ansible.cfg from
# a world-writable directory — even when pointed at it explicitly with
# ANSIBLE_CONFIG. So ansible.cfg (which is still the committed source of truth
# for these settings) won't take effect here.
#
# ANSIBLE_* environment variables, by contrast, are always honored and bypass
# config-file loading entirely. This script sets the same values ansible.cfg
# declares, so the live run behaves identically to a native-filesystem checkout.
# It changes nothing on disk and is safe to source repeatedly.

_ansible_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"

export ANSIBLE_INVENTORY="${_ansible_dir}/inventory/hosts.generated.ini"
export ANSIBLE_ROLES_PATH="${_ansible_dir}/roles"
# Vault password lives in your home dir (ext4, 0600) — never on the repo/mount.
export ANSIBLE_VAULT_PASSWORD_FILE="${ANSIBLE_VAULT_PASSWORD_FILE:-$HOME/.kente_vault_pass}"
export ANSIBLE_HOST_KEY_CHECKING=False
export ANSIBLE_RETRY_FILES_ENABLED=False
export ANSIBLE_INTERPRETER_PYTHON=auto_silent
# YAML-formatted output is now an option on the built-in default callback
# (community.general.yaml was removed in newer ansible-core).
export ANSIBLE_STDOUT_CALLBACK=default
export ANSIBLE_CALLBACK_RESULT_FORMAT=yaml
export ANSIBLE_PIPELINING=True
export ANSIBLE_SSH_RETRIES=5

unset _ansible_dir
echo "Ansible env loaded (vault pass: ${ANSIBLE_VAULT_PASSWORD_FILE}, inventory: ${ANSIBLE_INVENTORY})"
