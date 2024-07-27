resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/24"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "sample-vpc"
  }
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.0.0/26"
  availability_zone = "ap-southeast-3a"
  tags = {
    Name = "private-subnet"
  }
}

