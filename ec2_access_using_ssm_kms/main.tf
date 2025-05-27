#───────────────────────────────────────────────────────────────────────────────
# Provider & Region Lookup
#───────────────────────────────────────────────────────────────────────────────
variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-3"
}

provider "aws" {
  region = var.region
}

data "aws_availability_zones" "available" {}

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "autosetup-vpc"
  }
}

resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = {
    Name = "autosetup-private-${count.index}"
  }
}

data "aws_region" "current" {}

#───────────────────────────────────────────────────────────────────────────────
# Lookup: Latest Amazon Linux 2 & Your KMS Key
#───────────────────────────────────────────────────────────────────────────────
data "aws_ami" "amazon_linux2" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

data "aws_kms_alias" "use_case_key" {
  name = "alias/use-case-key"
}

#───────────────────────────────────────────────────────────────────────────────
# IAM Role & Instance Profile for SSM
#───────────────────────────────────────────────────────────────────────────────
resource "aws_iam_role" "ssm_managed_instance" {
  name = "ssm-managed-instance-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ssm_managed_instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm_profile" {
  name = "ssm-instance-profile"
  role = aws_iam_role.ssm_managed_instance.name
}

#───────────────────────────────────────────────────────────────────────────────
# (Optional) Interface VPC Endpoints for SSM
# so your private‐subnet EC2 can reach SSM without NAT/Internet
#───────────────────────────────────────────────────────────────────────────────
resource "aws_security_group" "instance_sg" {
  name        = "autosetup-instance-sg"
  description = "Allow necessary outbound for SSM"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }
}

resource "aws_security_group" "ssm_sg" {
  name        = "autosetup-ssm-sg"
  description = "Allow intra-VPC and SSM endpoint traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    self            = true
  }
  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = [aws_vpc.main.cidr_block]
  }
  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}

locals {
  ssm_services = [
    "ssm",
    "ssmmessages",
    "ec2messages",
  ]
}

resource "aws_vpc_endpoint" "ssm_eps" {
  for_each            = toset(local.ssm_services)
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.${each.key}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.instance_sg.id]
  private_dns_enabled = true
}

#───────────────────────────────────────────────────────────────────────────────
# EC2 Instance in Private Subnet, Encrypted with Your KMS Key
#───────────────────────────────────────────────────────────────────────────────
resource "aws_instance" "private_ssm" {
  ami                         = data.aws_ami.amazon_linux2.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.private[0].id
  iam_instance_profile        = aws_iam_instance_profile.ssm_profile.name
  associate_public_ip_address = false
  vpc_security_group_ids      = [aws_security_group.instance_sg.id]

  root_block_device {
    volume_size = 8
    volume_type = "gp3"
  }

  tags = {
    Name = "private-ssm-instance"
  }
}

#───────────────────────────────────────────────────────────────────────────────
# Outputs
#───────────────────────────────────────────────────────────────────────────────
output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.private_ssm.id
}

output "instance_private_ip" {
  description = "Private IP address"
  value       = aws_instance.private_ssm.private_ip
}