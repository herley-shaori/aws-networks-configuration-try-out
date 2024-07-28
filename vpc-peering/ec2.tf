module "ec2-A-sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "5.1.2"
  name    = "EC2 Instance A"
  vpc_id  = aws_vpc.vpc_a.id
  ingress_with_self = [
    { rule = "all-all", description = "Allow traffic from within itself." }
  ]
  ingress_with_source_security_group_id = [
    {
      from_port : -1
      to_port : -1
      protocol : -1
      source_security_group_id : module.ssm-sg.security_group_id
      description : "Allow traffic from SSM."
    }
  ]
  egress_with_cidr_blocks = [{ rule = "all-all", description = "Allow traffic to the world." }]
}

module "ec2-B-sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "5.1.2"
  name    = "EC2 Instance B"
  vpc_id  = aws_vpc.vpc_b.id
  ingress_with_self = [
    { rule = "all-all", description = "Allow traffic from within itself." }
  ]
  ingress_with_source_security_group_id = [
    {
      from_port : -1
      to_port : -1
      protocol : -1
      source_security_group_id : module.ec2-A-sg.security_group_id
      description : "Allow traffic from EC2 A."
    }
  ]
  egress_with_cidr_blocks = [{ rule = "all-all", description = "Allow traffic to the world." }]
  depends_on              = [aws_vpc_peering_connection.peering]
}

module "ec2_instance_a" {
  source                 = "terraform-aws-modules/ec2-instance/aws"
  name                   = "A"
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = "t3.micro"
  vpc_security_group_ids = [module.ec2-A-sg.security_group_id]
  subnet_id              = aws_subnet.private_subnet_a.id
  iam_instance_profile   = aws_iam_instance_profile.ssm_profile.name
}

module "ec2_instance_b" {
  source                 = "terraform-aws-modules/ec2-instance/aws"
  name                   = "B"
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = "t3.micro"
  vpc_security_group_ids = [module.ec2-B-sg.security_group_id]
  subnet_id              = aws_subnet.private_subnet_b.id
  depends_on             = [module.ec2-B-sg]
}

