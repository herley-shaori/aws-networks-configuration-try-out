AWS Networks Configuration Try Out 🚀

This repository contains Terraform-based examples to explore and validate various AWS networking scenarios. Each folder is a self-contained project demonstrating a specific network configuration, complete with resources, routing, and connectivity tests. 🌐

Folder Structure 📂
	•	vpc_peering 🔗
	•	Purpose: Establishes a VPC Peering Connection between two VPCs in the same AWS Region.
	•	What Happens: Creates two isolated VPCs, each with its own subnets, route tables, and security groups. It then configures a VPC Peering Connection, updates route tables to allow cross-VPC traffic, and launches EC2 instances to verify connectivity via private IP addresses. 🖧
	•	tgw_peering 🌍
	•	Purpose: Demonstrates Transit Gateway peering across two AWS Regions.
	•	What Happens: Provisions two AWS Transit Gateways (one in each region), attaches VPCs to each TGW, and establishes a Transit Gateway Peering Attachment. Route tables are updated on both sides to route traffic through the peering connection, enabling inter-region VPC communication. Example EC2 instances illustrate end-to-end connectivity. ✈️
	•	ec2_communication_using_tgw 🔄
	•	Purpose: Shows how to route traffic between multiple VPCs using a single Transit Gateway in one region.
	•	What Happens: Creates a Transit Gateway and two or more VPCs, each attached to the TGW. Subnets, route tables, and security groups are configured so that EC2 instances in different VPCs can communicate through the Transit Gateway. Connectivity is tested by pinging between instances. 📡
	•	site_to_site_vpn 🛡️
	•	Purpose: Configures a Site-to-Site VPN connection between a VPC in AWS and an on-premises network.
	•	What Happens: Sets up a Virtual Private Gateway attached to a VPC, a Customer Gateway representing the on-premises device, and a VPN Connection between them. Route propagation and static routes are configured so on-premises traffic can reach AWS resources. Sample BGP/static routing options are demonstrated. 🔒
	•	call_private_api_gateway 🔐
	•	Purpose: Illustrates how to invoke a Private API Gateway endpoint from within a VPC.
	•	What Happens: Deploys a Private API Gateway with a Lambda integration, creates an Interface VPC Endpoint for API Gateway, and launches Lambda functions or EC2 instances in private subnets. DNS and resource policies are configured so that the API can be called securely over the VPC endpoint without exposing it publicly. 🗝️

Usage 🚀
	1.	Prerequisites:
	•	Install Terraform (v0.12+)
	•	Configure AWS CLI credentials
	•	Set the desired AWS Region
	2.	Initialize:

cd <folder>
terraform init


	3.	Plan & Apply:

terraform plan
terraform apply


	4.	Verify:
Follow the tests or outputs in each folder’s README to confirm proper connectivity. ✅

	5.	Cleanup:

terraform destroy

Destroy resources when done. 🧹

⸻

Feel free to navigate into each folder for more details and happy networking! 🎉