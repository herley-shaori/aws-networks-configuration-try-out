

#############################################
# Provider and Data Sources
#############################################

# Configure AWS provider for the Jakarta region
provider "aws" {
  region = "ap-southeast-3"
}

# Fetch the list of availability zones in this region.
# We'll pick the first two AZs for a two‐AZ design.
data "aws_availability_zones" "available" {
  state = "available"
}

variable "simulate_failure_az_a" {
  description = "When true, simulate an AZ A outage by skipping NAT-A and removing default route in private-A."
  type        = bool
  default     = false
}

#############################################
# VPC and Core Networking Components
#############################################

# 1) Main VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "multi-az-vpc"
  }
}

# 2) Internet Gateway (IGW) attached to the VPC
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main-igw"
  }
}

#############################################
# Subnets: Two Public, Two Private (One per AZ)
#############################################

# PUBLIC SUBNET A in AZ[0]
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true  # so instances launched here get a public IP

  tags = {
    Name = "public-subnet-a"
  }
}

# PUBLIC SUBNET B in AZ[1]
resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-b"
  }
}

# PRIVATE SUBNET A in AZ[0]
resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.101.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]
  # Instances here do NOT get public IP by default

  tags = {
    Name = "private-subnet-a"
  }
}

# PRIVATE SUBNET B in AZ[1]
resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.102.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "private-subnet-b"
  }
}

#############################################
# Route Tables and Associations
#############################################

# PUBLIC ROUTE TABLE A (for public_a)
resource "aws_route_table" "public_rt_a" {
  vpc_id = aws_vpc.main.id

  # Default route: 0.0.0.0/0 → IGW
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public-rt-a"
  }
}

# ASSOCIATE PUBLIC ROUTE TABLE A to public_a
resource "aws_route_table_association" "assoc_public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public_rt_a.id
}

# PUBLIC ROUTE TABLE B (for public_b)
resource "aws_route_table" "public_rt_b" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public-rt-b"
  }
}

# ASSOCIATE PUBLIC ROUTE TABLE B to public_b
resource "aws_route_table_association" "assoc_public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public_rt_b.id
}

#############################################
# NAT Gateways (One per Public Subnet)
#############################################

# Elastic IP for NAT Gateway A
resource "aws_eip" "nat_eip_a" {
  domain = "vpc"

  tags = {
    Name = "nat-eip-a"
  }
}

# NAT Gateway A inside public_a
resource "aws_nat_gateway" "nat_gw_a" {
  allocation_id = aws_eip.nat_eip_a.id
  subnet_id     = aws_subnet.public_a.id

  tags = {
    Name = "nat-gateway-a"
  }
}

# Elastic IP for NAT Gateway B
resource "aws_eip" "nat_eip_b" {
  domain = "vpc"

  tags = {
    Name = "nat-eip-b"
  }
}

# NAT Gateway B inside public_b
resource "aws_nat_gateway" "nat_gw_b" {
  allocation_id = aws_eip.nat_eip_b.id
  subnet_id     = aws_subnet.public_b.id

  tags = {
    Name = "nat-gateway-b"
  }
}

#############################################
# Private Route Tables (Use AZ‐Specific NAT Gateway)
#############################################

# PRIVATE ROUTE TABLE A (for private_a)
resource "aws_route_table" "private_rt_a" {
  vpc_id = aws_vpc.main.id

  # Outbound internet from private_a → NAT Gateway A
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw_a.id
  }

  tags = {
    Name = "private-rt-a"
  }
}

# ASSOCIATE PRIVATE ROUTE TABLE A to private_a
resource "aws_route_table_association" "assoc_private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private_rt_a.id
}

# PRIVATE ROUTE TABLE B (for private_b)
resource "aws_route_table" "private_rt_b" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw_b.id
  }

  tags = {
    Name = "private-rt-b"
  }
}

# ASSOCIATE PRIVATE ROUTE TABLE B to private_b
resource "aws_route_table_association" "assoc_private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private_rt_b.id
}

#############################################
# Security Groups
#############################################

# 1) Security Group for the ALB (allow inbound HTTP from anywhere)
resource "aws_security_group" "alb_sg" {
  name        = "alb-sg"
  description = "Allow inbound HTTP from anywhere"
  vpc_id      = aws_vpc.main.id

  # Inbound: HTTP on port 80 from 0.0.0.0/0
  ingress {
    description = "HTTP from Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # (Optional) If you plan to serve HTTPS, add ingress rules for port 443.

  # Outbound: allow all (so ALB can health-check EC2s, etc.)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "alb-sg"
  }
}

# 2) Security Group for EC2 Instances (allow inbound from ALB and SSH via Instance Connect)
resource "aws_security_group" "ec2_sg" {
  name        = "ec2-sg"
  description = "Allow inbound HTTP from ALB and SSH (Instance Connect)"
  vpc_id      = aws_vpc.main.id

  # Inbound: HTTP from ALB security group (port 80)
  ingress {
    description      = "Allow HTTP from ALB"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    security_groups  = [aws_security_group.alb_sg.id]
  }

  # Inbound: SSH (port 22) from anywhere (EC2 Instance Connect will use this port)
  # You might want to lock this down to your office IP in production.
  ingress {
    description = "Allow SSH for EC2 Instance Connect"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound: allow all so EC2 can reach Internet (via NAT Gateway)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ec2-sg"
  }
}

#############################################
# Application Load Balancer (ALB)
#############################################

# ALB resource spanning both public subnets
resource "aws_lb" "app_lb" {
  name               = "multi-az-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]

  # Put the ALB in both public subnets (AZ A and AZ B)
  subnets = [
    aws_subnet.public_a.id,
    aws_subnet.public_b.id
  ]

  enable_deletion_protection = false

  tags = {
    Name = "multi-az-alb"
  }
}

# ALB Target Group (HTTP on port 80) for our EC2 instances
resource "aws_lb_target_group" "web_tg" {
  name        = "web-target-group"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id

  # Health check basics
  health_check {
    protocol            = "HTTP"
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200-399"
  }

  tags = {
    Name = "web-target-group"
  }
}

# ALB Listener on port 80 forwarding to the target group
resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_tg.arn
  }
}

#############################################
# Launch Template (EC2 Configuration for Instance Connect)
#############################################

# Get the latest Amazon Linux 2 AMI ID in Jakarta region
data "aws_ami" "amazon_linux_2" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  owners = ["amazon"]
}

# Launch Template that defines EC2 details (no key_pair; using Instance Connect)
resource "aws_launch_template" "web_lt" {
  name_prefix   = "web-server-"
  image_id      = data.aws_ami.amazon_linux_2.id
  instance_type = "t3.micro"        # adjust instance type as needed
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  # No key_name is provided → enables EC2 Instance Connect usage
  # (Instance Connect pushes an SSH key to the instance only when you call the 'ec2-instance-connect send-ssh-public-key' API)

  user_data = base64encode(<<-EOF
                #!/bin/bash
                # Update and install ec2-instance-connect package (if not present)
                yum update -y
                amazon-linux-extras install -y ec2-instance-connect
                EOF
            )

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "web-server-instance"
    }
  }
}

#############################################
# Auto Scaling Group (Spread Across Both AZs)
#############################################

resource "aws_autoscaling_group" "web_asg" {
  name                      = "web-asg"
  launch_template {
    id      = aws_launch_template.web_lt.id
    version = "$Latest"
  }

  # Place instances into both private subnets, or only subnet B if simulating AZ A failure
  vpc_zone_identifier = var.simulate_failure_az_a ? [aws_subnet.private_b.id] : [aws_subnet.private_a.id, aws_subnet.private_b.id]

  min_size            = 2
  max_size            = 4
  desired_capacity    = 2

  # Attach to the ALB target group so the ALB can distribute traffic
  target_group_arns = [aws_lb_target_group.web_tg.arn]

  health_check_type         = "ELB"
  health_check_grace_period = 60

  tag {
    key                 = "Name"
    value               = "web-server-asg"
    propagate_at_launch = true
  }
}

#############################################
# Bastion Host (Public EC2 for Instance Connect)
#############################################

# Security Group allowing SSH (port 22) from anywhere (for EC2 Instance Connect)
resource "aws_security_group" "bastion_sg" {
  name        = "bastion-sg"
  description = "Allow SSH from anywhere for bastion"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH from Internet"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "bastion-sg"
  }
}

# Bastion EC2 instance in public subnet A (no key pair, using EC2 Instance Connect)
resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.amazon_linux_2.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public_a.id
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id]
  associate_public_ip_address = true

  user_data = base64encode(<<-EOF
                #!/bin/bash
                yum update -y
                amazon-linux-extras install -y ec2-instance-connect
                EOF
            )

  tags = {
    Name = "bastion-host"
  }
}

#############################################
# Outputs (Useful Information After Apply)
#############################################

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = [aws_subnet.public_a.id, aws_subnet.public_b.id]
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = [aws_subnet.private_a.id, aws_subnet.private_b.id]
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.igw.id
}

output "nat_gateway_ids" {
  description = "IDs of NAT Gateways (one per AZ)"
  value       = [aws_nat_gateway.nat_gw_a.id, aws_nat_gateway.nat_gw_b.id]
}

output "alb_dns_name" {
  description = "DNS name for the Application Load Balancer"
  value       = aws_lb.app_lb.dns_name
}

output "autoscaling_group_name" {
  description = "Name of the Auto Scaling Group"
  value       = aws_autoscaling_group.web_asg.name
}