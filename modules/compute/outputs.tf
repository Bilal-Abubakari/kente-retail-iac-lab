output "instance_ids" {
  description = "IDs of the web-tier instance(s)."
  value       = aws_instance.web[*].id
}

output "public_ips" {
  description = "Public IP addresses of the web-tier instance(s)."
  value       = aws_instance.web[*].public_ip
}

output "key_name" {
  description = "Name of the EC2 key pair registered for SSH access."
  value       = aws_key_pair.web.key_name
}
