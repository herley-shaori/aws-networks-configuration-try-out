resource "aws_vpc" "vpc_a" {
  cidr_block           = "10.0.0.0/24"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "VPC A"
  }
}

resource "aws_vpc" "vpc_b" {
  cidr_block           = "10.0.1.0/24"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "VPC B"
  }
}