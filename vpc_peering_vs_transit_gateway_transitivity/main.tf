terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
  required_version = ">= 1.2.0"
}

provider "aws" {
  region = "ap-southeast-3"
}

variable "connection_mode" {
  description = "Choose 'peering' for VPC peering routes or 'tgw' for Transit Gateway routes"
  type        = string
  default     = "tgw"
}

# IAM role for SSM
resource "aws_iam_role" "ssm_role" {
  name = "ssm-managed-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_role_attach" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm_profile" {
  name = "ssm-managed-instance-profile"
  role = aws_iam_role.ssm_role.name
}

# Create three VPCs: A, B, C
resource "aws_vpc" "vpcA" {
  cidr_block = "10.0.0.0/16"
  tags       = { Name = "VPC-A" }
}
resource "aws_vpc" "vpcB" {
  cidr_block = "10.1.0.0/16"
  tags       = { Name = "VPC-B" }
}
resource "aws_vpc" "vpcC" {
  cidr_block = "10.2.0.0/16"
  tags       = { Name = "VPC-C" }
}

# Internet Gateways for each VPC
resource "aws_internet_gateway" "igwA" {
  vpc_id = aws_vpc.vpcA.id
  tags   = { Name = "igw-A" }
}
resource "aws_internet_gateway" "igwB" {
  vpc_id = aws_vpc.vpcB.id
  tags   = { Name = "igw-B" }
}
resource "aws_internet_gateway" "igwC" {
  vpc_id = aws_vpc.vpcC.id
  tags   = { Name = "igw-C" }
}

# Public Subnets (one per VPC)
resource "aws_subnet" "publicA" {
  vpc_id                  = aws_vpc.vpcA.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-southeast-3a"
  map_public_ip_on_launch = true
  tags = { Name = "public-A" }
}
resource "aws_subnet" "publicB" {
  vpc_id                  = aws_vpc.vpcB.id
  cidr_block              = "10.1.1.0/24"
  availability_zone       = "ap-southeast-3a"
  map_public_ip_on_launch = true
  tags = { Name = "public-B" }
}
resource "aws_subnet" "publicC" {
  vpc_id                  = aws_vpc.vpcC.id
  cidr_block              = "10.2.1.0/24"
  availability_zone       = "ap-southeast-3a"
  map_public_ip_on_launch = true
  tags = { Name = "public-C" }
}

# Route Tables for public subnets
resource "aws_route_table" "rtA" {
  vpc_id = aws_vpc.vpcA.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igwA.id
  }
  tags = { Name = "rt-public-A" }
}
resource "aws_route_table_association" "rtaA" {
  subnet_id      = aws_subnet.publicA.id
  route_table_id = aws_route_table.rtA.id
}
resource "aws_route_table" "rtB" {
  vpc_id = aws_vpc.vpcB.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igwB.id
  }
  tags = { Name = "rt-public-B" }
}
resource "aws_route_table_association" "rtaB" {
  subnet_id      = aws_subnet.publicB.id
  route_table_id = aws_route_table.rtB.id
}
resource "aws_route_table" "rtC" {
  vpc_id = aws_vpc.vpcC.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igwC.id
  }
  tags = { Name = "rt-public-C" }
}
resource "aws_route_table_association" "rtaC" {
  subnet_id      = aws_subnet.publicC.id
  route_table_id = aws_route_table.rtC.id
}

# Security Groups allowing ICMP (ping) and HTTP
resource "aws_security_group" "sgA" {
  name        = "allow-icmp-http-A"
  description = "Allow ICMP and HTTP"
  vpc_id      = aws_vpc.vpcA.id

  ingress {
    protocol    = "icmp"
    from_port   = -1
    to_port     = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "sg-A" }
}
resource "aws_security_group" "sgB" {
  name        = "allow-icmp-http-B"
  description = "Allow ICMP and HTTP"
  vpc_id      = aws_vpc.vpcB.id

  ingress {
    protocol    = "icmp"
    from_port   = -1
    to_port     = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "sg-B" }
}
resource "aws_security_group" "sgC" {
  name        = "allow-icmp-http-C"
  description = "Allow ICMP and HTTP"
  vpc_id      = aws_vpc.vpcC.id

  ingress {
    protocol    = "icmp"
    from_port   = -1
    to_port     = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "sg-C" }
}

# VPC Peering Connections: A-B and B-C
resource "aws_vpc_peering_connection" "peeringAB" {
  vpc_id        = aws_vpc.vpcA.id
  peer_vpc_id   = aws_vpc.vpcB.id
  auto_accept   = true
  tags          = { Name = "peering-A-B" }
}
resource "aws_route" "routeAtoB" {
  count                    = var.connection_mode == "peering" ? 1 : 0
  route_table_id            = aws_route_table.rtA.id
  destination_cidr_block    = aws_vpc.vpcB.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.peeringAB.id
}
resource "aws_route" "routeBtoA" {
  count                    = var.connection_mode == "peering" ? 1 : 0
  route_table_id            = aws_route_table.rtB.id
  destination_cidr_block    = aws_vpc.vpcA.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.peeringAB.id
}

resource "aws_vpc_peering_connection" "peeringBC" {
  vpc_id        = aws_vpc.vpcB.id
  peer_vpc_id   = aws_vpc.vpcC.id
  auto_accept   = true
  tags          = { Name = "peering-B-C" }
}
resource "aws_route" "routeBtoC" {
  count                    = var.connection_mode == "peering" ? 1 : 0
  route_table_id            = aws_route_table.rtB.id
  destination_cidr_block    = aws_vpc.vpcC.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.peeringBC.id
}
resource "aws_route" "routeCtoB" {
  count                    = var.connection_mode == "peering" ? 1 : 0
  route_table_id            = aws_route_table.rtC.id
  destination_cidr_block    = aws_vpc.vpcB.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.peeringBC.id
}

# Transit Gateway and Attachments
resource "aws_ec2_transit_gateway" "tgw" {
  description      = "TGW for VPC Lab"
  amazon_side_asn  = 64512
  tags             = { Name = "tgw-lab" }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "attachA" {
  transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  vpc_id             = aws_vpc.vpcA.id
  subnet_ids         = [aws_subnet.publicA.id]
  tags               = { Name = "tgw-attach-A" }
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false
}
resource "aws_ec2_transit_gateway_vpc_attachment" "attachB" {
  transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  vpc_id             = aws_vpc.vpcB.id
  subnet_ids         = [aws_subnet.publicB.id]
  tags               = { Name = "tgw-attach-B" }
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false
}
resource "aws_ec2_transit_gateway_vpc_attachment" "attachC" {
  transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  vpc_id             = aws_vpc.vpcC.id
  subnet_ids         = [aws_subnet.publicC.id]
  tags               = { Name = "tgw-attach-C" }
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false
}

resource "aws_ec2_transit_gateway_route_table" "tgw_rt" {
  transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  tags               = { Name = "tgw-rt-lab" }
}

# Associate and propagate each attachment with the TGW route table
resource "aws_ec2_transit_gateway_route_table_association" "assocA" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.attachA.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.tgw_rt.id
}
resource "aws_ec2_transit_gateway_route_table_association" "assocB" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.attachB.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.tgw_rt.id
}
resource "aws_ec2_transit_gateway_route_table_association" "assocC" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.attachC.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.tgw_rt.id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "propA" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.attachA.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.tgw_rt.id
}
resource "aws_ec2_transit_gateway_route_table_propagation" "propB" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.attachB.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.tgw_rt.id
}
resource "aws_ec2_transit_gateway_route_table_propagation" "propC" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.attachC.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.tgw_rt.id
}

# Add TGW routes in each VPC route table for full mesh via Transit Gateway
resource "aws_route" "rtAtoTGW_b" {
  count                  = var.connection_mode == "tgw" ? 1 : 0
  route_table_id         = aws_route_table.rtA.id
  destination_cidr_block = aws_vpc.vpcB.cidr_block
  transit_gateway_id     = aws_ec2_transit_gateway.tgw.id
}
resource "aws_route" "rtAtoTGW_c" {
  count                  = var.connection_mode == "tgw" ? 1 : 0
  route_table_id         = aws_route_table.rtA.id
  destination_cidr_block = aws_vpc.vpcC.cidr_block
  transit_gateway_id     = aws_ec2_transit_gateway.tgw.id
}

resource "aws_route" "rtBtoTGW_a" {
  count                  = var.connection_mode == "tgw" ? 1 : 0
  route_table_id         = aws_route_table.rtB.id
  destination_cidr_block = aws_vpc.vpcA.cidr_block
  transit_gateway_id     = aws_ec2_transit_gateway.tgw.id
}
resource "aws_route" "rtBtoTGW_c" {
  count                  = var.connection_mode == "tgw" ? 1 : 0
  route_table_id         = aws_route_table.rtB.id
  destination_cidr_block = aws_vpc.vpcC.cidr_block
  transit_gateway_id     = aws_ec2_transit_gateway.tgw.id
}

resource "aws_route" "rtCtoTGW_a" {
  count                  = var.connection_mode == "tgw" ? 1 : 0
  route_table_id         = aws_route_table.rtC.id
  destination_cidr_block = aws_vpc.vpcA.cidr_block
  transit_gateway_id     = aws_ec2_transit_gateway.tgw.id
}
resource "aws_route" "rtCtoTGW_b" {
  count                  = var.connection_mode == "tgw" ? 1 : 0
  route_table_id         = aws_route_table.rtC.id
  destination_cidr_block = aws_vpc.vpcB.cidr_block
  transit_gateway_id     = aws_ec2_transit_gateway.tgw.id
}

# EC2 Instances in each VPC public subnet (no key pair)
data "aws_ami" "amazonlinux2" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_instance" "instanceA" {
  ami                         = data.aws_ami.amazonlinux2.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.publicA.id
  vpc_security_group_ids      = [aws_security_group.sgA.id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.ssm_profile.name
  tags = { Name = "Instance-A" }
}

resource "aws_instance" "instanceB" {
  ami                         = data.aws_ami.amazonlinux2.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.publicB.id
  vpc_security_group_ids      = [aws_security_group.sgB.id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.ssm_profile.name
  tags = { Name = "Instance-B" }
}

resource "aws_instance" "instanceC" {
  ami                         = data.aws_ami.amazonlinux2.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.publicC.id
  vpc_security_group_ids      = [aws_security_group.sgC.id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.ssm_profile.name
  tags = { Name = "Instance-C" }
}