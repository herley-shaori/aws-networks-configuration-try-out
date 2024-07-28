resource "aws_vpc_peering_connection" "peering" {
  vpc_id      = aws_vpc.vpc_a.id
  peer_vpc_id = aws_vpc.vpc_b.id
  auto_accept = true
  tags = {
    Name = "VPC Peering between VPC A and VPC B"
  }
}