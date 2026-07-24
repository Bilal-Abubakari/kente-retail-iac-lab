variable "vpc_id" {
  description = "VPC ID the web-tier instance(s) will run in."
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID the web-tier instance(s) will run in."
  type        = string
}

variable "security_group_id" {
  description = "Security group ID to attach to the web-tier instance(s)."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type."
  type        = string
}

variable "instance_count" {
  description = "Number of web-tier instances to create."
  type        = number
  default     = 1
}

variable "name_prefix" {
  description = "Prefix used for the Name tag on each instance (a number is appended when instance_count > 1)."
  type        = string
}

variable "project_tag" {
  description = "Value for the Project tag on every resource this module creates."
  type        = string
}

variable "key_name" {
  description = "Existing EC2 key pair name for SSH access. Leave empty to skip (no SSH key attached)."
  type        = string
  default     = ""
}
