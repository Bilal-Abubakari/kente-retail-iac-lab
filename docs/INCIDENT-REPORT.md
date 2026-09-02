# Incident Report

Two parts: (1) the **seeded defect** that shipped in the starter, found and fixed;
(2) the **Day-2 state incident** — a prepared runbook, with the live write-up to be
completed during the walkthrough.

---

## Part 1 — Seeded dependency defect (found & fixed)

### Summary
The starter tagged the CloudWatch log group in `monitoring.tf` with a `VpcId`
read from a **stale, checked-in state file** rather than from the live VPC. The
tag would have carried a phantom VPC ID (`vpc-0legacy0000000001`) that belongs to
no running environment — and, because the value was a hard-coded constant, the
**same** wrong ID on both dev and staging.

### Root cause
```hcl
# starter monitoring.tf
data "terraform_remote_state" "networking" {
  backend = "local"
  config  = { path = "${path.module}/legacy-networking-state/terraform.tfstate" }
}
resource "aws_cloudwatch_log_group" "app" {
  tags = { VpcId = data.terraform_remote_state.networking.outputs.vpc_id }
}
```
The `.gitignore` had even been specially edited to force that dead state file to
be tracked (commit *"Fix .gitignore to actually keep legacy-networking-state's
tfstate tracked"*). So the log group depended on a **snapshot of the past** — a
frozen output baked into a file — instead of on the VPC this run actually builds.
Nothing errors; you just get infrastructure silently mislabelled, and a
monitoring resource that has *no real dependency* on the VPC it claims to describe.

### The teaching point the criteria asks for — where an implicit reference silently handled ordering correctly
Everywhere *else*, ordering was handled correctly and invisibly by **implicit
references**. `compute.tf` passes `module.networking.subnet_id` and
`security_group_id` into the compute module. Terraform reads those references,
adds edges to its dependency graph, and builds networking before compute — with
no `depends_on` needed. (The starter even had a redundant
`depends_on = [module.networking]` on compute; I removed it, because the passed
outputs already create the edge. It's the corrected counter-example.)

The defect is precisely the *absence* of that implicit link: the log group should
reference the live VPC the same way, and by not doing so it lost both the correct
value **and** the correct ordering.

### Fix
```hcl
# fixed monitoring.tf
resource "aws_cloudwatch_log_group" "app" {
  tags = { VpcId = module.networking.vpc_id }   # implicit ref -> live VPC, per workspace
}
```
Plus: deleted `legacy-networking-state/terraform.tfstate` and removed its
`.gitignore` exception. Now Terraform orders the VPC before the log group on its
own, and the tag is this workspace's real VPC — correct for both dev and staging.

### Why it matters beyond a wrong tag
A checked-in `.tfstate` is also a data-exposure risk (state files carry resource
attributes, sometimes secrets). The defect quietly normalised committing state to
git — the exact habit the rest of this lab exists to break.

---

## Part 2 — Day-2 state incident (prepared runbook)

> The brief says something will go wrong with the shared state during the
> walkthrough — most likely a **lock conflict** (a second apply while one holds the
> lock), a **stuck lock** (an apply that died without releasing), or a **manual
> state edit / corruption**. The steps below are prepared in advance; the
> "What happened" boxes are filled in live.

### Step 0 — Do NOT reach for the destructive fix first
The tempting buttons are `terraform force-unlock <id>` and hand-editing state.
Both can turn a recoverable situation into a corrupted one. Diagnose before acting.

### Step 1 — Read the lock, identify the holder
A lock conflict prints the lock ID, who holds it, the operation, and when it
started (from the DynamoDB lock record). First question: **is that other operation
still running?** A live `apply` mid-flight must be allowed to finish — unlocking it
is how you corrupt state. Only a lock whose process is genuinely dead is a stuck
lock.

### Step 2 — If genuinely stuck, force-unlock with the exact ID
Only once the holding process is confirmed dead:
```
terraform force-unlock <LOCK_ID>
```
Using the specific ID (not a blanket unlock) is deliberate — it refuses if the ID
doesn't match, which is one last guard against unlocking the wrong operation.

### Step 3 — If state looks wrong, prefer S3 versioning over hand-editing
The state bucket has **versioning enabled** (built in `bootstrap/`). A bad apply or
a fat-fingered manual edit is recovered by rolling the S3 object back to the prior
version — not by editing JSON by hand. Hand-editing state is the last resort, and
only via `terraform state` subcommands, never a text editor.

### Step 4 — Reconcile and prove clean
After recovery, run `terraform plan`. Drift shows as a diff; a clean plan
("No changes") is the proof the environment matches code again. For a suspected
out-of-band change, `terraform plan -refresh-only` shows what reality did without
conflating it with pending code changes.

### Step 5 — Write it up (below), including what you deliberately did NOT do
The half-page the brief asks for. The "did not do" line is the point: it shows you
understood the failure rather than flailing at it.

---

### Live write-up (the incident, as it actually happened)

- **What happened:** A **lock conflict** on the shared `staging` state. Two
  `terraform apply` operations ran against the same workspace at once; the first
  acquired the DynamoDB lock, so the second was correctly refused.
- **How it surfaced (exact error / symptom):**
  ```
  Error: Error acquiring the state lock
  Error message: operation error DynamoDB: PutItem, ...
    ConditionalCheckFailedException: The conditional request failed
  Lock Info:
    ID:        cbc9ed8a-1b17-d301-7d90-b2d1add68a2c
    Path:      kente-retail-tfstate-<ACCOUNT_ID>/env:/staging/kente-retail/web-tier.tfstate
    Operation: OperationTypeApply
    Who:       AzureAD\<redacted-user>@<redacted-host>
    Created:   2026-09-02 10:51:29 UTC
  ```
  The `ConditionalCheckFailedException` is the lock working exactly as designed:
  the lock row already existed, so DynamoDB's conditional `PutItem` refused a
  second writer.
- **What I did, in order:** (1) Read the lock record — it named a live
  `OperationTypeApply` started seconds earlier by my own second session. (2) Asked
  the one question that matters: *is the holder still running?* It was. (3) Let the
  holding apply run to completion so it released the lock cleanly. (4) Re-ran
  `terraform plan`, which acquired the now-free lock and reported **"No changes."**
- **What I deliberately did NOT do, and why:** I did **not** `terraform
  force-unlock cbc9ed8a-...`. The lock was held by an apply that was *still
  running*; force-unlocking a live apply is precisely how you corrupt shared
  state. Force-unlock is only for a lock whose process is genuinely dead. I also
  did not add `-lock=false` to "make it go away" — that disables the very safety
  that was doing its job.
- **How I proved the environment was healthy again:** `terraform plan` against
  `staging` returned *"No changes. Your infrastructure matches the configuration."*
  — a clean plan is the proof state and reality agree. (Had state looked wrong, the
  next resort was rolling the S3 object back to its prior version — the bucket is
  versioned — never a hand-edit of the JSON.)
- **Prevention / follow-up:** The lock did its job, so no fix was needed. Going
  forward: don't run two applies on one workspace; the value-add promotion script
  (Proposal 2) serialises staging changes behind an explicit gate. Note also that
  Terraform 1.10+ offers S3-native locking (`use_lockfile`), which would let us
  retire the DynamoDB table entirely — deliberately kept here because the brief
  specifies an S3 **+ DynamoDB** backend.
