provider "aws" {
  region = "ap-southeast-3"
}


variable "jwt_secret" {
  description = "Secret key for HS256 JWT validation"
  type        = string
  default     = "mysecret"
}

# IAM role for both Lambda functions
resource "aws_iam_role" "lambda_exec_role" {
  name               = "lambda-exec-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# Attach basic execution policy
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Package Hello World Lambda
data "archive_file" "hello" {
  type           = "zip"
  source_content_filename = "index.py"
  source_content = <<EOF
def handler(event, context):
    return {
        'statusCode': 200,
        'body': 'Hello, world!'
    }
EOF
  output_path = "${path.module}/hello.zip"
}

# Hello World Lambda function
resource "aws_lambda_function" "hello" {
  function_name = "hello-world"
  handler       = "index.handler"
  runtime       = "python3.12"
  role          = aws_iam_role.lambda_exec_role.arn
  filename      = data.archive_file.hello.output_path
  source_code_hash = data.archive_file.hello.output_base64sha256
}

# Package Lambda authorizer
data "archive_file" "authorizer" {
  type           = "zip"
  source_content_filename = "index.py"
  source_content = <<EOF
import base64, hashlib, hmac, json, os, time

def handler(event, context):
    token_header = event.get("authorizationToken")
    if not token_header or not token_header.startswith("Bearer "):
        raise Exception("Unauthorized")
    token = token_header.split(" ", 1)[1]
    header_b64, payload_b64, sig_b64 = token.split(".")
    signing_input = f"{header_b64}.{payload_b64}".encode()
    secret = os.environ["JWT_SECRET"].encode()
    expected_sig = base64.urlsafe_b64encode(hmac.new(secret, signing_input, hashlib.sha256).digest()).rstrip(b"=")
    if not hmac.compare_digest(expected_sig, sig_b64.encode()):
        raise Exception("Unauthorized")
    payload = json.loads(base64.urlsafe_b64decode(payload_b64 + "=="))
    # Optional: validate exp
    if payload.get("exp") and time.time() > payload["exp"]:
        raise Exception("Unauthorized")
    return {
        "principalId": payload.get("sub", "user"),
        "policyDocument": {
            "Version": "2012-10-17",
            "Statement": [{
                "Action": "execute-api:Invoke",
                "Effect": "Allow",
                "Resource": event.get("methodArn")
            }]
        }
    }
EOF
  output_path = "${path.module}/authorizer.zip"
}

# Lambda Authorizer function
resource "aws_lambda_function" "authorizer" {
  function_name = "lambda-authorizer"
  handler       = "index.handler"
  runtime       = "python3.12"
  role          = aws_iam_role.lambda_exec_role.arn
  filename      = data.archive_file.authorizer.output_path
  source_code_hash = data.archive_file.authorizer.output_base64sha256

  environment {
    variables = {
      JWT_SECRET = var.jwt_secret
    }
  }
}

# API Gateway REST API
resource "aws_api_gateway_rest_api" "api" {
  name = "hello-api"
}

# Define /hello resource
resource "aws_api_gateway_resource" "hello_resource" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "hello"
}

# Method with custom Lambda authorizer
resource "aws_api_gateway_method" "hello_get" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.hello_resource.id
  http_method   = "GET"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.custom.id
  api_key_required = false
}

# Integration with Hello Lambda
resource "aws_api_gateway_integration" "hello_integration" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.hello_resource.id
  http_method = aws_api_gateway_method.hello_get.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.hello.invoke_arn
}

# Permission for API Gateway to invoke Hello Lambda
resource "aws_lambda_permission" "allow_api_invoke_hello" {
  statement_id  = "AllowAPIGatewayInvokeHello"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.hello.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/GET/hello"
}

# Lambda authorizer setup
resource "aws_api_gateway_authorizer" "custom" {
  name                    = "lambda-authorizer"
  rest_api_id             = aws_api_gateway_rest_api.api.id
  authorizer_uri          = aws_lambda_function.authorizer.invoke_arn
  type                    = "TOKEN"
  identity_source         = "method.request.header.Authorization"
  authorizer_result_ttl_in_seconds = 300
}

# Permission for API Gateway to invoke Authorizer Lambda
resource "aws_lambda_permission" "allow_api_invoke_authorizer" {
  statement_id  = "AllowAPIGatewayInvokeAuthorizer"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.authorizer.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}

# Deploy the API
resource "aws_api_gateway_deployment" "deployment" {
  depends_on = [aws_api_gateway_integration.hello_integration]
  rest_api_id = aws_api_gateway_rest_api.api.id
}

resource "aws_api_gateway_stage" "prod" {
  stage_name    = "prod"
  rest_api_id   = aws_api_gateway_rest_api.api.id
  deployment_id = aws_api_gateway_deployment.deployment.id
  description   = "Production stage"
}
# Package Lambda invoker
data "archive_file" "invoker" {
  type                    = "zip"
  source_content_filename = "index.py"
  source_content = <<EOF
import os
import time
import json
import hmac
import base64
import hashlib
import urllib.request

def create_jwt(sub, secret):
    header = {'alg':'HS256','typ':'JWT'}
    payload = {'sub': sub, 'exp': int(time.time()) + 60}
    def b64encode(obj):
        return base64.urlsafe_b64encode(json.dumps(obj).encode()).rstrip(b'=').decode()
    signing_input = f"{b64encode(header)}.{b64encode(payload)}".encode()
    signature = base64.urlsafe_b64encode(hmac.new(secret.encode(), signing_input, hashlib.sha256).digest()).rstrip(b'=').decode()
    return f"{signing_input.decode()}.{signature}"

def handler(event, context):
    url = os.environ["API_URL"]
    secret = os.environ["JWT_SECRET"]
    token = create_jwt("invoker", secret)
    req = urllib.request.Request(url)
    req.add_header("Authorization", "Bearer " + token)
    with urllib.request.urlopen(req) as resp:
        body = resp.read().decode()
        status = resp.getcode()
    return {
        "statusCode": status,
        "body": body
    }
EOF
  output_path = "${path.module}/invoker.zip"
}

# Lambda Invoker function
resource "aws_lambda_function" "invoker" {
  function_name = "apigw-invoker"
  handler       = "index.handler"
  runtime       = "python3.12"
  role          = aws_iam_role.lambda_exec_role.arn
  filename      = data.archive_file.invoker.output_path
  source_code_hash = data.archive_file.invoker.output_base64sha256

  environment {
    variables = {
      API_URL    = "https://${aws_api_gateway_rest_api.api.id}.execute-api.ap-southeast-3.amazonaws.com/prod/hello"
      JWT_SECRET = var.jwt_secret
    }
  }
}