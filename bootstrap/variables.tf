variable "aws_region" {
  description = "Region the state bucket and lock table live in. Must match the region in the main config's backend block."
  type        = string
  default     = "eu-west-1"
}

variable "project_tag" {
  description = "Project prefix, reused in the bucket and table names and the Project tag."
  type        = string
  default     = "kente-retail"
}
