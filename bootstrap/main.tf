# Backend bootstrap — run this ONCE, before the main config's remote backend
# can be used. It provisions the two pieces of shared infrastructure the S3
# backend needs: a versioned, encrypted bucket to hold state, and a DynamoDB
# table to hold the lock.
#
# This config keeps its own state LOCAL on purpose. It is the one exception to
# "state lives remotely": you cannot store the state bucket's own state inside
# the bucket it is busy creating (chicken and egg). It creates two long-lived,
# rarely-changed resources, so a local state file for it is acceptable and is
# documented in the Assumptions Log.

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = var.project_tag
      Component = "tf-remote-backend"
      ManagedBy = "terraform"
    }
  }
}

data "aws_caller_identity" "current" {}

locals {
  # Bucket names are globally unique across all AWS accounts, so the account ID
  # is appended to avoid collisions with other learners in the same course.
  bucket_name = "${var.project_tag}-tfstate-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket" "state" {
  bucket = local.bucket_name

  # State buckets are meant to be durable. force_destroy stays false so that a
  # stray `terraform destroy` here can never silently delete every environment's
  # state history. Teardown of this bucket is a deliberate, manual act.
  force_destroy = false
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_ownership_controls" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket = aws_s3_bucket.state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "lock" {
  name         = "${var.project_tag}-tflock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}
