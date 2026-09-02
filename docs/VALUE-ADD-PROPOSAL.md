# Value-Add Proposal

The brief asks for two workflow improvements pitched to the CTO; one is approved
and built. I built the first because it closes the exact hole that caused last
sprint's incident. The second is specified ready to build if preferred.

---

## Proposal 1 (BUILT) — Pre-commit guard against leaked secrets

### The pitch
The incident that started this engagement was a secret reaching git. Vault fixes
*where the secret lives*; it does nothing to stop a tired engineer from pasting an
AWS key into a `.tf` file or committing a vault before encrypting it. This proposal
adds a **git pre-commit hook** that inspects staged content and **blocks the commit**
if it finds:

- an AWS access key id or secret access key,
- private key material (`BEGIN … PRIVATE KEY`),
- a `vault.yml` that is not `ansible-vault`-encrypted,
- (and, when the tools are present) unformatted Terraform or `ansible-lint` failures.

### Why this one
- **Direct ROI on the actual incident.** It attacks the root cause — human error at
  commit time — not just the symptom. One prevented leak pays for it many times
  over: a leaked key means rotating credentials, auditing usage, and possibly
  disclosure. This is minutes of setup against hours-to-days of incident response.
- **Cheap and local.** Pure bash for the secret checks, no service, no CI
  dependency; it runs in the half-second before every commit.
- **Fails safe.** The secret and vault checks always run; only the
  formatter/linter steps skip when their tool is absent, and they never skip
  *silently* — they print that they skipped.

### Evidence it works
Verified against three staged cases: an AWS key → **blocked**; a plaintext
`vault.yml` → **blocked**; a clean Terraform file → **passed**. (Transcript kept
with the submission.) Install with `bash scripts/install-hooks.sh`; the hook is
`scripts/pre-commit`.

### Honest limitation
A pre-commit hook is a *local* guard and can be bypassed with `--no-verify`. It is
a fast first line, not enforcement. The natural next step is the same checks in CI
(where they can't be skipped) and a server-side secret scanner — noted below.

---

## Proposal 2 (SPECIFIED) — dev → staging promotion discipline

### The pitch
Right now nothing stops dev and staging drifting apart or a change landing in
staging without first proving out in dev. Add a lightweight **promotion process**:

- A single `promote` script/Make target that (a) confirms dev's `terraform plan`
  is clean, (b) shows the staging plan for review, (c) applies staging only on
  explicit confirmation — so staging is never changed except as a deliberate
  promotion of something already live in dev.
- Pin the image/artifact version in `env_config` so "what's in dev" and "what's in
  staging" are explicit values you promote by editing one map entry, reviewed in a
  PR.

### Why it's valuable but second
It improves *consistency and change safety*, which matters — but it doesn't stop a
credential leak, so on this client's risk profile (a fresh secrets incident) it
ranks behind Proposal 1. It's the natural follow-up once the leak guard is in
place, and it pairs well with moving Proposal 1's checks into CI.
