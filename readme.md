Here’s the same README re-written with proper Markdown headings, bulleted lists, and code blocks for clarity:

# AWS Networks Configuration Try Out 🚀

This repository contains Terraform–based examples to explore and validate various AWS networking scenarios. Each folder is a self-contained project demonstrating a specific network configuration, complete with resources, routing, and connectivity tests. 🌐

---

## 📂 Folder Structure

- **vpc_peering** 🔗  
  - **Purpose:**  
    Establishes a VPC Peering Connection between two VPCs in the same AWS Region.  
  - **What Happens:**  
    - Creates two isolated VPCs, each with its own subnets, route tables, and security groups  
    - Sets up a VPC Peering Connection  
    - Updates route tables to allow cross-VPC traffic  
    - Launches EC2 instances to verify connectivity via private IP addresses 🖧

- **tgw_peering** 🌍  
  - **Purpose:**  
    Demonstrates Transit Gateway peering across two AWS Regions.  
  - **What Happens:**  
    - Provisions two AWS Transit Gateways (one in each region)  
    - Attaches VPCs to each TGW  
    - Establishes a Transit Gateway Peering Attachment  
    - Updates route tables on both sides to route traffic through the peering connection  
    - Launches EC2 instances to illustrate end-to-end, inter-region connectivity ✈️

- **ec2_communication_using_tgw** 🔄  
  - **Purpose:**  
    Shows how to route traffic between multiple VPCs using a single Transit Gateway in one region.  
  - **What Happens:**  
    - Creates a Transit Gateway and two (or more) VPCs attached to it  
    - Configures subnets, route tables, and security groups  
    - Tests connectivity by pinging between EC2 instances 📡

- **site_to_site_vpn** 🛡️  
  - **Purpose:**  
    Configures a Site-to-Site VPN connection between a VPC in AWS and an on-premises network.  
  - **What Happens:**  
    - Sets up a Virtual Private Gateway attached to a VPC  
    - Defines a Customer Gateway for the on-prem device  
    - Creates a VPN Connection (BGP/static)  
    - Configures route propagation and static routes 🔒

- **call_private_api_gateway** 🔐  
  - **Purpose:**  
    Illustrates how to invoke a Private API Gateway endpoint from within a VPC.  
  - **What Happens:**  
    - Deploys a Private API Gateway with a Lambda integration  
    - Creates an Interface VPC Endpoint for API Gateway  
    - Launches Lambda functions or EC2 instances in private subnets  
    - Configures DNS and resource policies so the API can be called securely over the VPC endpoint 🗝️

---

## 🚀 Usage

1. **Prerequisites**  
   - Install Terraform (v0.12+)  
   - Configure AWS CLI credentials  
   - Set the desired AWS Region  

2. **Initialize**  
   ```bash
   cd <folder>
   terraform init

	3.	Plan & Apply

terraform plan
terraform apply


	4.	Verify
	•	Follow the connectivity tests or example outputs in each folder’s README to confirm everything is working ✅
	5.	Cleanup

terraform destroy

	•	Destroys all resources when you’re done 🧹

⸻

Feel free to dive into any subfolder for detailed instructions and happy networking! 🎉