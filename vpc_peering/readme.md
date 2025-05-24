# VPC Peering Demo 🚀

This repository shows how to peer two AWS VPCs (A and B), each with a tiny public subnet and an EC2 “test” host, and then verify connectivity and isolation.  

---

## 📦 Architecture

┌──────────────┐         Peering          ┌──────────────┐
│   VPC A      │◀────────────────────────▶│   VPC B      │
│ CIDR: 10.0.0.0/27 │                    │ CIDR: 10.0.0.32/27 │
│ ┌──────────┐ │                    │ ┌──────────┐ │
│ │ Public   │ │                    │ │ Public   │ │
│ │ Subnet   │ │                    │ │ Subnet   │ │
│ │ ( /28 )  │ │                    │ │ ( /28 )  │ │
│ └──────────┘ │                    │ └──────────┘ │
│   ┌───────┐  │                    │   ┌───────┐  │
│   │ EC2 A │  │                    │   │ EC2 B │  │
│   └───────┘  │                    │   └───────┘  │
└──────────────┘                    └──────────────┘

- **VPC A**  
  - CIDR: `10.0.0.0/27`  
  - Public Subnet: `10.0.0.0/28`  
  - SG “A-sg” allows all traffic **only** from VPC B’s CIDR.  
- **VPC B**  
  - CIDR: `10.0.0.32/27`  
  - Public Subnet: `10.0.0.32/28`  
  - SG “B-sg” allows all traffic **only** from VPC A’s CIDR.  
- **Peering Connection** named `A-B-peering`  
- **Public Route Tables** per VPC, each with a `0.0.0.0/0 → IGW` route.  
- **Cross-VPC Routes** in each RT pointing to the peer’s CIDR via the peering connection.

---

## 🛠️ Deployment

1. **Initialize Terraform**  
   ```bash
   terraform init

	2.	Apply configuration

terraform apply -auto-approve



You’ll see two VPCs, subnets, IGWs, route tables, EC2 instances, security groups, and the peering connection all come up.

⸻

🔍 Testing Connectivity
	1.	Login to EC2 A
	•	Via SSM Session Manager or EC2 Instance Connect.
	2.	Ping EC2 B’s private IP (e.g. 10.0.0.34):

ping -c 4 10.0.0.34

	•	✅ Should succeed because SG A-sg allows VPC B CIDR and routes exist.

	3.	Ping EC2 A’s private IP from EC2 B:

ping -c 4 10.0.0.10

	•	✅ Should also succeed if both SGs and cross-routes are in place.

	4.	Prove isolation
	•	Remove or comment out the aws_route.B_to_A resource in main.tf (or delete the corresponding SG ingress rule), then:

terraform apply -auto-approve


	•	Try ping again:

ping -c 4 10.0.0.10

	•	❌ Should now fail, demonstrating how breaking a route or SG blocks traffic.

⸻

🧹 Cleanup

When you’re done:

terraform destroy -auto-approve


⸻

🙌 Acknowledgments

Built with Terraform and ❤️ by your friendly AWS DevOps engineer/user.