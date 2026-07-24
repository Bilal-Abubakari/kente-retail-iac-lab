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
