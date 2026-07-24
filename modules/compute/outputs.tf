output "instance_ids" {
  description = "IDs of the web-tier instance(s)."
  value       = aws_instance.web[*].id
}

output "public_ips" {
  description = "Public IP addresses of the web-tier instance(s)."
  value       = aws_instance.web[*].public_ip
}
