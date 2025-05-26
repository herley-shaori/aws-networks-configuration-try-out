# 🚀 Cross-VPC Private DNS Resolution Demo

This tutorial demonstrates how to enable and validate private DNS resolution across two AWS VPCs using Amazon Route 53 Resolver endpoints, a forwarding rule, and VPC peering. All resources are created with Terraform.

---

## 🔍 Scenario Overview

1. **VPC A (10.0.0.0/16)**  
   - Hosts the private hosted zone `myapp.internal`  
   - Inbound Route 53 Resolver endpoint to accept DNS queries from VPC B  
   - EC2 **instance‑a** in a public subnet for ground‑truth testing

2. **VPC B (10.1.0.0/16)**  
   - Outbound Route 53 Resolver endpoint to forward queries into VPC A  
   - EC2 **instance‑b** in a public subnet for end‑to‑end testing

3. **Routing & Peering**  
   - VPC peering connection and route table entries allow traffic between subnets  
   - Security groups ensure port 53 is permitted between resolver endpoints

4. **Private Hosted Zone**  
   - `myapp.internal` with an A‑record `app.myapp.internal → 10.0.1.123` in VPC A

---

## ⚙️ Terraform Resources

- **VPCs & Subnets**: `aws_vpc` & `aws_subnet`  
- **Internet Connectivity**: `aws_internet_gateway`, `aws_route_table`, `aws_route_table_association`  
- **Resolver Endpoints**:  
  - `aws_route53_resolver_endpoint.inbound` (VPC A)  
  - `aws_route53_resolver_endpoint.outbound` (VPC B)  
- **Security Groups**:  
  - `r53_inbound_sg` allows DNS from VPC B  
  - `r53_outbound_sg` allows DNS to VPC A  
- **Route 53 Hosted Zone**: `aws_route53_zone.private`  
- **A‑Record**: `aws_route53_record.app`  
- **Forwarding Rule**: `aws_route53_resolver_rule.forward_myapp`  
- **Rule Association**: `aws_route53_resolver_rule_association.b`  
- **EC2 Instances**: `aws_instance.instance_a` & `aws_instance.instance_b` for testing  
- **VPC Peering**: `aws_vpc_peering_connection.a_to_b` and associated `aws_route` resources

---

## 🛠️ Testing Steps

### 1. Verify on **instance‑a** (VPC A)

1. **Default lookup**  
   ```bash
   dig +short app.myapp.internal
   ```  
   - **What it does**: Queries the VPC’s AmazonProvidedDNS (via `/etc/resolv.conf`).  
   - **Success (`✅`)**: Returns `10.0.1.123`.  
   - **Failure (`❌`)**: No output or error → check hosted zone, A‑record, or DHCP options.

2. **Direct inbound endpoint lookup**  
   ```bash
   dig +short app.myapp.internal @10.0.1.37
   ```  
   - **What it does**: Sends the query directly to one of the inbound resolver endpoint IPs.  
   - **Success**: Returns `10.0.1.123`.  
   - **Failure**: Timeout → inspect the inbound endpoint security group and subnet.

---

### 2. Verify on **instance‑b** (VPC B)

1. **Default lookup**  
   ```bash
   dig +short app.myapp.internal
   ```  
   - **What it does**: Uses VPC B’s DNS (10.1.0.2) which applies the forwarding rule.  
   - **Success (`✅`)**: Returns `10.0.1.123`.  
   - **Failure (`❌`)**: No output or timeout → check rule association, outbound endpoint, or SG.

2. **Direct outbound endpoint lookup**  
   ```bash
   dig +short app.myapp.internal @10.1.1.98
   dig +short app.myapp.internal @10.1.2.152
   ```  
   - **What it does**: Bypasses the built‑in resolver, querying each outbound endpoint ENI.  
   - **Success**: Returns `10.0.1.123`.  
   - **Failure**: Timeout → inspect `r53-outbound-sg`, endpoint status, and subnet routing.

---

## ✅ Expected End-to-End Result

Both **instance‑a** and **instance‑b** should return `10.0.1.123` for:

```bash
dig +short app.myapp.internal
```

This confirms that VPC B queries are forwarded through the outbound endpoint into VPC A’s inbound endpoint, and resolved by the private hosted zone.

---

## 🔧 Troubleshooting Tips

- **Security groups**: Ensure port 53 (TCP/UDP) is allowed between resolver SGs.  
- **Rule association**:  
  ```bash
  aws route53resolver list-resolver-rule-associations \
    --filters Name=VpcId,Values=<VPC_B_ID> \
    --query "ResolverRuleAssociations"
  ```  
- **Endpoint status**: Check **Status = COMPLETE** in the AWS Console under Route 53 → Resolver → Endpoints.  
- **Peering & Routes**: Confirm `aws_route` entries exist in each public route table for cross‑VPC traffic.

---

Happy testing! 🎉