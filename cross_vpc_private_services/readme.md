

# Cross-VPC PrivateLink HTTP Service 🚀

## 📖 Overview
This Terraform project demonstrates how to expose an HTTP service in one VPC (the **Provider VPC**) to another isolated VPC (the **Consumer VPC**) using AWS PrivateLink and an internal Network Load Balancer (NLB). It also shows how to configure Systems Manager (SSM) connectivity and bootstrap Apache on the provider instance with Internet egress.

## 🎯 Goals
1. **Isolate traffic** between two VPCs without public ingress.  
2. **Publish** a private HTTP endpoint via PrivateLink backed by an internal NLB.  
3. **Ensure** the provider EC2 instance can install and run `httpd` without compromising VPC isolation.  
4. **Enable** secure administrative access to instances via AWS Systems Manager (no public SSH).

## 🏗 Architecture
- **Provider VPC**  
  - Two subnets: one public (for package installs), one private (service endpoint).  
  - Internal Network Load Balancer (NLB) fronting a web server.  
  - VPC Endpoint Service (PrivateLink) exposing the NLB.  
  - SSM Interface Endpoints + IAM role for agent connectivity.  
- **Consumer VPC**  
  - Two private subnets.  
  - Interface VPC Endpoint pointing to the PrivateLink service.  
  - SSM Interface Endpoints + IAM role for agent connectivity.  
  - Test EC2 instance without public IP (SSM-only access).

## 🔧 Deployment Steps
1. **Bootstrap provider instance**  
   - Public subnet + IGW allow `yum install httpd`.  
   - User data installs Apache and publishes `index.html`.  
2. **Health-check & target registration**  
   - The NLB runs TCP health checks on port 80.  
   - Provider instance passes and is marked **Healthy**.  
3. **Create PrivateLink service**  
   - An `aws_vpc_endpoint_service` wraps the internal NLB.  
4. **Consumer side configuration**  
   - Deploy an Interface VPC Endpoint to the PrivateLink service.  
   - Resolve the endpoint DNS (e.g. `vpce-0497d7678...amazonaws.com`).  
5. **Validation**  
   - From the consumer EC2 (via SSM):  
     ```bash
     curl -I http://<vpce-endpoint-dns>
     # → HTTP/1.1 200 OK
     curl http://<vpce-endpoint-dns>
     # → Hello from provider
     ```

## ✅ Results
- **Secure, private connectivity** over AWS network fabric.  
- **No public-facing load balancer** or instance.  
- **SSM-only access** for management.  
- **Repeatable infrastructure** using Terraform.

## 🤝 Feedback
For questions or improvements, feel free to open an issue or pull request!