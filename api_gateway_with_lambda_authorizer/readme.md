

# 🛠️ API Gateway + Python Lambda Authorizer Demo

This project demonstrates how to secure an AWS API Gateway endpoint using a custom Python-based Lambda authorizer and how to dynamically invoke that endpoint from another Lambda using JWTs.


## 🔄 Static vs. Dynamic

- **Static Secret (`JWT_SECRET`)**:  
  - Remains constant and is securely stored (environment variable in Lambdas).  
  - Used by both the invoker and authorizer Lambdas to sign and verify JWTs.  
  - Never transmitted over the network.

- **Dynamic Tokens (JWTs)**:  
  - Generated on each invocation with a unique payload (e.g., `sub`, `exp`).  
  - Carried in the `Authorization: Bearer <token>` header from the client (invoker Lambda) to API Gateway.  
  - Short‑lived and change with every request.

---

## 🚀 Components

1. **Provider Configuration**  
   - AWS region: `ap-southeast-3`  

2. **IAM Role**  
   - Single IAM role (`lambda-exec-role`) for all Lambdas  
   - Attached AWS-managed policy: `AWSLambdaBasicExecutionRole`

3. **Hello World Lambda**  
   - Function name: `hello-world`  
   - Runtime: **Python 3.12**  
   - Handler returns a simple JSON with status code `200` and body `"Hello, world!"`

4. **Custom Lambda Authorizer**  
   - Function name: `lambda-authorizer`  
   - Runtime: **Python 3.12**  
   - Verifies HS256-signed JWTs using a shared secret (`JWT_SECRET`)  
   - Checks signature and `exp` (expiration) claim  
   - Returns an IAM policy (Allow/Deny) based on JWT validity

5. **API Gateway Setup**  
   - REST API name: `hello-api`  
   - Resource path: `/hello`  
   - HTTP method: `GET`  
   - Authorization: **CUSTOM** (our Lambda authorizer)  
   - Integration type: `AWS_PROXY` to the Hello World Lambda  
   - Deployment with a dedicated `aws_api_gateway_stage` resource for stage `prod`

6. **Invoker Lambda**  
   - Function name: `apigw-invoker`  
   - Runtime: **Python 3.12**  
   - Generates a fresh JWT (valid 60 seconds) using the same `JWT_SECRET`  
   - Invokes the `/hello` endpoint with `Authorization: Bearer <token>` header  
   - Returns the API response status and body

---

## 📝 Variables

- `jwt_secret`:  
  - Description: Secret key for HS256 signing/verification  
  - Default: `"mysecret"`

---

## 🔧 Deployment

1. Initialize Terraform:  
   ```bash
   terraform init
   ```
2. Apply configuration:  
   ```bash
   terraform apply
   ```
3. Note: Terraform provisions:
   - `hello-world`, `lambda-authorizer`, and `apigw-invoker` Lambdas  
   - API Gateway REST API, resource, method, integration, authorizer, stage  

---

## 🧪 Testing

1. **Invoke the Invoker Lambda Directly**  
   ```bash
   aws lambda invoke \
     --function-name apigw-invoker \
     --payload '{}' \
     response.json
   ```
2. **Check the Results**  
   - **Success**:  
     ```json
     {
       "statusCode": 200,
       "body": "Hello, world!"
     }
     ```
   - **Failure (e.g. expired token)**:  
     ```json
     {
       "errorMessage": "Unauthorized"
     }
     ```

---

## 🔄 How It Works

1. **Invoker Lambda**  
   - Uses `jwt_secret` to sign a JWT with a 1-minute expiration.  
   - Sends the token in the `Authorization` header to API Gateway.

2. **API Gateway**  
   - Receives the request at `/hello`.  
   - Triggers the **Lambda Authorizer**.

3. **Lambda Authorizer**  
   - Extracts and verifies the JWT (signature + `exp`).  
   - If valid, returns an “Allow” policy; otherwise, “Deny”.

4. **Hello World Lambda**  
   - Only executed when the authorizer returns “Allow”.  
   - Returns “Hello, world!” to the client.

---

## 🔑 Security Notes

- **Secret Management**:  
  - In production, store `jwt_secret` securely (e.g., AWS Secrets Manager or Parameter Store).  
  - Rotate secrets periodically and implement proper key-management practices.

- **Token Issuance**:  
  - Replace the invoker demo with a real “login” service or AWS Cognito for user authentication and token issuance.

---

Enjoy your secure, JWT‑powered API gateway! 🎉