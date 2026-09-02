# AI Usage Log

This build was done with an AI assistant (Claude). The rubric rewards *thoughtful
rejection* of AI output over blind acceptance, so this log records where AI output
was corrected, rejected, or verified — not just where it was accepted.

> 🔲 **Bilal to complete before submission:** add your own prompts and, in §4, your
> honest "what I'd do differently". The entries below are the assistant's account
> of decisions made during the build; the marked spots are yours.

## 1. How AI was used
- Analysing the starter to locate and explain the planted defect.
- Drafting the Terraform refactor (workspaces, backend, `default_tags`, locals map).
- Writing the Ansible role, playbook, inventory generator, and Vault machinery.
- Drafting the written deliverables (this log, exec summary, CDK memo, etc.).

Everything was reviewed before being accepted; the corrections below are the ones
worth recording.

## 2. Rejections & corrections (the important part)

### 2.1 Deprecated `null_data_source` for the workspace guard → rejected
The first draft of the "refuse to run in the default workspace" guard used a
`null_data_source` with a `postcondition`. `null_data_source` is **deprecated**.
Replaced with the built-in `terraform_data` resource and a `precondition` — no
extra provider, and it's the modern idiom. *Lesson: AI reaches for familiar-but-
dated constructs; check provider status.*

### 2.2 Redundant `depends_on` — caught, and turned into the teaching point
The starter's `compute.tf` had `depends_on = [module.networking]`. It was
redundant: passing `module.networking.subnet_id`/`security_group_id` as inputs
already creates the dependency edge. Rather than leave it "because it's harmless",
I removed it and used it as the *corrected counter-example* to the seeded defect
(implicit references handle ordering; the defect failed to use one).

### 2.3 Fabricating encrypted vault files → refused
Ansible/`ansible-vault` is not installed on this machine (Windows) or in WSL. The
tempting shortcut was to hand-fabricate an `$ANSIBLE_VAULT` blob so the repo
"looked done". Rejected: a fake vault is worse than an honest un-encrypted-yet
template — it would fail to decrypt and hide the real state. Instead I shipped
`.example` templates + an `init-vaults.sh` script the operator runs in WSL, so the
**vault password stays with the operator** and never enters this transcript.

### 2.4 Installing Ansible into WSL → not done silently, done later on explicit ask
First pass: I did **not** auto-install Ansible, because installing tooling into the
operator's WSL and generating vaults would have put the vault password in my hands.
When the operator later explicitly authorised the install, I installed
`ansible-core` + `ansible-lint` in WSL and generated the real encrypted vaults —
but the vault password is a fresh `openssl rand -base64 24` that is **never printed
in this transcript**; it lives only in `~/.kente_vault_pass` (mode 0600) and can be
rotated at will. *Lesson: "don't touch the environment" is the right default; once
consent is given, the constraint that survives is "the secret stays with the
operator", so the password was machine-generated and never echoed.*

### 2.5 The `/mnt/c` world-writable + exec-bit traps → env vars, not a remount
Running Ansible from the repo on `/mnt/c` surfaced two WSL-specific failures:
(a) the mount is world-writable, so Ansible **refuses to load `ansible.cfg`** —
even when pointed at it with `ANSIBLE_CONFIG`; and (b) every file on `/mnt/c` is
mode 0777, so `ansible-vault` treats the password file as an **executable script**
("Exec format error"). The tempting fixes were invasive: edit `/etc/wsl.conf` to a
metadata mount and `wsl --shutdown`, or `chmod` the tree (which doesn't stick on
`/mnt/c`). Rejected both — they change the operator's whole WSL for one lab. Instead:
the vault password moved to `~/.kente_vault_pass` (native ext4, real 0600), and
`scripts/wsl-env.sh` exports the `ansible.cfg` settings as `ANSIBLE_*` env vars,
which are always honored. `ansible.cfg` stays committed as the source of truth.

### 2.6 ansible-lint production profile → conformed, didn't disable the rule
`ansible-lint` (production profile) flagged the role's variables under
`var-naming[no-role-prefix]`. The shortcut was a `.ansible-lint` that skips the
rule. Rejected: the rule is right — role vars share a global namespace and can
collide. Renamed every role-consumed variable to the `order_service_` prefix
(defaults, tasks, templates, group_vars) and fixed an invalid galaxy platform
version in `meta/main.yml`. Lint now reports **0 failures at the production
profile**. *Conforming to the idiom is more defensible than muting the check.*

### 2.7 `force_destroy = true` on the state bucket → rejected (context differs from last lab)
In the previous lab the app S3 bucket used `force_destroy = true` to make teardown
clean. Copying that habit to the **state** bucket would be dangerous — a stray
`destroy` could wipe every environment's state history. Set `force_destroy = false`
here on purpose. *Same engineer, opposite correct answer, because the resource's
role is different.*

### 2.8 Committing the account-specific bucket name in the backend block → rejected
The backend needs a bucket name that carries the AWS account ID. Rather than commit
it, the `backend "s3"` block is a **partial config** and the account-specific
values go in a gitignored `backend.hcl` (with a committed `.example`). Keeps the
committed HCL account-agnostic.

### 2.9 Unused `vpc_id` input on the compute module → removed
The compute module declared and was passed `vpc_id` but never used it. Left in, it
invites a future reader to think there's a dependency there. Removed from both the
module and the call; the real edges (`subnet_id`, `security_group_id`) remain.

### 2.10 Apostrophe in the security-group description → only `apply` caught it
`terraform validate` and `fmt` both passed, but the first live `apply` failed:
`InvalidParameterValue: Invalid security group description`. The description read
"…the app's HTTP port." and AWS's allowed character set for SG descriptions
**excludes the apostrophe**. Removed it. *Lesson the brief rewards: `validate` only
checks the config is well-formed; provider/API constraints surface at `apply`, so
"it validates" is not "it applies". Caught by actually running it, not by trust.*

### 2.11 `stdout_callback = yaml` → removed plugin, moved to the built-in option
The first live `ansible-playbook` run errored: the `community.general.yaml` stdout
callback **has been removed** (superseded by `result_format: yaml` on the built-in
`default` callback from ansible-core 2.13+). Switched `ansible.cfg` (and the
`ANSIBLE_*` mirror in `wsl-env.sh`) to `stdout_callback = default` +
`callback_result_format = yaml`. *Same failure mode as 2.1: AI reaches for a
familiar construct that has since been retired — verify against the installed
version, don't assume.*

## 3. Accepted with reasoning
- **Provider `default_tags`** for `Project`/`Environment` over per-resource tags:
  one source of truth, impossible to forget on a new resource, and
  `Environment = terraform.workspace` makes it workspace-correct automatically.
- **One vault file per environment** over a shared vault: independent blast radius
  (see Assumptions A-secrets-layout).
- **`env_config` map keyed by workspace** over per-workspace `.tfvars`: keeps the
  "same code, values vary" contract in one visible place and makes a 3rd
  environment a one-line change.

## 4. What I would do differently 🔲
> Bilal — your reflection here. Prompts that follow, e.g.: which parts did you have
> to push back on the AI hardest about? Where did reviewing its output teach you
> something about Terraform/Ansible you didn't know? If you were starting over,
> what would you build first?

- _______________________________________________________________
- _______________________________________________________________

## 5. Verification, not trust
- Terraform: `terraform validate` passes on both the bootstrap and main configs;
  `terraform fmt` clean.
- Ansible: `ansible-lint` passes at the **production** profile (0 failures) and
  `ansible-playbook site.yml --syntax-check` parses clean, both run in WSL against
  the real tree.
- Vault: the two per-environment `vault.yml` files are really `ansible-vault`
  encrypted (`$ANSIBLE_VAULT;1.1;AES256`) and were **decrypt-verified** with the
  home-dir password file; their plaintext DB passwords differ per environment.
- Python: `generate_inventory.py` and `app.py` compile; all YAML parses.
- The value-add hook was **tested against real cases** (AWS key blocked, plaintext
  vault blocked, clean file passed) rather than assumed to work.
- Still requires live verification by the operator (needs AWS creds): the actual
  `apply` in both workspaces, the Ansible run against the live hosts, and
  idempotency (`changed=0` on a second run). Tracked in the README run-book.
