# Executive Summary — Two Environments, One Codebase

**To:** Kente Retail CTO **From:** Bilal Abubakari **Re:** dev + staging on one
Terraform codebase, configured by Ansible, state secured remotely.

## What was delivered

Last sprint's single-environment Terraform — state on a laptop, one environment,
manual server tweaks — is now **two environments (dev and staging) built from one
set of modules**, their state held in a shared, locked, encrypted S3 backend, and
every server configured end-to-end by Ansible with no manual SSH step. The
database credential that leaked last sprint is now encrypted with Ansible Vault
and cannot be committed in plaintext, enforced automatically.

## Cost estimate (eu-west-1, on-demand list prices)

| Item | Rate | dev | staging |
|---|---|---|---|
| EC2 instance | t3.micro $0.0120/hr · t3.small $0.0240/hr | $0.0120/hr | $0.0240/hr |
| Public IPv4 (1 per host) | $0.005/hr | $0.0050/hr | $0.0050/hr |
| EBS gp3 root, 8 GiB | $0.088/GiB-month | ~$0.0010/hr | ~$0.0010/hr |
| VPC, subnet, IGW, route table, SG | free | $0 | $0 |
| S3 state + DynamoDB lock + CloudWatch | usage-based, few KB / few requests | negligible (shared) | |

- **Both environments running: ≈ $0.046 per hour.**
- **A typical 8-hour lab session (build → demo → destroy): ≈ $0.37.**
- **If left running a full month (730 h): ≈ $34** — which is the entire financial
  case for the teardown discipline in §8 of the spec. The cost of the lab is not
  the build; it is *forgetting to destroy it*.

Notable finding: on these tiny instances the **public IPv4 charge is ~30% of the
per-host bill**. Moving the web tier to private subnets behind a NAT/ALB (out of
scope now) would change the cost shape, not just the security posture.

## Workspace design — how "same code, two environments" works

One code path, one copy of every resource block. The only thing that varies
between dev and staging is a lookup in `locals.tf`:

```
env_config = {
  dev     = { vpc_cidr = "10.10.0.0/16", instance_type = "t3.micro", ... }
  staging = { vpc_cidr = "10.20.0.0/16", instance_type = "t3.small", ... }
}
cfg = env_config[terraform.workspace]
```

`terraform.workspace` selects the row. `terraform workspace select dev && apply`
builds dev; the same against `staging` builds staging. A guard (`terraform_data`
precondition) refuses to run in the unconfigured `default` workspace, so you can
never accidentally apply a half-configured environment. Resource **names** carry
the workspace (`kente-vpc-dev`, `kente-vpc-staging`) so the two never collide, and
**tags** (`Project`, `Environment`) are applied once via provider `default_tags`
so nothing can be left untagged.

Adding a third environment later is one map entry — not a second copy of the code.

## The locking conflict, in plain terms

State now lives in S3, with a **DynamoDB lock table** in front of it. When anyone
runs `plan` or `apply`, Terraform first writes a lock record to DynamoDB. If a
second person (or a CI job) starts an `apply` while the first still holds the lock,
the second does not read stale state and does not corrupt it — it is **refused**,
with the ID and identity of whoever holds the lock:

```
Error: Error acquiring the state lock ... ConditionalCheckFailedException
Lock Info: ID: 7f3c... , Who: bilal@... , Created: ...
```

The second operator waits, or the lock is investigated. This is the difference
between "state on a laptop" (two applies silently overwrite each other and one
person's changes vanish) and a backend safe for a team. Recovering from a *stuck*
lock, and why you must diagnose rather than blindly `force-unlock`, is covered in
the incident report.

## Secrets — plaintext confirmation

There is **no plaintext secret anywhere in the repository or its history.** The
only real secret (the per-environment DB password) exists as: the vault password
in the operator's head, an AES256-encrypted `group_vars/*/vault.yml` at rest, and
a mode-0640 file on the instance at run time (delivered with `no_log`). This is
enforced, not just intended — the committed **pre-commit hook blocks any commit**
that contains an AWS key, a private key, or a `vault.yml` that isn't encrypted.
That hook is the value-add feature, chosen because it closes the exact hole that
caused last sprint's incident.

## Bottom line

Kente Retail can now stand up matching-but-independent environments from one
reviewed codebase, run them side by side for pennies an hour, tear them down on a
schedule, and cannot leak a credential to git by accident. The remaining
recommended step is private-subnet networking for the web tier before anything
resembling production traffic.
