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
  description = "Prefix used for the Name tag and key-pair name (a number is appended to the Name when instance_count > 1)."
  type        = string
}

variable "public_key_path" {
  description = "Path to the SSH public key to register for Ansible access."
  type        = string
}
