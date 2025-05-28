## 🏗 Architecture

### 🔒 Security Groups
- **Provider VPC**  
  - `provider-sg`: Ingress allows all traffic from the provider VPC CIDR and HTTP (TCP 80) from the consumer VPC CIDR; egress allows all outbound.
  - `provider-instance-sg`: Ingress allows all self-traffic (SSM agent); egress allows all outbound.
- **Consumer VPC**  
  - `consumer-sg`: Ingress allows HTTP (TCP 80) from the consumer VPC CIDR; egress allows all outbound.
  - `consumer-instance-sg`: Ingress allows all self-traffic (SSM agent); egress allows all outbound.

## 🔧 Deployment Steps

...

5. Deploy the consumer instance and test the connection to the provider's private service using the curl command.

6. **SSM VPC Endpoints**  
   We created **three** SSM interface endpoints in each VPC (for `ssm`, `ssmmessages`, and `ec2messages`), totalling **six** SSM endpoints across both VPCs.

...

**Note:** Access the EC2 instances via **AWS Systems Manager Session Manager** — no SSH keys are required.