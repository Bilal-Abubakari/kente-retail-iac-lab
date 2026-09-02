output "state_bucket" {
  description = "Name of the S3 bucket that holds remote state. Copy this into the backend block in ../main.tf."
  value       = aws_s3_bucket.state.id
}

output "lock_table" {
  description = "Name of the DynamoDB lock table. Copy this into the backend block in ../main.tf."
  value       = aws_dynamodb_table.lock.name
}

output "region" {
  description = "Region both live in — the backend block's region must match."
  value       = var.aws_region
}

output "backend_block" {
  description = "Ready-to-paste backend configuration for the main config."
  value       = <<-EOT
    backend "s3" {
      bucket         = "${aws_s3_bucket.state.id}"
      key            = "kente-retail/web-tier.tfstate"
      region         = "${var.aws_region}"
      dynamodb_table = "${aws_dynamodb_table.lock.name}"
      encrypt        = true
    }
  EOT
}
