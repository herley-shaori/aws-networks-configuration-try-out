##################################################################
# main.tf
##################################################################

# ----------------------------------------
# PROVIDERS
# ----------------------------------------
provider "aws" {
  region = "ap-southeast-3"              # Jakarta
}

provider "aws" {
  alias  = "sg"
  region = "ap-southeast-1"              # Singapore
}

# ----------------------------------------
# DATA
# ----------------------------------------
# needed for TGW peering within same account
data "aws_caller_identity" "me" {}

# ----------------------------------------
# JAKARTA VPC + PUBLIC SUBNET
# ----------------------------------------
resource "aws_vpc" "jakarta" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name = "vpc-jakarta"
  }
}

resource "aws_subnet" "jakarta_public" {
  vpc_id                  = aws_vpc.jakarta.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-southeast-3a"
  map_public_ip_on_launch = true
  tags = {
    Name = "jakarta-public-subnet"
  }
}

resource "aws_internet_gateway" "jakarta_igw" {
  vpc_id = aws_vpc.jakarta.id
  tags   = {
    Name = "igw-jakarta"
  }
}

resource "aws_route_table" "jakarta_public_rt" {
  vpc_id = aws_vpc.jakarta.id
  tags   = {
    Name = "public-rt-jakarta"
  }
}

resource "aws_route" "jakarta_default_route" {
  route_table_id         = aws_route_table.jakarta_public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.jakarta_igw.id
}

resource "aws_route_table_association" "jakarta_pub_assoc" {
  subnet_id      = aws_subnet.jakarta_public.id
  route_table_id = aws_route_table.jakarta_public_rt.id
}

resource "aws_route" "jakarta_to_sg_via_tgw" {
  route_table_id         = aws_route_table.jakarta_public_rt.id
  destination_cidr_block = aws_vpc.singapore.cidr_block
  transit_gateway_id     = aws_ec2_transit_gateway.jakarta_tgw.id
}

# ----------------------------------------
# SINGAPORE VPC + PUBLIC SUBNET
# ----------------------------------------
resource "aws_vpc" "singapore" {
  provider             = aws.sg
  cidr_block           = "10.1.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name = "vpc-singapore"
  }
}

resource "aws_subnet" "singapore_public" {
  provider                = aws.sg
  vpc_id                  = aws_vpc.singapore.id
  cidr_block              = "10.1.1.0/24"
  availability_zone       = "ap-southeast-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "sg-public-subnet"
  }
}

resource "aws_internet_gateway" "singapore_igw" {
  provider = aws.sg
  vpc_id   = aws_vpc.singapore.id
  tags     = {
    Name = "igw-singapore"
  }
}

resource "aws_route_table" "singapore_public_rt" {
  provider = aws.sg
  vpc_id   = aws_vpc.singapore.id
  tags     = {
    Name = "public-rt-singapore"
  }
}

resource "aws_route" "sg_default_route" {
  provider               = aws.sg
  route_table_id         = aws_route_table.singapore_public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.singapore_igw.id
}

resource "aws_route_table_association" "sg_pub_assoc" {
  provider       = aws.sg
  subnet_id      = aws_subnet.singapore_public.id
  route_table_id = aws_route_table.singapore_public_rt.id
}

resource "aws_route" "sg_to_jakarta_via_tgw" {
  provider               = aws.sg
  route_table_id         = aws_route_table.singapore_public_rt.id
  destination_cidr_block = aws_vpc.jakarta.cidr_block
  transit_gateway_id     = aws_ec2_transit_gateway.singapore_tgw.id
}

# ----------------------------------------
# TRANSIT GATEWAYS
# ----------------------------------------
resource "aws_ec2_transit_gateway" "jakarta_tgw" {
  description = "Jakarta TGW"
  tags = {
    Name = "tgw-jakarta"
  }
}

resource "aws_ec2_transit_gateway" "singapore_tgw" {
  provider    = aws.sg
  description = "Singapore TGW"
  tags = {
    Name = "tgw-singapore"
  }
}

# ----------------------------------------
# TGW VPC ATTACHMENTS (one subnet each)
# ----------------------------------------
resource "aws_ec2_transit_gateway_vpc_attachment" "jakarta_attach" {
  transit_gateway_id = aws_ec2_transit_gateway.jakarta_tgw.id
  vpc_id             = aws_vpc.jakarta.id
  subnet_ids         = [aws_subnet.jakarta_public.id]
  tags = {
    Name = "attach-jakarta"
  }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "singapore_attach" {
  provider           = aws.sg
  transit_gateway_id = aws_ec2_transit_gateway.singapore_tgw.id
  vpc_id             = aws_vpc.singapore.id
  subnet_ids         = [aws_subnet.singapore_public.id]
  tags = {
    Name = "attach-singapore"
  }
}

# ----------------------------------------
# TGW PEERING
# ----------------------------------------
resource "aws_ec2_transit_gateway_peering_attachment" "jk_sg_peering" {
  transit_gateway_id      = aws_ec2_transit_gateway.jakarta_tgw.id
  peer_transit_gateway_id = aws_ec2_transit_gateway.singapore_tgw.id
  peer_account_id         = data.aws_caller_identity.me.account_id
  peer_region             = "ap-southeast-1"
  tags = {
    Name = "peering-jk-sg"
  }
}

resource "aws_ec2_transit_gateway_peering_attachment_accepter" "jk_sg_peering_accepter" {
  provider = aws.sg
  transit_gateway_attachment_id = aws_ec2_transit_gateway_peering_attachment.jk_sg_peering.id
  tags = {
    Name = "peering-jk-sg-accepter"
  }
}


# Fetch Jakarta TGW’s default association route table
data "aws_ec2_transit_gateway_route_table" "jakarta_default_rt" {
  filter {
    name   = "default-association-route-table"
    values = ["true"]
  }
  filter {
    name   = "transit-gateway-id"
    values = [aws_ec2_transit_gateway.jakarta_tgw.id]
  }
}

# — Jakata TGW’s default route table & static route to Singapore —
resource "aws_ec2_transit_gateway_route" "jakarta_to_singapore" {
  transit_gateway_route_table_id    = data.aws_ec2_transit_gateway_route_table.jakarta_default_rt.id
  destination_cidr_block            = aws_vpc.singapore.cidr_block
  transit_gateway_attachment_id     = aws_ec2_transit_gateway_peering_attachment.jk_sg_peering.id
}


# Fetch Singapore TGW’s default association route table
data "aws_ec2_transit_gateway_route_table" "singapore_default_rt" {
  provider = aws.sg
  filter {
    name   = "default-association-route-table"
    values = ["true"]
  }
  filter {
    name   = "transit-gateway-id"
    values = [aws_ec2_transit_gateway.singapore_tgw.id]
  }
}

# — Singapore TGW’s default route table & static route to Jakarta —
resource "aws_ec2_transit_gateway_route" "singapore_to_jakarta" {
  provider                          = aws.sg
  transit_gateway_route_table_id     = data.aws_ec2_transit_gateway_route_table.singapore_default_rt.id
  destination_cidr_block            = aws_vpc.jakarta.cidr_block
  transit_gateway_attachment_id     = aws_ec2_transit_gateway_peering_attachment.jk_sg_peering.id
}

# ----------------------------------------
# EC2 INSTANCES FOR TESTING (NO KEY_PAIR, EC2 INSTANCE CONNECT)
# ----------------------------------------

# Jakarta: AMI lookup for Amazon Linux 2
data "aws_ami" "amzn2_jakarta" {
  most_recent = true
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
  filter {
    name   = "owner-alias"
    values = ["amazon"]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
}

resource "aws_security_group" "jakarta_ssh" {
  name        = "jakarta-ssh-sg"
  description = "Allow SSH inbound"
  vpc_id      = aws_vpc.jakarta.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = [aws_vpc.singapore.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "jakarta_test" {
  ami                    = data.aws_ami.amzn2_jakarta.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.jakarta_public.id
  vpc_security_group_ids = [aws_security_group.jakarta_ssh.id]
  tags = {
    Name = "test-ec2-jakarta"
  }
}

# Singapore: AMI lookup for Amazon Linux 2
data "aws_ami" "amzn2_singapore" {
  provider     = aws.sg
  most_recent  = true
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
  filter {
    name   = "owner-alias"
    values = ["amazon"]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
}

resource "aws_security_group" "singapore_ssh" {
  provider    = aws.sg
  name        = "singapore-ssh-sg"
  description = "Allow SSH inbound"
  vpc_id      = aws_vpc.singapore.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = [aws_vpc.jakarta.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "singapore_test" {
  provider               = aws.sg
  ami                    = data.aws_ami.amzn2_singapore.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.singapore_public.id
  vpc_security_group_ids = [aws_security_group.singapore_ssh.id]
  tags = {
    Name = "test-ec2-singapore"
  }
}