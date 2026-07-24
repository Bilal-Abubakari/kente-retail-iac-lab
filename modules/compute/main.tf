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

resource "aws_instance" "web" {
  count = var.instance_count

  ami                    = data.aws_ami.app.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.security_group_id]
  key_name               = var.key_name != "" ? var.key_name : null

  tags = {
    Name        = var.instance_count > 1 ? "${var.name_prefix}-${count.index}" : var.name_prefix
    Project     = var.project_tag
    Environment = terraform.workspace
  }
}

resource "null_resource" "connectivity_smoke_test" {
  triggers = {
    instance_ids = join(",", aws_instance.web[*].id)
  }

  provisioner "local-exec" {
    command = "echo 'smoke test placeholder: confirm outbound internet route is up before handing off to Ansible'"
  }
}
