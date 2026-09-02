data "aws_ami" "app" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Registers the operator's SSH public key so Ansible can log in. Only the PUBLIC
# key is read here; the private key never touches Terraform state or the repo.
# The key is named per-workspace so dev and staging never collide.
resource "aws_key_pair" "web" {
  key_name   = "${var.name_prefix}-key"
  public_key = file(pathexpand(var.public_key_path))
}

resource "aws_instance" "web" {
  count = var.instance_count

  ami                    = data.aws_ami.app.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.security_group_id]
  key_name               = aws_key_pair.web.key_name

  # Enforce IMDSv2 so a request-forgery bug in the app can't be used to steal
  # instance credentials from the metadata endpoint.
  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = 8
    encrypted   = true
  }

  # NO user_data / bootstrap here on purpose. The spec requires the web tier to
  # be configured ENTIRELY by Ansible from Terraform's outputs — if Terraform
  # pre-installed the app, that line would be blurred. Terraform's job ends at a
  # reachable, SSH-able host; Ansible does all configuration.

  tags = {
    Name = var.instance_count > 1 ? "${var.name_prefix}-${count.index}" : var.name_prefix
  }
}
