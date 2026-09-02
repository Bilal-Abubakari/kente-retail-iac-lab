locals {
  # With workspaces actually in use now, this resolves to "dev" or "staging"
  # (the root config guards against the default workspace). It is used only for
  # the human-readable Name tags; Project and Environment come from the
  # provider's default_tags.
  env_label = terraform.workspace
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "kente-vpc-${local.env_label}"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "kente-igw-${local.env_label}"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 4, 0)
  map_public_ip_on_launch = true

  tags = {
    Name = "kente-public-subnet-${local.env_label}"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "kente-public-rt-${local.env_label}"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "web" {
  name        = "kente-web-sg-${local.env_label}"
  description = "Allows SSH (for Ansible) and the app's HTTP port."
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH for Ansible configuration"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    # Locked to the machine Ansible runs from — no longer 0.0.0.0/0. The root
    # variable validation refuses to let this be the whole internet.
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  ingress {
    description = "Kente Retail order-service"
    from_port   = var.app_port
    to_port     = var.app_port
    protocol    = "tcp"
    cidr_blocks = [var.allowed_app_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "kente-web-sg-${local.env_label}"
  }
}
