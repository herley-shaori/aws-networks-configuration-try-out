# Multi-AZ High Availability Network Setup with NAT Gateway & ALB

> **Goal**:  
> Build a highly available VPC inside a single AWS region (Jakarta, `ap-southeast-3`) that spans **two Availability Zones** (AZ A and AZ B).  
> - Use an **Application Load Balancer (ALB)** across both AZs.  
> - Deploy **EC2 instances** in an **Auto Scaling Group (ASG)** spanning both AZs (private subnets).  
> - Create **NAT Gateways** in each public subnet so private subnets in each AZ can egress independently.  
> - Provide a **bastion host** in a public subnet for EC2 Instance Connect (no key-pair).  
> - Toggle between “success” (both AZs healthy) and “failure” (AZ A outage) with a Terraform variable.

---

## 1. High-Level Architecture (ASCII Diagram)

```
             +---------------------------------------------------+
             |                   VPC (10.0.0.0/16)               |
             |                                                   |
  +------------------------+                         +------------------------+
  | Availability Zone A    |                         | Availability Zone B    |
  | (ap-southeast-3a)      |                         | (ap-southeast-3b)      |
  +------------------------+                         +------------------------+
      |               |                                |               |
  Public Subnet A   Private Subnet A               Public Subnet B   Private Subnet B
   (10.0.1.0/24)      (10.0.101.0/24)                (10.0.2.0/24)      (10.0.102.0/24)
      |               |                                |               |
  +-------+       +-------+                     +-------+       +-------+
  |  IGW  |       | NAT-A |                     |  IGW  |       | NAT-B |
  | (IGW) | <--   | (EIP) |                     | (IGW) | <--   | (EIP) |
  +-------+       +-------+                     +-------+       +-------+
      |               |                                |               |
      |               v                                |               v
      |         +----------------+                     |         +----------------+
      |         | Private-A RT   |                     |         | Private-B RT   |
      |         | 0.0.0.0/0 → NAT-A|                    |         | 0.0.0.0/0 → NAT-B|
      |         +----------------+                     |         +----------------+
      |               |                                |               |
      |               |                                |               |
      |           +------+        +----------------+   |           +------+        +----------------+
      |           | EC2  | <----  | ALB (HTTP → TG)|   |           | EC2  | <----  | ALB (HTTP → TG)|
      |           |(ASG) |        | Load Balancer  |   |           |(ASG) |        | Load Balancer  |
      |           +------+        +----------------+   |           +------+        +----------------+
      |               |                                |               |
      +---------------+--------------------------------+---------------+
```

Legend:  
- **IGW**: Internet Gateway for public subnet routing.  
- **Public Subnet A/B**: host NAT Gateway A/B and ALB nodes.  
- **Private Subnet A/B**: host EC2 web servers (Auto Scaling Group).  
- **NAT Gateway A/B**: provide outbound Internet for private subnets.  
- **ALB**: distributes incoming HTTP traffic across both AZs to targets in private subnets.

---

## 2. Prerequisites

1. **Terraform** (v0.12 or later) installed locally.  
2. **AWS CLI** configured with your credentials (`aws configure`), default region = `ap-southeast-3`.  
3. **SSH agent** running (`ssh-agent`) on your local workstation to forward your key for EC2 Instance Connect.  
4. Familiarity with AWS Console components (EC2, VPC, NAT Gateways, ALBs, Auto Scaling Groups).

---

## 3. Deployment Steps

### 3.1. Initialize & Deploy (Success Scenario)

1. **Initialize Terraform** (downloads providers, modules):  
   ```bash
   cd <your-terraform-directory>
   terraform init
   ```

2. **Apply Terraform (Both AZs Healthy)**  
   By default, the flag `simulate_failure_az_a` is `false`. That results in both AZs being healthy, with NAT Gateways in each AZ and one EC2 instance in each private subnet.  
   ```bash
   terraform apply
   # Confirm with "yes" when prompted
   ```

3. **Confirm Outputs**  
   After the apply completes, note the outputs:  
   - **alb_dns_name** (e.g., `multi-az-alb-1234567890.ap-southeast-3.elb.amazonaws.com`).  
   - **autoscaling_group_name** (e.g., `web-asg`).  
   - **bastion_public_ip** (find via AWS CLI or Console):  
     ```bash
     aws ec2 describe-instances \
       --filters "Name=tag:Name,Values=bastion-host" "Name=instance-state-name,Values=running" \
       --query "Reservations[].Instances[].PublicIpAddress" \
       --output text --region ap-southeast-3
     ```

4. **Verify ALB Targets**  
   - In AWS Console → EC2 → Load Balancers → select your ALB → Targets tab:  
     - Two healthy targets: one in AZ A, one in AZ B.  
   - Or via AWS CLI:  
     ```bash
     aws elbv2 describe-target-health \
       --target-group-arn $(aws elbv2 describe-target-groups \
         --names web-target-group --query "TargetGroups[0].TargetGroupArn" \
         --output text --region ap-southeast-3) \
       --query "TargetHealthDescriptions[].{Instance:Target.Id,State:TargetHealth.State,AZ:TargetHealthDescription.AvailabilityZone}" \
       --output table --region ap-southeast-3
     ```

5. **Test ALB from Local Machine**  
   Replace `<ALB_DNS>` with the actual DNS value:  
   ```bash
   curl http://<ALB_DNS>
   # Expect HTTP 200 from a web server in either AZ A or AZ B
   ```

---

## 4. SSH Access & NAT Verification

### 4.1. SSH into the Bastion Host

Establish an SSH session using EC2 Instance Connect (ensure you use `ssh -A` to forward your local SSH agent):  
```bash
ssh -A ec2-user@<BASTION_PUBLIC_IP>
# Now on the bastion in Public Subnet A (AZ A)
```

### 4.2. Retrieve Private EC2 Private IPs

From the bastion shell, run:  
```bash
aws ec2 describe-instances \
  --filters "Name=tag:aws:autoscaling:groupName,Values=web-asg" \
            "Name=instance-state-name,Values=running" \
  --query "Reservations[].Instances[].{ID:InstanceId,AZ:Placement.AvailabilityZone,PrivateIP:PrivateIpAddress}" \
  --output table --region ap-southeast-3
```
Example output:  
```
-----------------------------------------
| DescribeInstances                    |
+------------+--------------------+-----+
| InstanceId | AZ                 |PrivateIP |
+------------+--------------------+-----+
| i-0abcdef1 | ap-southeast-3a    |10.0.101.55|
| i-01234567 | ap-southeast-3b    |10.0.102.60|
+------------+--------------------+-----+
```

### 4.3. SSH into Private Subnets & Test NAT

1. **SSH into Private-A (AZ A)**  
   ```bash
   ssh ec2-user@10.0.101.55
   # On private-A instance now:
   curl -s http://ifconfig.me
   # Should return NAT-A’s public IP
   exit
   ```

2. **SSH into Private-B (AZ B)**  
   ```bash
   ssh ec2-user@10.0.102.60
   # On private-B instance now:
   curl -s http://ifconfig.me
   # Should return NAT-B’s public IP
   exit
   ```

If each returns the correct NAT Gateway IP, outbound traffic is properly routed per AZ.

---

## 5. Simulate AZ-A Failure (Failure Scenario)

1. **Re-apply Terraform with Failure Flag**  
   ```bash
   terraform apply -var="simulate_failure_az_a=true"
   # Confirm with "yes"
   ```
   - Removes **NAT Gateway A**, deletes Private-A default route, and forces the ASG to place both instances in private-B.

2. **Verify EC2 Instances Moved to AZ B**  
   On your local machine or from the bastion:  
   ```bash
   aws ec2 describe-instances \
     --filters "Name=tag:aws:autoscaling:groupName,Values=web-asg" \
               "Name=instance-state-name,Values=running" \
     --query "Reservations[].Instances[].{ID:InstanceId,AZ:Placement.AvailabilityZone,PrivateIP:PrivateIpAddress}" \
     --output table --region ap-southeast-3
   ```
   - Both instances should now reside in `ap-southeast-3b`.

3. **Test ALB Again**  
   ```bash
   curl http://<ALB_DNS>
   # Expect HTTP 200 (all traffic served by AZ B)
   ```

4. **Attempt to SSH into Private-A (AZ A)**  
   ```bash
   ssh -A ec2-user@<BASTION_PUBLIC_IP>
   ssh ec2-user@10.0.101.55
   # Fails (no route, NAT-A removed)
   exit
   ```

5. **SSH into Private-B (AZ B) & Test Egress**  
   ```bash
   ssh ec2-user@10.0.102.60
   curl -s http://ifconfig.me
   # Should return NAT-B’s public IP
   exit
   ```

Result: AZ A’s private subnet loses Internet connectivity and ASG instances, while AZ B remains fully operational. ALB continues serving requests using AZ B.

---

## 6. Revert to Success (Restore AZ-A)

To restore AZ A (NAT-A, route, ASG distribution), run:  
```bash
terraform apply -var="simulate_failure_az_a=false"
# Or simply: terraform apply
```
After completion:  
- **NAT Gateway A** and Private-A default route reappear.  
- **ASG** will rebalance, launching one instance in private-A and one in private-B.  
- **Verify**:  
  1. SSH into bastion → SSH into private-A → `curl http://ifconfig.me` (returns NAT-A IP).  
  2. SSH into private-B → `curl http://ifconfig.me` (returns NAT-B IP).  
  3. ALB shows two healthy targets (one per AZ).

---

## 7. Troubleshooting & Best Practices

1. **Terraform Validation**  
   - Ensure `simulate_failure_az_a` is declared correctly.  
   - Confirm use of `vpc_security_group_ids` in launch template.  
   - Remove any inline route in `private_rt_a` and use the conditional `aws_route`.  
   - Run `terraform fmt` to maintain tidy formatting.

2. **EC2 Instance Connect Issues**  
   - Always SSH into the bastion with `ssh -A ec2-user@<BASTION_PUBLIC_IP>`.  
   - Verify the bastion can ping private subnet IPs:  
     ```bash
     ping 10.0.101.55
     ```
   - If “Permission denied” or “Connection timed out,” confirm `ec2-instance-connect` installation in user data.

3. **ALB Target Health**  
   - ALB security group must allow inbound HTTP (port 80) from 0.0.0.0/0.  
   - EC2 security group must allow inbound HTTP from the ALB security group.  
   - Ensure web server (e.g., NGINX) is running on port 80 on each instance.

4. **Cost Considerations**  
   - Running a NAT Gateway in each AZ incurs additional hourly and data transfer charges.  
   - For reduced cost with lower availability, you may route private subnets through a single NAT Gateway, understanding it becomes a single point of failure.

---

## Conclusion

This README outlines a **professional, multi-AZ, intra-region high availability** setup using Terraform. It covers:  
- A clear, tidy ASCII diagram of the network architecture.  
- Step-by-step instructions for deploying, testing success, simulating an AZ outage, and reverting.  
- Troubleshooting guidance and cost considerations.  

Use these instructions to ensure AZ-isolated NAT Gateways, ALBs, and ASGs work together to eliminate single points of failure.  