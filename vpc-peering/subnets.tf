resource "aws_subnet" "private_subnet_a" {
  vpc_id     = aws_vpc.vpc_a.id
  cidr_block = "10.0.0.0/25"

  tags = {
    Name = "Private Subnet A"
  }
}

resource "aws_subnet" "private_subnet_b" {
  vpc_id     = aws_vpc.vpc_b.id
  cidr_block = "10.0.1.0/25"

  tags = {
    Name = "Private Subnet B"
  }
}