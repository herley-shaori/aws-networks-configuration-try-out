resource "aws_vpc_endpoint" "ssm" {
  vpc_id             = aws_vpc.main.id
  service_name       = "com.amazonaws.ap-southeast-3.ssm"
  security_group_ids = [aws_security_group.private_sg.id]
  vpc_endpoint_type  = "Interface"
  subnet_ids         = [aws_subnet.private.id]
  tags = {
    Name = "Demo SSM"
  }
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "ssmmessages" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.ap-southeast-3.ssmmessages"
  subnet_ids          = [aws_subnet.private.id]
  security_group_ids  = [aws_security_group.private_sg.id]
  private_dns_enabled = true
  vpc_endpoint_type   = "Interface"
  tags = {
    Name = "Demo SSM"
  }
}

resource "aws_vpc_endpoint" "ec2messages" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.ap-southeast-3.ec2messages"
  subnet_ids          = [aws_subnet.private.id]
  security_group_ids  = [aws_security_group.private_sg.id]
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  tags = {
    Name = "Demo SSM"
  }
}