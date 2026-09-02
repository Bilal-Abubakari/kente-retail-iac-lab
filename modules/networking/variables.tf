variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
}

variable "allowed_ssh_cidr" {
  description = "CIDR permitted to SSH in (port 22)."
  type        = string
}

variable "allowed_app_cidr" {
  description = "CIDR permitted to reach the application port."
  type        = string
}

variable "app_port" {
  description = "TCP port the order-service listens on."
  type        = number
}
