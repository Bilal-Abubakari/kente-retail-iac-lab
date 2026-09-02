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

### 2.4 Installing Ansible into WSL automatically → deliberately not done
I could have `pip install ansible` in WSL to produce real encrypted vaults and run
`ansible-lint` here. Rejected: it modifies the operator's environment without
asking, and it would have put the vault password in my hands. The vault password
should be the operator's. Documented the WSL steps instead.

### 2.5 `force_destroy = true` on the state bucket → rejected (context differs from last lab)
In the previous lab the app S3 bucket used `force_destroy = true` to make teardown
clean. Copying that habit to the **state** bucket would be dangerous — a stray
`destroy` could wipe every environment's state history. Set `force_destroy = false`
here on purpose. *Same engineer, opposite correct answer, because the resource's
role is different.*

### 2.6 Committing the account-specific bucket name in the backend block → rejected
The backend needs a bucket name that carries the AWS account ID. Rather than commit
it, the `backend "s3"` block is a **partial config** and the account-specific
values go in a gitignored `backend.hcl` (with a committed `.example`). Keeps the
committed HCL account-agnostic.

### 2.7 Unused `vpc_id` input on the compute module → removed
The compute module declared and was passed `vpc_id` but never used it. Left in, it
invites a future reader to think there's a dependency there. Removed from both the
module and the call; the real edges (`subnet_id`, `security_group_id`) remain.

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
- Python: `generate_inventory.py` and `app.py` compile; all YAML parses.
- The value-add hook was **tested against real cases** (AWS key blocked, plaintext
  vault blocked, clean file passed) rather than assumed to work.
- Still requires live verification by the operator (needs AWS creds + WSL Ansible):
  the actual `apply` in both workspaces, the Ansible run, and idempotency (`changed=0`
  on a second run). Tracked in the README run-book.
