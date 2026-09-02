terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Remote state on S3 with a DynamoDB lock. This replaces last sprint's
  # "state on whoever's laptop" setup and is what makes dev and staging safe to
  # run as a team.
  #
  # Partial configuration on purpose: the bucket name is account-specific
  # (it carries the account ID — see bootstrap/), so it is NOT committed here.
  # Supply it at init time:
  #   terraform init -backend-config=backend.hcl
  # See backend.hcl.example for the shape.
  #
  # Workspaces keep dev and staging state apart automatically: each workspace's
  # state lands under env:/<workspace>/<key> in the same bucket, so the two
  # never overwrite each other.
  backend "s3" {
    key     = "kente-retail/web-tier.tfstate"
    encrypt = true
  }
}

provider "aws" {
  region = var.aws_region

  # Every resource created by this config (and its modules) is tagged from here,
  # so the Project/Environment pair can never drift out of sync between modules
  # or be forgotten on a new resource. Environment is the workspace name, which
  # is what makes the same code produce correctly-labelled dev and staging
  # resources. This satisfies the spec's tagging requirement in one place.
  default_tags {
    tags = {
      Project     = var.project_tag
      Environment = terraform.workspace
      ManagedBy   = "terraform"
    }
  }
}
