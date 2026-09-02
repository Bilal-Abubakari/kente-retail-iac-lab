# Ansible — configuring the Kente Retail web tier

Terraform builds the hosts; **Ansible does all configuration**. No server is ever
hand-edited over SSH — that is the spec's hard line, and the reason there is no
`user_data` in the compute module.

## Layout

```
ansible.cfg                     # inventory path, vault password file, ssh settings
scripts/wsl-env.sh              # exports ansible.cfg's settings as ANSIBLE_* env vars
inventory/
  generate_inventory.py         # reads `terraform output` -> hosts.generated.ini
group_vars/
  all.yml                       # common to every host (ssh user, key, paths)
  dev/vars.yml                  # dev-specific non-secret config
  dev/vault.yml(.example)       # dev DB password, ENCRYPTED
  staging/vars.yml              # staging-specific non-secret config
  staging/vault.yml(.example)   # staging DB password, ENCRYPTED (different value)
roles/
  order_service/                # the one custom role (mandatory)
site.yml                        # the playbook
```

Why a **role** and not a flat playbook: the spec requires at least one custom
role, and it is the right call anyway — the order-service install is reusable and
self-contained (defaults, tasks, handlers, templates, a health check), so `site.yml`
stays a three-line statement of intent.

Why dev and staging differ **only in group_vars**: same role, same play. dev and
staging get different DB hosts/names/users (`group_vars/*/vars.yml`) and different,
independently-encrypted DB passwords (`group_vars/*/vault.yml`). No playbook logic
is copy-pasted.

## The `/mnt/c` wrinkle (read once)

The repo lives on the Windows drive, which WSL mounts **world-writable** (every
file mode 0777). For security, Ansible refuses to load `ansible.cfg` from a
world-writable directory — even if you point `ANSIBLE_CONFIG` straight at it. So
`ansible.cfg` is the committed source of truth for these settings, but on this
mount it won't take effect on its own. Two consequences, both handled:

- **Settings** — `source scripts/wsl-env.sh` first; it exports the same values
  as `ANSIBLE_*` env vars, which are always honored.
- **Vault password** — it lives at `~/.kente_vault_pass` (your home dir, real
  0600), not on the mount. On `/mnt/c` a file can't drop its exec bit, and
  `ansible-vault` would try to *run* an executable password file as a script.

## One-time setup (in WSL — Ansible does not run on native Windows)

```bash
# 1. Install the control-node tools
python3 -m venv ~/.venv/ansible && source ~/.venv/ansible/bin/activate
pip install -r requirements.txt

# 2. Create your vault password in your home dir (never committed, never on /mnt/c)
openssl rand -base64 24 > ~/.kente_vault_pass && chmod 600 ~/.kente_vault_pass

# 3. Create the encrypted per-environment vaults (unique password each)
bash scripts/init-vaults.sh
```

## Each run

```bash
# 0. Load the settings (world-writable mount means ansible.cfg won't auto-load)
source scripts/wsl-env.sh

# 1. Generate the inventory from live Terraform outputs (both environments)
python3 inventory/generate_inventory.py

# 2. Configure everything
ansible-playbook site.yml               # dev + staging
ansible-playbook site.yml --limit dev   # one environment

# 3. Verify idempotency — a second run must report changed=0
ansible-playbook site.yml
```

Confirm the app is serving with the environment baked in:

```bash
curl http://<public-ip>:8080/          # {"environment":"dev", "db_credential_loaded":true, ...}
```

The health page reports `db_credential_loaded: true` but never prints the
password — proof the secret was delivered without a way to leak it.

## Secrets

The DB password exists in exactly three states, none of them plaintext-in-repo:
the vault password in `~/.kente_vault_pass` (your home dir, gitignored and off
the Windows mount), the DB passwords encrypted at rest in `group_vars/*/vault.yml`,
and delivered at run time to `/etc/kente/order-service.env` on the box (mode 0640,
`no_log: true` so it never hits the Ansible log). The pre-commit hook refuses to
commit a `vault.yml` that isn't encrypted.
