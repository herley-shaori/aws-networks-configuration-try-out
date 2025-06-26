# 🏷️ Route53 Private Hosted Zone with EC2 Resolution

This example shows how two VPCs in the **ap-southeast-3 (Jakarta)** region can share a Route53 Private Hosted Zone so that EC2 instances resolve each other by hostname. A VPC peering connection provides network reachability.

## 🌐 Architecture
- **VPC A** `10.10.0.0/16` with a public subnet and EC2 **instance-a**
- **VPC B** `10.20.0.0/16` with a public subnet and EC2 **instance-b**
- **Peering** connection `vpc-a-b-peer` linking the VPCs
- **Route53 PHZ** `demo.internal` associated with both VPCs
- **A Records** `a.demo.internal` & `b.demo.internal` -> private IPs of the instances

The diagram is essentially:

```
instance-a (VPC A) <--> Peering <--> instance-b (VPC B)
             \__ shared Route53 Private Hosted Zone __/
```

## 🚀 Deployment
1. Initialize and apply the Terraform configuration:
   ```bash
   ./deploy.sh
   ```
   This provisions the VPCs, instances, peering connection, and Route53 zone.
2. Wait a few minutes for the EC2 instances to boot and register their DNS records.

## 🔎 Verification
After deployment connect to either EC2 instance (via SSH or Session Manager) and run the helper script included here:

```bash
cat test_dns_ping.sh
```
Copy its contents to a file on the instance and execute:

```bash
bash test_dns_ping.sh b.demo.internal   # from instance-a
bash test_dns_ping.sh a.demo.internal   # from instance-b
```

You should see successful ping replies, confirming the instances resolve each other using the private hosted zone. 🎉

## 🧹 Cleanup
When done, destroy all resources:
```bash
./destroy.sh
```

Enjoy exploring Route53 Private Hosted Zones! 😎
