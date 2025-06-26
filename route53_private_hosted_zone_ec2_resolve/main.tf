terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0"
    }
  }
}

provider "aws" {
  region = "ap-southeast-3"
}

# -----------------------
# VPC A and related resources
# -----------------------
resource "aws_vpc" "vpc_a" {
  cidr_block           = "10.10.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "vpc-a" }
}

resource "aws_subnet" "subnet_a" {
  vpc_id                  = aws_vpc.vpc_a.id
  cidr_block              = "10.10.1.0/24"
  availability_zone       = "ap-southeast-3a"
  map_public_ip_on_launch = true
  tags                    = { Name = "subnet-a" }
}

resource "aws_internet_gateway" "igw_a" {
  vpc_id = aws_vpc.vpc_a.id
  tags   = { Name = "igw-a" }
}

resource "aws_route_table" "rt_a" {
  vpc_id = aws_vpc.vpc_a.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw_a.id
  }

  tags = { Name = "rt-a" }
}

resource "aws_route_table_association" "rta_a" {
  subnet_id      = aws_subnet.subnet_a.id
  route_table_id = aws_route_table.rt_a.id
}

# -----------------------
# VPC B and related resources
# -----------------------
resource "aws_vpc" "vpc_b" {
  cidr_block           = "10.20.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "vpc-b" }
}

resource "aws_subnet" "subnet_b" {
  vpc_id                  = aws_vpc.vpc_b.id
  cidr_block              = "10.20.1.0/24"
  availability_zone       = "ap-southeast-3a"
  map_public_ip_on_launch = true
  tags                    = { Name = "subnet-b" }
}

resource "aws_internet_gateway" "igw_b" {
  vpc_id = aws_vpc.vpc_b.id
  tags   = { Name = "igw-b" }
}

resource "aws_route_table" "rt_b" {
  vpc_id = aws_vpc.vpc_b.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw_b.id
  }

  tags = { Name = "rt-b" }
}

resource "aws_route_table_association" "rta_b" {
  subnet_id      = aws_subnet.subnet_b.id
  route_table_id = aws_route_table.rt_b.id
}

# -----------------------
# VPC peering and routes
# -----------------------
resource "aws_vpc_peering_connection" "peer" {
  vpc_id      = aws_vpc.vpc_a.id
  peer_vpc_id = aws_vpc.vpc_b.id
  auto_accept = true
  tags        = { Name = "vpc-a-b-peer" }
}

resource "aws_route" "a_to_b" {
  route_table_id            = aws_route_table.rt_a.id
  destination_cidr_block    = aws_vpc.vpc_b.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.peer.id
}

resource "aws_route" "b_to_a" {
  route_table_id            = aws_route_table.rt_b.id
  destination_cidr_block    = aws_vpc.vpc_a.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.peer.id
}

# -----------------------
# Security groups
# -----------------------
resource "aws_security_group" "sg_a" {
  name   = "sg-a"
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
  tags = { Name = "sg-a" }
}

resource "aws_security_group" "sg_b" {
  name   = "sg-b"
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
  tags = { Name = "sg-b" }
}

# -----------------------
# EC2 instances
# -----------------------
data "aws_ami" "al2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_instance" "instance_a" {
  ami                         = data.aws_ami.al2.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.subnet_a.id
  vpc_security_group_ids      = [aws_security_group.sg_a.id]
  associate_public_ip_address = true
  tags                        = { Name = "instance-a" }
}

resource "aws_instance" "instance_b" {
  ami                         = data.aws_ami.al2.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.subnet_b.id
  vpc_security_group_ids      = [aws_security_group.sg_b.id]
  associate_public_ip_address = true
  tags                        = { Name = "instance-b" }
}

# -----------------------
# Private hosted zone and records
# -----------------------
resource "aws_route53_zone" "phz" {
  name = "demo.internal"
  vpc { vpc_id = aws_vpc.vpc_a.id }
  vpc { vpc_id = aws_vpc.vpc_b.id }
  comment = "Shared private zone"
}

resource "aws_route53_record" "a_record" {
  zone_id = aws_route53_zone.phz.zone_id
  name    = "a.demo.internal"
  type    = "A"
  ttl     = 60
  records = [aws_instance.instance_a.private_ip]
}

resource "aws_route53_record" "b_record" {
  zone_id = aws_route53_zone.phz.zone_id
  name    = "b.demo.internal"
  type    = "A"
  ttl     = 60
  records = [aws_instance.instance_b.private_ip]
}
