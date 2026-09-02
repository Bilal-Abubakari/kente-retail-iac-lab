variable "aws_region" {
  description = "AWS region to deploy into. Must match the region of the remote state backend."
  type        = string
  default     = "eu-west-1"
}

variable "project_tag" {
  description = "Value used for the Project tag on every resource (applied via provider default_tags)."
  type        = string
  default     = "kente-retail"
}

# --- Access control ----------------------------------------------------------
# The web tier must be reachable on its app port from the class network, and
# over SSH from wherever Ansible runs. These are the two CIDRs that control that.

variable "allowed_ssh_cidr" {
  description = "CIDR permitted to SSH in (port 22) — the machine Ansible runs from. Never 0.0.0.0/0."
  type        = string

  validation {
    condition     = can(cidrhost(var.allowed_ssh_cidr, 0))
    error_message = "allowed_ssh_cidr must be valid IPv4 CIDR, e.g. 41.210.10.5/32."
  }

  validation {
    condition     = var.allowed_ssh_cidr != "0.0.0.0/0"
    error_message = "allowed_ssh_cidr must not be 0.0.0.0/0. SSH open to the whole internet is the misconfiguration this lab is meant to fix — use your own /32."
  }
}

variable "allowed_app_cidr" {
  description = "CIDR permitted to reach the application port — the class network. Defaults to open for the demo; tighten to the campus range in a real deployment."
  type        = string
  default     = "0.0.0.0/0"

  validation {
    condition     = can(cidrhost(var.allowed_app_cidr, 0))
    error_message = "allowed_app_cidr must be valid IPv4 CIDR."
  }
}

variable "app_port" {
  description = "TCP port the Kente Retail order-service listens on. Ansible configures the service to match."
  type        = number
  default     = 8080

  validation {
    condition     = var.app_port > 0 && var.app_port <= 65535
    error_message = "app_port must be between 1 and 65535."
  }
}

variable "public_key_path" {
  description = "Path to the SSH PUBLIC key to register as the EC2 key pair for Ansible access. The matching private key stays on your machine and is never committed. Generate with: ssh-keygen -t ed25519 -f ~/.ssh/kente_lab."
  type        = string
  default     = "~/.ssh/kente_lab.pub"
}
