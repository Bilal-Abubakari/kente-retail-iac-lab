# Kente Retail — Two Environments, One Codebase

dev and staging, built from **one** set of Terraform modules via workspaces,
state held in a remote **S3 + DynamoDB** backend, and every server configured
end-to-end by **Ansible** (with a **Vault**-managed DB credential). This is last
sprint's single-environment code, refactored to the `environment-requirements-spec.md`.

## Deliverables index

| Document | Contents |
|---|---|
| [`docs/EXECUTIVE-SUMMARY.md`](docs/EXECUTIVE-SUMMARY.md) | Cost estimate, workspace design, the locking-conflict explanation, no-plaintext-secret confirmation |
| [`docs/CDK-COMPARISON-MEMO.md`](docs/CDK-COMPARISON-MEMO.md) | When AWS CDK would beat Terraform *for this client* |
| [`docs/ASSUMPTIONS.md`](docs/ASSUMPTIONS.md) | Sizing call, CIDR scheme, vault layout, gaps filled, questions for the CTO |
| [`docs/INCIDENT-REPORT.md`](docs/INCIDENT-REPORT.md) | The seeded defect (found & fixed) + Day-2 state-incident runbook |
| [`docs/VALUE-ADD-PROPOSAL.md`](docs/VALUE-ADD-PROPOSAL.md) | Two proposals; the pre-commit secret guard is built |
| [`docs/AI-USAGE-LOG.md`](docs/AI-USAGE-LOG.md) | What AI produced, what was rejected/corrected and why |
| [`ansible/README.md`](ansible/README.md) | The Terraform→Ansible handoff, roles, Vault workflow |
| [`bootstrap/README.md`](bootstrap/README.md) | Creating the remote state backend |

## What changed from the starter (map for the walkthrough)

- **Workspaces**: `locals.tf` holds one `env_config` row per environment; the same
  modules build dev (`10.10.0.0/16`, t3.micro) and staging (`10.20.0.0/16`, t3.small).
- **Remote state**: `main.tf` has an S3 backend with DynamoDB locking; `bootstrap/`
  creates the bucket (versioned, encrypted) + lock table.
- **Seeded defect fixed**: `monitoring.tf` now takes `VpcId` from the live
  `module.networking.vpc_id` (implicit reference) instead of a checked-in dead
  state file, which has been removed. See the incident report.
- **Tagging**: `Project`/`Environment` via provider `default_tags`, once.
- **Security**: SSH locked to `allowed_ssh_cidr` (never 0.0.0.0/0), IMDSv2 required,
  encrypted root volume, no `user_data` (Ansible does all config).
- **Ansible**: one custom role (`order_service`), inventory generated from
  Terraform outputs, per-environment `group_vars`, Vault-encrypted DB passwords.
- **Value-add**: `scripts/pre-commit` blocks secrets and un-encrypted vaults.

## Run book

### 0. One-time: install the pre-commit guard and generate an SSH key
```bash
bash scripts/install-hooks.sh
ssh-keygen -t ed25519 -f ~/.ssh/kente_lab      # public key is what Terraform registers
```

### 1. Bootstrap the remote backend (once)
```bash
cd bootstrap && terraform init && terraform apply
terraform output backend_block        # copy values into ../backend.hcl
```

### 2. Build both environments from the same code
```bash
cd ..
cp backend.hcl.example backend.hcl    # fill in from step 1
terraform init -backend-config=backend.hcl

terraform workspace new dev      || terraform workspace select dev
terraform apply -var allowed_ssh_cidr="$(curl -s https://checkip.amazonaws.com)/32"

terraform workspace new staging  || terraform workspace select staging
terraform apply -var allowed_ssh_cidr="$(curl -s https://checkip.amazonaws.com)/32"
```

### 3. Configure the web tier with Ansible (in WSL — see `ansible/README.md`)
```bash
cd ansible
# one-time: pip install -r requirements.txt ; set .vault_pass ; bash scripts/init-vaults.sh
python3 inventory/generate_inventory.py
ansible-playbook site.yml
ansible-playbook site.yml            # second run proves idempotency (changed=0)
```

### 4. Verify
```bash
curl http://<dev-ip>:8080/           # {"environment":"dev", "db_credential_loaded":true}
curl http://<staging-ip>:8080/       # {"environment":"staging", ...}
```

### 5. Tear down BOTH environments before the deadline
```bash
cd ..
terraform workspace select dev     && terraform destroy
terraform workspace select staging && terraform destroy
# backend bucket/table are torn down last, manually (see bootstrap/README.md)
```

## Environment note

Terraform, AWS CLI and Python run on Windows. **Ansible does not run on native
Windows** — run all Ansible steps from WSL (Ubuntu). Full steps in `ansible/README.md`.
