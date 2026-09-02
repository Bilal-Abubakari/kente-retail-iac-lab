# CloudWatch log group for the web tier.
#
# PLANTED DEFECT (fixed) — see docs/INCIDENT-REPORT.md "Seeded defect" for the
# full write-up. The starter tagged this log group's VpcId by reading a stale,
# checked-in state file (legacy-networking-state/terraform.tfstate) through a
# terraform_remote_state data source. That value was a phantom VPC
# (vpc-0legacy0000000001) belonging to no live environment, and — worse in a
# workspace world — it was the SAME constant for both dev and staging, so both
# log groups would have been mislabelled with an identical wrong VPC.
#
# The fix is to reference the VPC the way everything else does: an IMPLICIT
# reference to module.networking.vpc_id. Terraform reads that reference, adds the
# edge to its dependency graph automatically, and creates the VPC before this log
# group without any depends_on. It is also per-workspace correct, because the
# module output resolves to this workspace's real VPC.
resource "aws_cloudwatch_log_group" "app" {
  name              = "/kente-retail/${terraform.workspace}/app"
  retention_in_days = 14

  # Project and Environment are applied by provider default_tags. VpcId is
  # specific to this resource, so it stays here — now sourced from the live
  # module output instead of a dead state file.
  tags = {
    VpcId = module.networking.vpc_id
  }
}
