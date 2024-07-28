resource "aws_route_table" "rt_a" {
  vpc_id = aws_vpc.vpc_a.id

  route {
    cidr_block                = aws_vpc.vpc_b.cidr_block
    vpc_peering_connection_id = aws_vpc_peering_connection.peering.id
  }

  tags = {
    Name = "Route Table for VPC A"
  }
}

resource "aws_route_table" "rt_b" {
  vpc_id = aws_vpc.vpc_b.id

  route {
    cidr_block                = aws_vpc.vpc_a.cidr_block
    vpc_peering_connection_id = aws_vpc_peering_connection.peering.id
  }

  tags = {
    Name = "Route Table for VPC B"
  }
}

resource "aws_route_table_association" "rta_a" {
  subnet_id      = aws_subnet.private_subnet_a.id
  route_table_id = aws_route_table.rt_a.id
}

resource "aws_route_table_association" "rta_b" {
  subnet_id      = aws_subnet.private_subnet_b.id
  route_table_id = aws_route_table.rt_b.id
}