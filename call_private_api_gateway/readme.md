
# Private API Gateway + Lambda in a VPC

This Terraform setup creates a private REST API backed by two Lambda functions (frontend & backend), all running inside a VPC. The Lambdas share a single security group and communicate via an API Gateway VPC endpoint. Finally, we verify that the frontend Lambda always returns a 200.

---

## 1. Provider & Data Lookups

1. **AWS Provider**  
   Sets the region to `ap-southeast-3`.

2. **Data Sources**  
   - `aws_region.current` : Fetches the current AWS region.  
   - `aws_caller_identity.current` : Retrieves your AWS account ID (for policy ARNs).  
   - `aws_availability_zones.available` : Lists AZs in the region.

---

## 2. Networking

3. **VPC** (`aws_vpc.main`)  
   - CIDR: `10.0.0.0/16`  
   - DNS support + hostnames enabled.

4. **Private Subnet** (`aws_subnet.private`)  
   - CIDR: `10.0.1.0/24`  
   - No public IPs.

5. **Security Group** (`aws_security_group.lambda_sg`)  
   - Applied to both Lambdas & the VPC endpoint.  
   - **Egress**: allow all outbound.  
   - **Ingress**: allow all traffic _within_ this SG (so Lambdas ↔ API Gateway endpoint can communicate freely).

6. **VPC Endpoint for API Gateway** (`aws_vpc_endpoint.api_gateway`)  
   - Service: `com.amazonaws.<region>.execute-api` (private).  
   - Interface endpoint in the private subnet.  
   - **Private DNS enabled** so the standard API hostname resolves to the endpoint.

---

## 3. IAM for Lambdas

7. **Lambda Execution Role** (`aws_iam_role.lambda_exec`)  
   - Trusts the Lambda service.

8. **Inline Policy** (`aws_iam_role_policy.lambda_exec_policy`)  
   - Allows CloudWatch Logs.  
   - Permits EC2 ENI operations (`CreateNetworkInterface`, etc.) for VPC access.

---

## 4. Frontend Lambda Setup

9. **Package Code** (`data.archive_file.frontend_lambda`)  
   - Inlines a Python handler that always returns `200` with a JSON message.

10. **Lambda Function** (`aws_lambda_function.frontend`)  
    - Uses the packaged ZIP.  
    - Runtime: Python 3.12, timeout 60s.  
    - VPC-configured: private subnet + shared SG.

---

## 5. Private API Gateway

11. **Create REST API** (`aws_api_gateway_rest_api.api`)  
    - **PRIVATE** endpoint.  
    - **Resource Policy** limits calls to your VPC endpoint (via `aws:SourceVpce`).

12. **Proxy Resource** (`/{proxy+}`)  
    - Catches all paths under the root.

13. **POST Method** (`aws_api_gateway_method.post_method`)  
    - Defines `POST` on the proxy resource (no auth).

14. **Integration** (`aws_api_gateway_integration.lambda_integration`)  
    - **AWS_PROXY** integration pointing to the frontend Lambda via the full ARN path.

15. **Deployment & Stage**  
    - `aws_api_gateway_deployment.deployment` (depends on the integration).  
    - `aws_api_gateway_stage.test` publishes it under the `test` stage.

16. **Lambda Permission** (`aws_lambda_permission.allow_apigw`)  
    - Grants API Gateway the right to invoke the frontend Lambda at `*/*/*` for the sake of simplicity.

---

## 6. Backend Lambda Setup

17. **Package Code** (`data.archive_file.backend_lambda`)  
    - Python handler calls the frontend API’s invoke URL (appends `/test` so it matches the proxy).

18. **Lambda Function** (`aws_lambda_function.backend`)  
    - Same VPC config and SG as the frontend.  
    - Exposes an `API_URL` environment variable set to `stage.invoke_url`.

---

## 7. Verification

Once everything is applied, invoking the frontend Lambda directly (e.g. via the console **Test** tab) returns:

```json
{
  "statusCode": 200,
  "body": "{\"message\": \"Hello from frontend Lambda!\"}"
}

This confirms that:
	•	The Lambda code always returns a 200.
	•	The private API Gateway integration and VPC endpoint are correctly routing calls into your VPC.

👍 All set! You now have an internally-accessible API backed by Lambdas in a private subnet, with full VPC-endpoint security and logging enabled.