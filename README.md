# Kente Retail — Web Tier (last sprint's Terraform)

This is the Terraform code from the Infrastructure as Code module, as it was left at
the end of last sprint: one environment, one AWS account, state on whoever's laptop
last ran `terraform apply`.

## What's here

- `main.tf` — provider and required-version configuration. No `backend` block —
  state is local (`terraform.tfstate` next to these files), which is exactly the
  problem this module's lab asks you to fix.
- `variables.tf` — the knobs this config exposes today. Nothing here is workspace-aware
  yet.
- `networking.tf` / `compute.tf` — the two pieces of infrastructure, already split into
  reusable-ish modules under `modules/`.
- `monitoring.tf` — a small CloudWatch log group, wired up before `networking.tf` was
  pulled into its own module.
- `outputs.tf` — root outputs.
- `modules/networking`, `modules/compute` — the module implementations.

## Running it (as-is, single environment)

```bash
terraform init
terraform plan
terraform apply
```

This provisions one VPC, one subnet, one security group, and one (or more) EC2
instance(s) running the Kente Retail order-service image, all in whatever AWS account
your default credentials point at.

## Your job this module

See the Learner Brief and `environment-requirements-spec.md` (in the parent
`resources/` folder) for what's actually being asked of you. In short: this code needs
to become reusable modules driven by Terraform workspaces (dev + staging, same code),
the state needs to move to a remote S3 + DynamoDB backend, and the web tier needs to be
configured end-to-end by an Ansible role fed from Terraform's outputs — no manual SSH
step left over.

Your copy of this code has one planted defect somewhere in it. Nothing about the defect
is described here — finding and explaining it is part of the assessment.
