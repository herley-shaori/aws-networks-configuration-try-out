# IAM Role and Instance Profile for SSM
resource "aws_iam_role" "ssm" {
  name = "ssm-instance-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm" {
  name = "ssm-instance-profile"
  role = aws_iam_role.ssm.name
}

variable "vpc_cidrs" {
  type = map(string)
  default = {
    A = "10.0.0.0/27"
    B = "10.0.0.32/27"
  }
}

locals {
  vpcs = var.vpc_cidrs
}

resource "aws_vpc" "vpc" {
  for_each = local.vpcs

  cidr_block           = each.value
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(
    local.common_tags,
    {
      Name = "${each.key}-vpc"
    }
  )
}

# Internet gateways for each VPC
resource "aws_internet_gateway" "igw" {
  for_each = local.vpcs
  vpc_id   = aws_vpc.vpc[each.key].id

  tags = merge(
    local.common_tags,
    { Name = "${each.key}-igw" }
  )
}

# Public route tables for each VPC
resource "aws_route_table" "public" {
  for_each = local.vpcs
  vpc_id   = aws_vpc.vpc[each.key].id

  tags = merge(
    local.common_tags,
    { Name = "${each.key}-public-rt" }
  )
}

# Default route to IGW in each public route table
resource "aws_route" "public_internet_access" {
  for_each               = local.vpcs
  route_table_id         = aws_route_table.public[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw[each.key].id
}

# Associate public subnets with their route tables
resource "aws_route_table_association" "public" {
  for_each       = local.vpcs
  subnet_id      = aws_subnet.public[each.key].id
  route_table_id = aws_route_table.public[each.key].id
}
 
# Fetch availability zones
data "aws_availability_zones" "available" {}

# Amazon Linux 2 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# Private subnets for each VPC
# Public subnets for EC2
resource "aws_subnet" "public" {
  for_each                = local.vpcs
  vpc_id                  = aws_vpc.vpc[each.key].id
  cidr_block              = cidrsubnet(each.value, 1, 0)
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[0]

  tags = merge(
    local.common_tags,
    { Name = "${each.key}-public-subnet" }
  )
}

# Security group allowing traffic from all VPC CIDRs
resource "aws_security_group" "allow_vpc_cidrs" {
  for_each    = local.vpcs
  name        = "${each.key}-sg"
  description = "Allow traffic from all VPC CIDRs"
  vpc_id      = aws_vpc.vpc[each.key].id

  tags = merge(
    local.common_tags,
    { Name = "${each.key}-sg" }
  )

  dynamic "ingress" {
    for_each = local.vpcs
    content {
      description = "Allow from ${ingress.key}"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = [ingress.value]
    }
  }

  ingress {
    description = "Allow SSH from anywhere for Instance Connect"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Amazon Linux EC2 instances in each private subnet
resource "aws_instance" "amazon_linux" {
  for_each = local.vpcs

  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public[each.key].id
  associate_public_ip_address = true

  user_data = <<-EOF
    #!/bin/bash
    sudo yum install -y ec2-instance-connect
  EOF

  vpc_security_group_ids = [aws_security_group.allow_vpc_cidrs[each.key].id]
  iam_instance_profile   = aws_iam_instance_profile.ssm.name

  tags = merge(
    local.common_tags,
    { Name = "${each.key}-instance" }
  )
}