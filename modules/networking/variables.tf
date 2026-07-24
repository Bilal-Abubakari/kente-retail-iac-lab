variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
}

variable "project_tag" {
  description = "Value for the Project tag on every resource this module creates."
  type        = string
}
