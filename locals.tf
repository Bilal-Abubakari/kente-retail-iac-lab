# Single source of truth for everything that differs between dev and staging.
#
# This is the mechanism that satisfies "both environments, same code": there is
# exactly one copy of every resource block (in the modules), and the ONLY things
# that vary between environments are the values looked up here by workspace name.
# Adding a third environment later means adding one map entry, not copying code.

locals {
  env_config = {
    dev = {
      vpc_cidr       = "10.10.0.0/16"
      instance_type  = "t3.micro"
      instance_count = 1
    }
    staging = {
      # Staging is sized up to sit closer to production load, so that anything
      # that only shows up under a larger instance (memory headroom, CPU credit
      # behaviour) surfaces in staging before promotion rather than in prod.
      # Justified in docs/ASSUMPTIONS.md (A-sizing).
      vpc_cidr       = "10.20.0.0/16"
      instance_type  = "t3.small"
      instance_count = 1
    }
  }

  # Fail loudly and early if someone runs in an unconfigured workspace (e.g. the
  # accidental "default" workspace), instead of silently building with fallback
  # values that belong to neither environment.
  known_workspace = contains(keys(local.env_config), terraform.workspace)

  cfg = local.known_workspace ? local.env_config[terraform.workspace] : local.env_config["dev"]
}

# Turns the "unknown workspace" case into a clear plan-time error rather than a
# confusing apply against fallback values. terraform_data is the built-in,
# provider-free resource for hanging an assertion off of; it has no cloud
# footprint. The precondition runs during plan, so an un-configured workspace
# fails before anything is created.
resource "terraform_data" "workspace_guard" {
  input = terraform.workspace

  lifecycle {
    precondition {
      condition     = local.known_workspace
      error_message = "Workspace '${terraform.workspace}' is not configured. Run 'terraform workspace select dev' (or staging) — never apply in the default workspace. See locals.tf env_config."
    }
  }
}
