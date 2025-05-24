# 🛠️ TGW Peering Simulation with Terraform

Welcome! This project demonstrates how to simulate AWS Transit Gateway (TGW)–based connectivity between two VPCs in Jakarta (ap-southeast-3) using Terraform.  

---

## 🎯 Objectives

1. **Create two public VPCs** (VPC A and VPC B)  
2. **Launch one EC2 instance** in each VPC, in a public subnet with auto-assigned public IP  
3. **Deploy a single Transit Gateway (TGW)** and attach both VPCs to it  
4. **Verify end-to-end connectivity** between the two EC2s (ping over the TGW path)  
5. **Introduce a simple toggle** (`enable_tgw_connection`) to connect or disconnect the TGW routes  

---

## 📋 What the Terraform (`main.tf`) Does

1. **Providers & Data Sources**  
   - Sets AWS as the provider in Jakarta  
   - Retrieves account, region, AZ, and AMI details  

2. **Networking Setup**  
   - Creates **VPC A** (`10.0.0.0/16`) and **VPC B** (`10.1.0.0/16`)  
   - Adds one **public subnet** per VPC, with `map_public_ip_on_launch = true`  
   - Attaches an **Internet Gateway** to each VPC  
   - Builds a **public route table** per VPC with:
     - Default route (`0.0.0.0/0 → IGW`)
     - (Optionally) TGW route when `enable_tgw_connection = true`  

3. **Transit Gateway Deployment**  
   - Creates a single **TGW** resource  
   - Fetches its **default route table** via data source  
   - Attaches both VPCs to the TGW  

4. **Routing Over TGW**  
   - **VPC side**: Adds two `aws_route` resources to point `10.1.0.0/16 ↔ 10.0.0.0/16` through the TGW  
   - **TGW side**: Adds two `aws_ec2_transit_gateway_route` resources for the reverse directions  

5. **EC2 Instances & Security**  
   - Launches one **t3.micro** Amazon Linux 2 instance in each subnet  
   - Assigns a **public IP** so you can use **EC2 Instance Connect** (no SSH key needed)  
   - Configures security groups to allow **ICMP** (ping) and **SSH (TCP 22)** from anywhere  

---

## 🔄 Connect / Disconnect Switch

We add a Terraform variable:

```hcl
variable "enable_tgw_connection" {
  description = "Toggle TGW connectivity between VPC A and VPC B"
  type        = bool
  default     = true
}

	•	When set to true (✅), all TGW routes are created and the two EC2s can ping each other via the Transit Gateway.
	•	When set to false (❌), those routes are omitted, effectively “disconnecting” VPC A and VPC B while preserving all other infrastructure.

# Connect the TGW path
terraform apply -var="enable_tgw_connection=true"

# Disconnect the TGW path
terraform apply -var="enable_tgw_connection=false"