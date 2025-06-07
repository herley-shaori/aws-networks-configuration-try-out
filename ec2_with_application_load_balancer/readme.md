# 🚀 ALB with Two EC2 Instances in Jakarta (ap-southeast-3)

## 🏗️ Goal
Simulate an Application Load Balancer (ALB) in AWS Jakarta region (ap-southeast-3) with two EC2 instances, each in a different availability zone (ap-southeast-3a and ap-southeast-3b). The ALB acts as the frontend, distributing HTTP traffic to both EC2s running Apache httpd.

---

## 📝 Steps

### 1. VPC & Subnets
- Create a VPC with DNS support and hostnames enabled.
- Create two public subnets:
  - `public_a` in ap-southeast-3a
  - `public_b` in ap-southeast-3b
- Enable `map_public_ip_on_launch` for both subnets.
- Attach an Internet Gateway and associate a public route table to both subnets.

### 2. Security Groups
- **ALB Security Group**: Allows HTTP (port 80) from anywhere.
- **EC2 Security Group**: Allows HTTP (port 80) only from the ALB SG, and SSH (port 22) from anywhere.

### 3. EC2 Instances
- Launch two EC2 instances (Amazon Linux 2, t3.2xlarge):
  - One in `public_a` (ap-southeast-3a)
  - One in `public_b` (ap-southeast-3b)
- Each instance installs `httpd` and serves a unique index.html:
  - AZ A: `Hello World from AZ A`
  - AZ B: `Hello World from AZ B`

### 4. Application Load Balancer (ALB)
- Create an ALB spanning both public subnets.
- Attach the ALB security group.
- Create a target group (HTTP, port 80) with health checks on `/`.
- Register both EC2s as targets.
- Set target group draining (deregistration_delay) to 30 seconds.
- Create a listener on port 80 forwarding to the target group.

### 5. Outputs & Access
- Access the application via the ALB DNS name (see AWS Console or output).
- The ALB will round-robin requests to both EC2s, showing different "Hello World" messages depending on the backend.

---

## 🛠️ Terraform Highlights
- All resources are in `ap-southeast-3` (Jakarta).
- Public subnets, IGW, and route tables ensure EC2s are reachable.
- Security groups enforce least privilege: EC2s only accept HTTP from ALB.
- ALB target group draining is set to 30 seconds for fast deregistration.

---

## 💡 Quick Test
1. Deploy with `terraform apply -auto-approve`.
2. Find the ALB DNS name in the AWS Console (EC2 > Load Balancers) or output.
3. Open the DNS in your browser. Refresh to see responses from both AZs!