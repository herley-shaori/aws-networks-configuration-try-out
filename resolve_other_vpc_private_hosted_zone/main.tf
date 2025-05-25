terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.50.0"
    }
  }
}

provider "aws" {
  region = "ap-southeast-3"
}

# -------------------------------------------------------------------
# 1. VPC Definitions
# -------------------------------------------------------------------
# -------------------------------------------------------------------
# 1. VPC Definitions
# -------------------------------------------------------------------
resource "aws_vpc" "vpc_a" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "vpc-a"
  }
}

resource "aws_subnet" "subnet_a1" {
  vpc_id            = aws_vpc.vpc_a.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "ap-southeast-3a"
}
resource "aws_subnet" "subnet_a2" {
  vpc_id            = aws_vpc.vpc_a.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-southeast-3b"
}

resource "aws_vpc" "vpc_b" {
  cidr_block           = "10.1.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "vpc-b"
  }
}

resource "aws_subnet" "subnet_b1" {
  vpc_id            = aws_vpc.vpc_b.id
  cidr_block        = "10.1.1.0/24"
  availability_zone = "ap-southeast-3a"
}
resource "aws_subnet" "subnet_b2" {
  vpc_id            = aws_vpc.vpc_b.id
  cidr_block        = "10.1.2.0/24"
  availability_zone = "ap-southeast-3b"
}

# -------------------------------------------------------------------
# Internet Gateways
# -------------------------------------------------------------------
resource "aws_internet_gateway" "igw_a" {
  vpc_id = aws_vpc.vpc_a.id
  tags = { Name = "igw-a" }
}
resource "aws_internet_gateway" "igw_b" {
  vpc_id = aws_vpc.vpc_b.id
  tags = { Name = "igw-b" }
}

# -------------------------------------------------------------------
# Public Route Tables
# -------------------------------------------------------------------
resource "aws_route_table" "public_a" {
  vpc_id = aws_vpc.vpc_a.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw_a.id
  }
  tags = { Name = "public-rt-a" }
}
resource "aws_route_table_association" "public_a1" {
  subnet_id      = aws_subnet.subnet_a1.id
  route_table_id = aws_route_table.public_a.id
}
resource "aws_route_table_association" "public_a2" {
  subnet_id      = aws_subnet.subnet_a2.id
  route_table_id = aws_route_table.public_a.id
}

resource "aws_route_table" "public_b" {
  vpc_id = aws_vpc.vpc_b.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw_b.id
  }
  tags = { Name = "public-rt-b" }
}
resource "aws_route_table_association" "public_b1" {
  subnet_id      = aws_subnet.subnet_b1.id
  route_table_id = aws_route_table.public_b.id
}
resource "aws_route_table_association" "public_b2" {
  subnet_id      = aws_subnet.subnet_b2.id
  route_table_id = aws_route_table.public_b.id
}

# -------------------------------------------------------------------
# 2. Security Groups for Resolver Endpoints
# -------------------------------------------------------------------
resource "aws_security_group" "r53_inbound_sg" {
  name        = "r53-inbound-sg"
  description = "Allow DNS queries from VPC B"
  vpc_id      = aws_vpc.vpc_a.id

  ingress {
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = [aws_vpc.vpc_b.cidr_block]
  }
  ingress {
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.vpc_b.cidr_block]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "r53_outbound_sg" {
  name        = "r53-outbound-sg"
  description = "Allow forwarding to inbound endpoint in VPC A"
  vpc_id      = aws_vpc.vpc_b.id

  egress {
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = [aws_vpc.vpc_a.cidr_block]
  }
  egress {
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.vpc_a.cidr_block]
  }
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# -------------------------------------------------------------------
# 3. Private Hosted Zone in VPC A
# -------------------------------------------------------------------
resource "aws_route53_zone" "private" {
  name = "myapp.internal"

  vpc {
    vpc_id = aws_vpc.vpc_a.id
  }

  comment = "Private hosted zone for myapp.internal in VPC A"
}

# -------------------------------------------------------------------
# 3.1: A-Record for app.myapp.internal in the private hosted zone
# -------------------------------------------------------------------
resource "aws_route53_record" "app" {
  zone_id = aws_route53_zone.private.zone_id
  name    = "app.myapp.internal"
  type    = "A"
  ttl     = 60
  records = ["10.0.1.123"]
}

# -------------------------------------------------------------------
# 4. Resolver Endpoints
# -------------------------------------------------------------------
resource "aws_route53_resolver_endpoint" "inbound" {
  name               = "inbound-resolver"
  direction          = "INBOUND"
  security_group_ids = [aws_security_group.r53_inbound_sg.id]

  ip_address {
    subnet_id = aws_subnet.subnet_a1.id
  }
  ip_address {
    subnet_id = aws_subnet.subnet_a2.id
  }
}

resource "aws_route53_resolver_endpoint" "outbound" {
  name               = "outbound-resolver"
  direction          = "OUTBOUND"
  security_group_ids = [aws_security_group.r53_outbound_sg.id]

  ip_address {
    subnet_id = aws_subnet.subnet_b1.id
  }
  ip_address {
    subnet_id = aws_subnet.subnet_b2.id
  }
}

# -------------------------------------------------------------------
# 5. Forwarding Rule for myapp.internal
# -------------------------------------------------------------------
resource "aws_route53_resolver_rule" "forward_myapp" {
  name                 = "forward-myapp"
  domain_name          = "myapp.internal"
  rule_type            = "FORWARD"
  resolver_endpoint_id = aws_route53_resolver_endpoint.outbound.id

  dynamic "target_ip" {
    for_each = aws_route53_resolver_endpoint.inbound.ip_address
    content {
      ip   = target_ip.value.ip
      port = 53
    }
  }

  tags = {
    Name = "forward-myapp"
  }
}

# -------------------------------------------------------------------
# 6. Associate Rule with VPC B
# -------------------------------------------------------------------
# -------------------------------------------------------------------
# 6. Associate Rule with VPC B
# -------------------------------------------------------------------
resource "aws_route53_resolver_rule_association" "b" {
  name            = "assoc-forward-myapp-b"
  resolver_rule_id = aws_route53_resolver_rule.forward_myapp.id
  vpc_id          = aws_vpc.vpc_b.id
}

# -------------------------------------------------------------------
# 7. EC2 Instances for Testing
# -------------------------------------------------------------------
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_security_group" "instance_sg_a" {
  name        = "instance-sg-a"
  description = "Allow SSH inbound"
  vpc_id      = aws_vpc.vpc_a.id

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
}

resource "aws_security_group" "instance_sg_b" {
  name        = "instance-sg-b"
  description = "Allow SSH inbound"
  vpc_id      = aws_vpc.vpc_b.id

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
}

resource "aws_instance" "instance_a" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.subnet_a1.id
  vpc_security_group_ids      = [aws_security_group.instance_sg_a.id]
  associate_public_ip_address = true

  tags = {
    Name = "instance-a"
  }
}

resource "aws_instance" "instance_b" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.subnet_b1.id
  vpc_security_group_ids      = [aws_security_group.instance_sg_b.id]
  associate_public_ip_address = true

  tags = {
    Name = "instance-b"
  }
}