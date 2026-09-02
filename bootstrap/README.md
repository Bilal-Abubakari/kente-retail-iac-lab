# Backend bootstrap

Creates the two resources the main config's S3 backend depends on, so they exist
*before* the first `terraform init` up one level:

- an S3 bucket for state — versioned (so a bad apply can be rolled back),
  encrypted at rest, and fully blocked from public access;
- a DynamoDB table for the state lock — the thing that makes a second concurrent
  `apply` wait instead of corrupting state.

## Why this is a separate config with local state

You cannot keep the state bucket's own state *inside the bucket it is creating*.
This config therefore keeps its state local — the single, deliberate exception to
the "no state on a laptop" rule, justified in `../docs/ASSUMPTIONS.md` (A-remote).
It provisions two long-lived resources that change almost never.

## Run it once

```bash
cd bootstrap
terraform init
terraform apply
```

Then take the `backend_block` output and confirm it matches the `backend "s3"`
block already committed in `../main.tf` (bucket name is account-specific, so if
yours differs, update the block, or pass the values with `-backend-config` at
`init` time so no account-specific value is committed).

> If your instructor has already provisioned a shared bucket and lock table, skip
> this directory entirely and point the backend block at the names they gave you.
> The spec explicitly allows either path.

## Do not `terraform destroy` this casually

The bucket holds the state history of *both* environments. `force_destroy` is
deliberately `false`, so Terraform will refuse to delete a non-empty bucket —
tearing the backend down is a manual, last-step act after both workspaces are
already destroyed.
