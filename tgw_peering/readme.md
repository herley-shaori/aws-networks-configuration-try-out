# AWS Transit Gateway Peering: Jakarta ↔ Singapore 🌏

This repository demonstrates how to set up a cross-region Transit Gateway (TGW) peering between two VPCs—one in Jakarta (`ap-southeast-3`) and one in Singapore (`ap-southeast-1`)—using Terraform. You’ll spin up public subnets, internet gateways, route tables, security groups, and EC2 instances to verify private-IP connectivity across regions.

---

## 🔧 Prerequisites

- Terraform >= 1.0  
- AWS CLI configured with access to both **ap-southeast-3** and **ap-southeast-1**  
- AWS account with permissions to create VPCs, TGWs, EC2, IAM, etc.

---

## 🚧 Resources Overview

1. **VPCs & Public Subnets**  
   - **Jakarta VPC** (`10.0.0.0/16`) + Public Subnet (`10.0.1.0/24`)  
   - **Singapore VPC** (`10.1.0.0/16`) + Public Subnet (`10.1.1.0/24`)  

2. **Internet Gateways & Route Tables**  
   - IGW attached to each VPC  
   - Public Route Tables with:  
     - **0.0.0.0/0 → IGW**  
     - **Peer VPC CIDR → Local TGW**

3. **Transit Gateways & Attachments**  
   - **Jakarta TGW** & **Singapore TGW**  
   - One **VPC Attachment** per TGW (to the public subnet)  

4. **TGW Peering Attachment**  
   - **Requester**: Jakarta TGW → Singapore TGW  
   - **Accepter**: Singapore TGW accepts the peering  

5. **TGW Route Configuration**  
   - Fetch each TGW’s **default association route table**  
   - Create **static routes**:  
     - Jakarta TGW RT: `10.1.0.0/16 → Peering Attachment`  
     - Singapore TGW RT: `10.0.0.0/16 → Peering Attachment`  

6. **Security Groups**  
   - Allow **SSH (TCP/22)** from anywhere  
   - Allow **all protocols** from the peer VPC CIDR  
   - Egress open to **0.0.0.0/0**

7. **EC2 Test Instances**  
   - Amazon Linux 2 in each VPC  
   - No keypairs—use EC2 Instance Connect  

---

## 🚀 Deployment Steps

```bash
# 1. Initialize Terraform
terraform init

# 2. Preview
terraform plan

# 3. Apply
terraform apply

This will provision all resources in both regions.

⸻

🧪 Validation & Testing
	1.	Verify TGW Peering

aws ec2 describe-transit-gateway-peering-attachments \
  --transit-gateway-attachment-ids tgw-attach-09e1dd3f85642416c \
  --query 'TransitGatewayPeeringAttachments[0].State'
# should return "available"


	2.	Check TGW Route Tables

# Jakarta RT
aws ec2 describe-transit-gateway-routes \
  --transit-gateway-route-table-id <Jakarta-RTB-ID> \
  --filters Name=destination-cidr-block,Values=10.1.0.0/16
# Singapore RT
aws ec2 describe-transit-gateway-routes \
  --region ap-southeast-1 \
  --transit-gateway-route-table-id <Singapore-RTB-ID> \
  --filters Name=destination-cidr-block,Values=10.0.0.0/16


	3.	Ping Private IP
	•	SSH into Jakarta EC2 via Instance Connect
	•	Run:

ping -c 4 <Singapore-EC2-Private-IP>


	•	You should see replies! 🎉

⸻

🗑️ Cleanup

terraform destroy


⸻

🤝 Notes & Best Practices
	•	We use default association route tables for simplicity; for production, consider custom TGW RTBs.
	•	Static TGW routes ensure explicit control—dynamic propagation is also available via the Propagations tab.
	•	Security Groups lock down access to only necessary traffic.

Happy Peering! 🚀🔗

