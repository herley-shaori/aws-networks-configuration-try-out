

# EC2 Access Using SSM and KMS Encryption

This Terraform configuration provisions a private EC2 instance that can be accessed via AWS Systems Manager (SSM) without a public IP, with the root volume encrypted using a customer-managed KMS key. 

## 🔍 Overview
- **VPC Setup**: Creates a VPC with DNS support and hostnames enabled.
- **Subnets**: Provisions two private subnets across availability zones.
- **SSM IAM Role**: Defines an IAM role and instance profile for SSM managed instances.
- **VPC Endpoints**: Sets up interface endpoints for SSM services (SSM, EC2 Messages, SSM Messages).
- **KMS Encryption**: Looks up an existing KMS alias `alias/use-case-key` to encrypt the root volume.
- **EC2 Instance**: Launches a t3.micro Amazon Linux 2 instance in a private subnet.
- **Security Groups**: Configures security groups to allow internal traffic and SSM endpoint communication.
- **Outputs**: Exposes instance ID and private IP.

## ⚙️ Prerequisites
- Terraform v1.x
- AWS CLI configured with appropriate permissions
- Existing KMS key with alias `alias/use-case-key`
- AWS region set to `ap-southeast-3` by default

## 📝 Variables
| Name   | Description | Default         |
|--------|-------------|-----------------|
| region | AWS region  | `ap-southeast-3`|

## 📦 Resources

### Provider & Region
- Uses the AWS provider and sets the region from `var.region`.

### VPC & Subnets
- **aws_vpc.main**: Creates a VPC (`10.0.0.0/16`) with DNS support.
- **aws_subnet.private**: Two private subnets in separate AZs.

### AMI & KMS Lookup
- **aws_ami.amazon_linux2**: Fetches the latest Amazon Linux 2 AMI.
- **aws_kms_alias.use_case_key**: References an existing customer-managed KMS alias `alias/use-case-key`. **Ensure you create the KMS key and alias beforehand**, as Terraform will look up this alias to encrypt the EC2 instance’s root volume.

### IAM Role & Instance Profile
- **aws_iam_role.ssm_managed_instance**: Role for EC2 to assume for SSM.
- **aws_iam_role_policy_attachment.ssm_core**: Attaches `AmazonSSMManagedInstanceCore`.
- **aws_iam_instance_profile.ssm_profile**: Instance profile for EC2.

### Security Groups
- **aws_security_group.instance_sg**: Used by both the EC2 instance and the SSM VPC interface endpoints.  
  - **Ingress (self)**: Allows all protocols from other members of the same security group, enabling secure communication between the EC2 instance and SSM endpoints.  
  - **Egress (0.0.0.0/0)**: Allows all outbound traffic so the instance can reach AWS SSM services through the interface endpoints without requiring Internet or NAT.

- **aws_security_group.ssm_sg**: (Optional) Defines rules for intra-VPC traffic and SSM endpoint communication.  
  - **Ingress (self & VPC CIDR)**: Permits all traffic from within the security group and the VPC CIDR block, ensuring services in the VPC can communicate with each other and the SSM endpoints.  
  - **Egress (0.0.0.0/0)**: Allows all outbound traffic for any additional calls (e.g., CloudWatch logs).

### VPC Endpoints
- **aws_vpc_endpoint.ssm_eps**: Interface endpoints for `ssm`, `ssmmessages`, `ec2messages`.

### EC2 Instance
- **aws_instance.private_ssm**:
  - Private instance without public IP.
  - Uses IAM profile and security group.
  - Encrypted root volume (gp3, 8 GB): Uses the customer-managed KMS key to encrypt all data at rest, ensuring that the root disk cannot be accessed or decrypted without proper IAM and KMS permissions. This enhances data security, meets compliance requirements, and protects against unauthorized access if the underlying hardware is compromised.

## 🚀 Outputs
- `instance_id`: ID of the EC2 instance.
- `instance_private_ip`: Private IP address of the instance.

## 📖 Usage
1. Run `terraform init`.
2. Run `terraform apply` and confirm.
3. Note the outputs and start an SSM session:
   ```bash
   aws ssm start-session --target $(terraform output -raw instance_id)
   ```