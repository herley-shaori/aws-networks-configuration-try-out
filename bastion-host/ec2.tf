# Key Pair
resource "tls_private_key" "example" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Save the private key to the current directory
resource "local_file" "local_key_for_public_ec2" {
  content  = tls_private_key.example.private_key_pem
  filename = "${path.module}/my_key.pem"
}

# Create a new EC2 key pair
resource "aws_key_pair" "public_ec2_key_pair" {
  key_name   = "my_key"
  public_key = tls_private_key.example.public_key_openssh
}

data "aws_ami" "amazon_linux_2" {
  most_recent = true
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
  filter {
    name   = "owner-alias"
    values = ["amazon"]
  }
}

# Security Group for Public EC2
resource "aws_security_group" "public_ec2" {
  name        = "allow_ssh"
  description = "Allow SSH inbound traffic"
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
    Name = "Allow SSH for public ec2 (bastion)."
  }
}

resource "aws_security_group" "private_ec2_sg" {
  name        = "allow from public ec2"
  description = "Allow traffic only from public ec2 sg."
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Ping from public ec2."
    from_port       = 0
    to_port         = 0
    protocol        = -1
    security_groups = [aws_security_group.public_ec2.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "Allow SSH for public ec2 (bastion)."
  }
}

# EC2 Instance in Public Subnet
resource "aws_instance" "public_ec2" {
  ami                         = data.aws_ami.amazon_linux_2.id
  instance_type               = "t3.micro"
  key_name                    = aws_key_pair.public_ec2_key_pair.id
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.public_ec2.id]
  associate_public_ip_address = true
  tags = {
    Name = "Public EC2"
  }
}

# EC2 Instance in Private Subnet
resource "aws_instance" "private_ec2" {
  ami                         = data.aws_ami.amazon_linux_2.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.private.id
  associate_public_ip_address = false
  tags = {
    Name = "Private EC2"
  }
  security_groups = [aws_security_group.private_ec2_sg.id]
}