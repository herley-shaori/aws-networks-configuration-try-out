terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0"
    }
  }
}

provider "aws" {
  region = var.region
}

data "aws_availability_zones" "available" {}

data "aws_region" "current" {}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-ebs"]
  }
}

variable "region" {
  type    = string
  default = "ap-southeast-3"
}

variable "provider_vpc_cidr" {
  type    = string
  default = "10.0.10.0/24"
}

variable "consumer_vpc_cidr" {
  type    = string
  default = "10.0.20.0/24"
}

locals {
  provider_subnet_cidrs = ["10.0.10.0/25", "10.0.10.128/25"]
  consumer_subnet_cidrs = ["10.0.20.0/25", "10.0.20.128/25"]
}

# ----- Provider VPC -----
resource "aws_vpc" "provider" {
  cidr_block           = var.provider_vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "provider-vpc"
  }
}

resource "aws_internet_gateway" "provider_igw" {
  vpc_id = aws_vpc.provider.id

  tags = {
    Name = "provider-igw"
  }
}

resource "aws_route_table" "provider_public_rt" {
  vpc_id = aws_vpc.provider.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.provider_igw.id
  }

  tags = {
    Name = "provider-public-rt"
  }
}

resource "aws_route_table_association" "provider_public_rta" {
  subnet_id      = aws_subnet.provider[0].id
  route_table_id = aws_route_table.provider_public_rt.id
}

resource "aws_subnet" "provider" {
  count             = length(local.provider_subnet_cidrs)
  vpc_id            = aws_vpc.provider.id
  cidr_block        = local.provider_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = {
    Name = "provider-subnet-${count.index}"
  }
}

resource "aws_security_group" "provider_sg" {
  name   = "provider-sg"
  vpc_id = aws_vpc.provider.id

  ingress {
    description = "Allow all traffic from provider VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.provider_vpc_cidr]
  }

  ingress {
    description = "Allow HTTP from consumer VPC via PrivateLink"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.consumer_vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "provider-sg"
  }
}

resource "aws_security_group" "provider_instance_sg" {
  name        = "provider-instance-sg"
  vpc_id      = aws_vpc.provider.id
  description = "Allow SSM traffic"

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "provider-instance-sg"
  }
}

data "aws_iam_policy_document" "provider_ssm_assume_policy" {
  statement {
    effect       = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "provider_ssm_role" {
  name               = "provider-ssm-managed-instance-role"
  assume_role_policy = data.aws_iam_policy_document.provider_ssm_assume_policy.json
}

resource "aws_iam_role_policy_attachment" "provider_ssm_core" {
  role       = aws_iam_role.provider_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "provider_ssm_profile" {
  name = "provider-ssm-instance-profile"
  role = aws_iam_role.provider_ssm_role.name
}

locals {
  provider_ssm_services = [
    "ssm",
    "ssmmessages",
    "ec2messages",
  ]
}

resource "aws_vpc_endpoint" "provider_ssm_endpoints" {
  for_each            = toset(local.provider_ssm_services)
  vpc_id              = aws_vpc.provider.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.${each.key}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.provider[*].id
  security_group_ids  = [aws_security_group.provider_instance_sg.id]
  private_dns_enabled = true
}

resource "aws_instance" "provider_app" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.provider[0].id
  associate_public_ip_address = true
  iam_instance_profile   = aws_iam_instance_profile.provider_ssm_profile.name
  vpc_security_group_ids = [
    aws_security_group.provider_sg.id,
    aws_security_group.provider_instance_sg.id
  ]
  user_data = <<-EOF
    #!/bin/bash
    yum install -y httpd
    systemctl enable httpd
    systemctl start httpd
    echo "Hello from provider" > /var/www/html/index.html
  EOF

  tags = {
    Name = "provider-instance"
  }
}

resource "aws_lb" "nlb" {
  name               = "provider-nlb"
  internal           = true
  load_balancer_type = "network"

  dynamic "subnet_mapping" {
    for_each = aws_subnet.provider
    content {
      subnet_id = subnet_mapping.value.id
    }
  }

  tags = {
    Name = "provider-nlb"
  }
}

resource "aws_lb_target_group" "provider_tg" {
  name        = "provider-tg"
  port        = 80
  protocol    = "TCP"
  target_type = "instance"
  vpc_id      = aws_vpc.provider.id

  health_check {
    protocol            = "TCP"
    port                = "80"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_target_group_attachment" "app_attachment" {
  target_group_arn = aws_lb_target_group.provider_tg.arn
  target_id        = aws_instance.provider_app.id
  port             = 80
}

resource "aws_lb_listener" "nlb_listener" {
  load_balancer_arn = aws_lb.nlb.arn
  port              = 80
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.provider_tg.arn
  }
}

resource "aws_vpc_endpoint_service" "private_link_service" {
  acceptance_required        = false
  network_load_balancer_arns = [aws_lb.nlb.arn]
}

# ----- Consumer VPC -----
resource "aws_vpc" "consumer" {
  cidr_block           = var.consumer_vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "consumer-vpc"
  }
}

resource "aws_subnet" "consumer" {
  count             = length(local.consumer_subnet_cidrs)
  vpc_id            = aws_vpc.consumer.id
  cidr_block        = local.consumer_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = {
    Name = "consumer-subnet-${count.index}"
  }
}

resource "aws_security_group" "consumer_sg" {
  name   = "consumer-sg"
  vpc_id = aws_vpc.consumer.id

  ingress {
    description = "Allow TCP traffic from consumer VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.consumer_vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "consumer-sg"
  }
}

# SSM: IAM Role & Profile
resource "aws_iam_role" "consumer_ssm_role" {
  name = "consumer-ssm-managed-instance-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "consumer_ssm_core" {
  role       = aws_iam_role.consumer_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "consumer_ssm_profile" {
  name = "consumer-ssm-instance-profile"
  role = aws_iam_role.consumer_ssm_role.name
}

resource "aws_security_group" "consumer_instance_sg" {
  name        = "consumer-instance-sg"
  vpc_id      = aws_vpc.consumer.id
  description = "Allow outbound to SSM endpoints and inbound from itself"

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

locals {
  consumer_ssm_services = [
    "ssm",
    "ssmmessages",
    "ec2messages",
  ]
}

resource "aws_vpc_endpoint" "consumer_ssm_endpoints" {
  for_each            = toset(local.consumer_ssm_services)
  vpc_id              = aws_vpc.consumer.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.${each.key}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.consumer[*].id
  security_group_ids  = [aws_security_group.consumer_instance_sg.id]
  private_dns_enabled = true
}

resource "aws_instance" "consumer_test" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.consumer[0].id
  vpc_security_group_ids      = [aws_security_group.consumer_instance_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.consumer_ssm_profile.name
  associate_public_ip_address = false
  user_data = <<-EOF
    #!/bin/bash
    yum install -y aws-cli
  EOF
  tags = {
    Name = "consumer-ssm-test-instance"
  }
}

resource "aws_vpc_endpoint" "consumer_interface" {
  vpc_id              = aws_vpc.consumer.id
  vpc_endpoint_type   = "Interface"
  service_name        = aws_vpc_endpoint_service.private_link_service.service_name
  subnet_ids          = [for sn in aws_subnet.consumer : sn.id]
  security_group_ids  = [aws_security_group.consumer_sg.id]
  private_dns_enabled = false
}