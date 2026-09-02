# Assumptions Log

Every place the spec left a gap, or where I had to decide something it did not
pin down, with the reasoning I would defend out loud.

## Decisions the spec explicitly left to me

### A-sizing — dev and staging are sized *differently*
The requirements spec (§3) says whether staging should be sized up is my call, as
long as I wire it through a variable and justify it.

**Decision:** dev = `t3.micro`, staging = `t3.small`, both a single instance.

**Why:** the whole point of a staging environment is to catch what dev cannot. A
`t3.micro` has 1 GiB RAM and a small CPU-credit balance; behaviour that only
appears with more memory headroom or under sustained CPU (GC pauses, credit
exhaustion, connection-pool sizing) will never surface on dev if dev is a micro.
Sizing staging one step up lets it behave more like production *before* a change
is promoted, which is exactly the risk this two-environment setup exists to
reduce. The cost delta is about **one US cent per hour** (see the executive
summary) — a trivial price for that signal.

**The counter-argument I considered and rejected:** identical sizing gives
"environment parity", so staging is a faithful mirror of dev. That is the right
instinct for staging-vs-*production* (you want those identical), but dev is a
scratch environment, not production. Parity that matters is staging↔production,
and production is out of scope for this pass. If production is added later,
staging's type should be pinned to match *it*, not dev.

**How it is wired:** `locals.tf > env_config` holds one map entry per
environment; `instance_type` and `instance_count` are read from
`env_config[terraform.workspace]`. There is exactly one `aws_instance` block (in
`modules/compute`); nothing is duplicated.

### A-cidr — VPC CIDR scheme
Spec §2 says pick a non-overlapping scheme and note it.

- dev → `10.10.0.0/16`
- staging → `10.20.0.0/16`

Each is a `/16` (65k addresses — vastly more than a one-subnet lab needs, but
cheap and leaves room). They do not overlap, so if the two VPCs are ever peered
for a migration test there is no collision. The single public subnet in each is
`cidrsubnet(vpc_cidr, 4, 0)` → a `/20` at the front of the range.

### A-secrets-layout — one vault file per environment
Spec §6 leaves the vault organisation to me. I chose **one vault file per
environment** (`group_vars/dev/vault.yml`, `group_vars/staging/vault.yml`) rather
than a single shared vault.

**Why:** blast radius. dev and staging get *independently generated* DB
passwords, so a leaked or rotated dev credential has no bearing on staging. A
single shared vault would put both environments' secrets behind one file and
tempt a single shared password. Per-environment files also line up naturally with
`group_vars/<env>/`, so Ansible loads the right secret for the right hosts with no
extra wiring.

## Gaps I filled that the spec did not specify

### A-remote — the state backend's *own* state is local, on purpose
Spec §4 says state must be remote. The one resource whose state cannot be remote
is the state bucket itself — it cannot store its own state inside the bucket it is
creating. The `bootstrap/` config that creates the S3 bucket + DynamoDB table
therefore keeps **its** state local. This is the single, deliberate exception, and
it is low-risk: bootstrap provisions two long-lived resources that change almost
never. Everything the day-to-day config touches is remote.

I assumed I should create the backend myself rather than expect a pre-provisioned
one — spec §4 says to check with the instructor first. In a real engagement I
would ask; for this solo sandbox I built it, and the bootstrap README documents
how to skip it if a shared bucket already exists.

### A-keypair — one SSH key pair, reused across environments
Terraform registers the operator's SSH *public* key as an EC2 key pair
(`aws_key_pair`), named per-workspace so the resources don't collide, but pointing
at the same public key. So a single private key on the operator's machine reaches
both environments. For a solo lab that is fine and keeps the private key count at
one. In a team/production setting each environment would get distinct keys (or,
better, SSM Session Manager and no SSH keys at all) — noted as a follow-up.

### A-appport — Terraform and Ansible share the app port by convention
`app_port` is a Terraform variable (opens the security group) *and* an Ansible
group_var (configures the service). They must agree. They are both 8080 and each
file notes the coupling. In a larger system this single value would come from one
source of truth handed across the Terraform→Ansible boundary; for this size,
documented duplication of one integer is the pragmatic call.

## Clarifying questions I would put to the CTO in a real engagement

1. **Is there a real production environment coming?** It changes the sizing answer
   (staging should mirror production, not be picked in a vacuum) and whether I
   should design the workspace/promotion flow for three tiers now.
2. **Who owns the AWS account boundary?** dev and staging share one account here.
   Many orgs separate environments by account for hard blast-radius isolation. If
   that is the direction, the backend and tagging strategy change.
3. **What is the real order-service?** I shipped a stand-in that proves the
   pipeline (build → configure → serve, with a Vault-delivered credential). The
   role's `tasks/main.yml` is where the real deployment steps would slot in.
4. **Where does Ansible run in the real workflow** — a laptop, or a CI runner?
   That decides what goes in `allowed_ssh_cidr` and whether SSH should be replaced
   by SSM.
5. **What is the secret rotation policy?** Right now rotation means re-running
   `ansible-vault` and re-applying. If secrets rotate often, this should move to a
   dynamic secrets store (Vault server / AWS Secrets Manager).

## Explicitly out of scope for this pass (spec §9), noted not built

TLS/certificates, autoscaling, a load balancer, multi-AZ + private subnets + NAT,
and CI/CD automation of `terraform apply`. Each is a sensible next step; none is
required or built here. The most valuable next one is probably **multi-AZ with
private subnets**, because the current single public subnet puts the web tier
directly on the internet with a public IP — acceptable for a lab, not for
production.
