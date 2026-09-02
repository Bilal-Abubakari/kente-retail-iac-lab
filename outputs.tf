output "environment" {
  description = "The workspace/environment these outputs belong to."
  value       = terraform.workspace
}

output "vpc_id" {
  description = "ID of the VPC this environment provisioned."
  value       = module.networking.vpc_id
}

output "subnet_id" {
  description = "ID of the public subnet this environment provisioned."
  value       = module.networking.subnet_id
}

output "security_group_id" {
  description = "ID of the web-tier security group."
  value       = module.networking.security_group_id
}

output "web_public_ips" {
  description = "Public IP addresses of the web-tier instance(s), for handing off to Ansible."
  value       = module.compute.public_ips
}

output "web_instance_ids" {
  description = "EC2 instance IDs of the web-tier instance(s)."
  value       = module.compute.instance_ids
}

output "ssh_key_name" {
  description = "Name of the EC2 key pair Ansible should use."
  value       = module.compute.key_name
}

output "app_port" {
  description = "Port the order-service listens on — Ansible reads this to configure the service and health check."
  value       = var.app_port
}

output "app_urls" {
  description = "Reachable URL(s) for the order-service once Ansible has configured it."
  value       = [for ip in module.compute.public_ips : "http://${ip}:${var.app_port}"]
}

# Consolidated blob the Ansible inventory generator consumes in one read.
output "ansible_inventory" {
  description = "Everything the inventory generator needs: env name, host IPs, SSH user, key, and app port."
  value = {
    environment = terraform.workspace
    app_port    = var.app_port
    ssh_user    = "ec2-user" # AL2023 default login
    key_name    = module.compute.key_name
    hosts       = module.compute.public_ips
  }
}
