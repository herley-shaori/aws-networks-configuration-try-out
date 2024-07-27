resource "aws_security_group" "private_sg" {
  vpc_id = aws_vpc.main.id
  name   = "private-sg"
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
    description = "Allow traffic from self."
  }

  tags = {
    Name = "private-sg"
  }
}