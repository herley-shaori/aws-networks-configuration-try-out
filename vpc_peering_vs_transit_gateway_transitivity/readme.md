

# VPC Peering vs Transit Gateway Transitivity Lab 🚀

This lab demonstrates the difference between non-transitive VPC Peering and hub‑and‑spoke connectivity using an AWS Transit Gateway. By the end, you’ll understand why peering doesn’t scale for many VPCs and how a Transit Gateway solves that.

---

## 🎯 Goal
- Connect **VPC A**, **VPC B**, and **VPC C**  
- Show that **VPC Peering** between A↔B and B↔C allows A↔B and B↔C but **NOT** A↔C  
- Switch to **Transit Gateway** mode and show full mesh connectivity (A↔B, B↔C, A↔C)  

---

## 🔧 Prerequisites
- **Terraform** ≥ 1.2  
- **AWS CLI** configured for `ap-southeast-3`  
- IAM user with rights to create VPCs, EC2, TGW, IAM roles, etc.

---

## 🏗️ Architecture Overview
1. **Three VPCs** (A, B, C) each with:
   - CIDR blocks:  
     - A: `10.0.0.0/16`  
     - B: `10.1.0.0/16`  
     - C: `10.2.0.0/16`  
   - Public Subnet `/24` in AZ `ap-southeast-3a`  
   - Internet Gateway  
2. **Security Groups** (`allow-icmp-http-<A|B|C>`) permitting:
   - ICMP (ping)  
   - HTTP (port 80)  
   - SSH (port 22)  
3. **Default NACLs** are left unchanged (allow all traffic).  
4. **EC2 Instances** in each public subnet (no static keypair; uses SSM and/or EC2 Instance Connect).  
5. **VPC Peering** connections for A↔B and B↔C.  
6. **Transit Gateway** attachments for A, B, and C with a single TGW route table.  

---

## ⚙️ Key Variables
- `connection_mode` (string):  
  - `"peering"` – enable only the peering routes  
  - `"tgw"`     – enable only the Transit Gateway routes  
- **Default**: `peering`

---

## 🚀 Deployment Steps

1. **Initialize Terraform**  
   ```bash
   cd vpc_peering_vs_transit_gateway_transitivity
   terraform init
   ```

2. **Apply in Peering Mode** (non‑transitive)  
   ```bash
   terraform apply -var="connection_mode=peering" -auto-approve
   ```
   - ✅ A↔B  |  ❌ A↔C  

3. **Apply in Transit Gateway Mode** (transitive)  
   ```bash
   terraform apply -var="connection_mode=tgw" -auto-approve
   ```
   - ✅ A↔B  |  ✅ A↔C  

---

## 🔗 Connecting to EC2 Instances

### Option A: Session Manager (recommended)
1. Ensure EC2 role has `AmazonSSMManagedInstanceCore` attached.
2. Start session:
   ```bash
   aws ssm start-session --target <instance-id> --region ap-southeast-3
   ```

### Option B: EC2 Instance Connect (SSH)
1. Open SSH port in SG (port 22 from your IP).  
2. Push your public key:
   ```bash
   aws ec2-instance-connect send-ssh-public-key \
     --instance-id <id> \
     --availability-zone ap-southeast-3a \
     --instance-os-user ec2-user \
     --ssh-public-key file://~/.ssh/id_rsa.pub
   ```
3. SSH in:
   ```bash
   ssh ec2-user@<public-ip>
   ```

---

## 🧪 Testing Connectivity

From **Instance A** shell:

```bash
# Replace with actual private IPs:
export IP_B=10.1.1.x
export IP_C=10.2.1.y

# 1) Test A→B:
ping -c 4 $IP_B

# 2) Test A→C:
ping -c 4 $IP_C
```

- **Peering mode**: first ping succeeds, second fails.  
- **TGW mode**: both pings succeed.  

### HTTP Test (TGW mode)
On **Instance C**:
```bash
sudo yum install -y httpd
sudo systemctl enable --now httpd
echo "Hello from C" | sudo tee /var/www/html/index.html
```
Back on **Instance A**:
```bash
curl http://$IP_C
# Should return "Hello from C"
```

---

## 🎉 Cleanup
```bash
terraform destroy -var="connection_mode=tgw" -auto-approve
```

---

👍 Congratulations! You’ve experienced firsthand the scaling limits of VPC Peering and the power of AWS Transit Gateway transitive routing.