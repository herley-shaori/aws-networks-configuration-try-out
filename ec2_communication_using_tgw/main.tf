terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
  required_version = ">= 1.0"
}

variable "enable_tgw_connection" {
  description = "Toggle TGW connectivity between VPC A and VPC B"
  type        = bool
  default     = true
}

provider "aws" {
  region = "ap-southeast-3"
}

provider "aws" {
  alias  = "peer"
  region = "ap-southeast-3"
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_availability_zones" "available" {}

# Create two VPCs: VPC A and VPC B
resource "aws_vpc" "vpc_a" {
  cidr_block = "10.0.0.0/16"
  tags = { Name = "vpc-a" }
}
resource "aws_vpc" "vpc_b" {
  cidr_block = "10.1.0.0/16"
  tags = { Name = "vpc-b" }
}

# Create one subnet in each VPC
resource "aws_subnet" "subnet_a" {
  vpc_id            = aws_vpc.vpc_a.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
  tags = { Name = "subnet-a" }
}
resource "aws_subnet" "subnet_b" {
  vpc_id            = aws_vpc.vpc_b.id
  cidr_block        = "10.1.1.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
  tags = { Name = "subnet-b" }
}

# Internet Gateways and route tables for initial connectivity
resource "aws_internet_gateway" "igw_a" {
  vpc_id = aws_vpc.vpc_a.id
  tags   = { Name = "igw-a" }
}
resource "aws_internet_gateway" "igw_b" {
  vpc_id = aws_vpc.vpc_b.id
  tags   = { Name = "igw-b" }
}
resource "aws_route_table" "rt_a_internet" {
  vpc_id = aws_vpc.vpc_a.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw_a.id
  }
  tags = { Name = "rt-a-internet" }
}
resource "aws_route_table" "rt_b_internet" {
  vpc_id = aws_vpc.vpc_b.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw_b.id
  }
  tags = { Name = "rt-b-internet" }
}
resource "aws_route_table_association" "a_internet" {
  subnet_id      = aws_subnet.subnet_a.id
  route_table_id = aws_route_table.rt_a_internet.id
}
resource "aws_route_table_association" "b_internet" {
  subnet_id      = aws_subnet.subnet_b.id
  route_table_id = aws_route_table.rt_b_internet.id
}

resource "aws_route" "a_to_tgw" {
  count = var.enable_tgw_connection ? 1 : 0
  route_table_id         = aws_route_table.rt_a_internet.id
  destination_cidr_block = aws_vpc.vpc_b.cidr_block
  transit_gateway_id     = aws_ec2_transit_gateway.tgw.id
}

resource "aws_route" "b_to_tgw" {
  count = var.enable_tgw_connection ? 1 : 0
  route_table_id         = aws_route_table.rt_b_internet.id
  destination_cidr_block = aws_vpc.vpc_a.cidr_block
  transit_gateway_id     = aws_ec2_transit_gateway.tgw.id
}

# Create one Transit Gateway (TGW)
resource "aws_ec2_transit_gateway" "tgw" {
  description = "Transit Gateway"
  tags        = { Name = "tgw" }
}

# Fetch the default route table for the Transit Gateway
data "aws_ec2_transit_gateway_route_table" "default" {
  filter {
    name   = "default-association-route-table"
    values = ["true"]
  }
  filter {
    name   = "transit-gateway-id"
    values = [aws_ec2_transit_gateway.tgw.id]
  }
}

# Attach each VPC to the TGW
resource "aws_ec2_transit_gateway_vpc_attachment" "attach_a" {
  transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  vpc_id             = aws_vpc.vpc_a.id
  subnet_ids         = [aws_subnet.subnet_a.id]
  tags               = { Name = "attach-a" }
}
resource "aws_ec2_transit_gateway_vpc_attachment" "attach_b" {
  transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  vpc_id             = aws_vpc.vpc_b.id
  subnet_ids         = [aws_subnet.subnet_b.id]
  tags               = { Name = "attach-b" }
}

# Add static routes pointing to attachments
resource "aws_ec2_transit_gateway_route" "a_to_b" {
  count                           = var.enable_tgw_connection ? 1 : 0
  destination_cidr_block          = aws_vpc.vpc_b.cidr_block
  transit_gateway_route_table_id  = data.aws_ec2_transit_gateway_route_table.default.id
  transit_gateway_attachment_id   = aws_ec2_transit_gateway_vpc_attachment.attach_b.id
}
resource "aws_ec2_transit_gateway_route" "b_to_a" {
  count                           = var.enable_tgw_connection ? 1 : 0
  destination_cidr_block          = aws_vpc.vpc_a.cidr_block
  transit_gateway_route_table_id  = data.aws_ec2_transit_gateway_route_table.default.id
  transit_gateway_attachment_id   = aws_ec2_transit_gateway_vpc_attachment.attach_a.id
}

# Security groups to allow ICMP between instances
resource "aws_security_group" "sg_a" {
  name   = "allow_icmp_a"
  vpc_id = aws_vpc.vpc_a.id
  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [aws_vpc.vpc_b.cidr_block]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "allow_icmp_a" }
}
resource "aws_security_group" "sg_b" {
  name   = "allow_icmp_b"
  vpc_id = aws_vpc.vpc_b.id
  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [aws_vpc.vpc_a.cidr_block]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "allow_icmp_b" }
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_instance" "a" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.subnet_a.id
  vpc_security_group_ids      = [aws_security_group.sg_a.id]
  associate_public_ip_address = true
  tags = { Name = "instance-a" }
}
resource "aws_instance" "b" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.subnet_b.id
  vpc_security_group_ids      = [aws_security_group.sg_b.id]
  associate_public_ip_address = true
  tags = { Name = "instance-b" }
}

output "instance_a_private_ip" {
  value = aws_instance.a.private_ip
}
output "instance_b_private_ip" {
  value = aws_instance.b.private_ip
}
output "tgw_id" {
  value = aws_ec2_transit_gateway.tgw.id
}