resource "aws_vpc_endpoint" "ssmmessages" {
  vpc_id              = aws_vpc.vpc_a.id
  service_name        = "com.amazonaws.ap-southeast-3.ssmmessages"
  subnet_ids          = [aws_subnet.private_subnet_a.id]
  security_group_ids  = [module.ssm-sg.security_group_id]
  private_dns_enabled = true
  vpc_endpoint_type   = "Interface"
  tags = {
    Name = "Demo SSM"
  }
}

resource "aws_vpc_endpoint" "ec2messages" {
  vpc_id              = aws_vpc.vpc_a.id
  service_name        = "com.amazonaws.ap-southeast-3.ec2messages"
  subnet_ids          = [aws_subnet.private_subnet_a.id]
  security_group_ids  = [module.ssm-sg.security_group_id]
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  tags = {
    Name = "Demo SSM"
  }
}

resource "aws_vpc_endpoint" "ssm" {
  vpc_id            = aws_vpc.vpc_a.id
  service_name      = "com.amazonaws.${var.region}.ssm"
  vpc_endpoint_type = "Interface"
  subnet_ids        = [aws_subnet.private_subnet_a.id]

  security_group_ids = [
    module.ssm-sg.security_group_id
  ]

  private_dns_enabled = true
}

module "ssm-sg" {
  source      = "terraform-aws-modules/security-group/aws"
  version     = "5.1.2"
  name        = "SSM"
  description = "Security group for SSM endpoints."
  vpc_id      = aws_vpc.vpc_a.id
  ingress_with_self = [
    {
      rule = "all-all"
    }
  ]
  ingress_with_source_security_group_id = [
    {
      from_port                = -1
      to_port                  = -1
      protocol                 = -1
      description              = "Allow traffic from EC2 A."
      source_security_group_id = module.ec2-A-sg.security_group_id
    }
  ]
  egress_with_cidr_blocks = [{ rule = "all-all" }]
}