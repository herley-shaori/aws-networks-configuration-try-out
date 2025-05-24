provider "aws" {
  region = "ap-southeast-3"
}

# Determine current region and availability zone
data "aws_region" "current" {}

# Get current account ID for API Gateway policy
data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

# Create a VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "main-vpc"
  }
}

# Create a private subnet
resource "aws_subnet" "private" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = false

  tags = {
    Name = "private-subnet"
  }
}

# Security group for Lambda and VPC Endpoint
resource "aws_security_group" "lambda_sg" {
  name        = "lambda-sg"
  description = "Security group for Lambda functions and API Gateway VPC endpoint"
  vpc_id      = aws_vpc.main.id

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow all traffic from lambda SG"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }
}

# VPC Endpoint for Private API Gateway
resource "aws_vpc_endpoint" "api_gateway" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.execute-api"
  vpc_endpoint_type = "Interface"
  private_dns_enabled = true
  subnet_ids        = [aws_subnet.private.id]
  security_group_ids = [aws_security_group.lambda_sg.id]

  tags = {
    Name = "api-gateway-endpoint"
  }
}

# IAM role for Lambda execution
resource "aws_iam_role" "lambda_exec" {
  name = "lambda_exec_role"

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

# Basic execution policy for Lambda
resource "aws_iam_role_policy" "lambda_exec_policy" {
  name   = "lambda_exec_policy"
  role   = aws_iam_role.lambda_exec.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

# Package frontend Lambda inline as a zip
data "archive_file" "frontend_lambda" {
  type        = "zip"
  output_path = "frontend_lambda.zip"

  source {
    content = <<EOF
import json

def handler(event, context):
    try:
        body = {"message": "Hello from frontend Lambda!"}
        return {
            "statusCode": 200,
            "body": json.dumps(body),
            "headers": {"Content-Type": "application/json"}
        }
    except Exception:
        # Fallback to a 200 response on any error
        return {
            "statusCode": 200,
            "body": json.dumps({"message": "Hello from frontend Lambda!"}),
            "headers": {"Content-Type": "application/json"}
        }
EOF
    filename = "lambda_function.py"
  }
}

# Frontend Lambda function
resource "aws_lambda_function" "frontend" {
  function_name = "frontend-lambda"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "lambda_function.handler"
  runtime       = "python3.12"
  timeout       = 60

  filename         = data.archive_file.frontend_lambda.output_path
  source_code_hash = filebase64sha256(data.archive_file.frontend_lambda.output_path)

  vpc_config {
    subnet_ids         = [aws_subnet.private.id]
    security_group_ids = [aws_security_group.lambda_sg.id]
  }
}

# Private API Gateway
resource "aws_api_gateway_rest_api" "api" {
  name = "private-api"

  endpoint_configuration {
    types = ["PRIVATE"]
  }

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action    = "execute-api:Invoke"
        Resource  = "arn:aws:execute-api:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*/*/*/*"
        Condition = {
          StringEquals = {
            "aws:SourceVpce" = aws_vpc_endpoint.api_gateway.id
          }
        }
      }
    ]
  })
}

# Proxy resource for all paths
resource "aws_api_gateway_resource" "proxy" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "{proxy+}"
}

# Replace ANY method with POST method
resource "aws_api_gateway_method" "post_method" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.proxy.id
  http_method   = "POST"
  authorization = "NONE"
}

# Integration to frontend Lambda
resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.proxy.id
  http_method             = aws_api_gateway_method.post_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:${data.aws_region.current.name}:lambda:path/2015-03-31/functions/${aws_lambda_function.frontend.arn}/invocations"
}

# Deployment and stage
resource "aws_api_gateway_deployment" "deployment" {
  depends_on = [aws_api_gateway_integration.lambda_integration]
  rest_api_id = aws_api_gateway_rest_api.api.id
}

# Create a stage for the deployment
resource "aws_api_gateway_stage" "test" {
  stage_name    = "test"
  rest_api_id   = aws_api_gateway_rest_api.api.id
  deployment_id = aws_api_gateway_deployment.deployment.id

  # Optional: enable logging or metrics here if desired
}

# Allow API Gateway to invoke frontend Lambda
resource "aws_lambda_permission" "allow_apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.frontend.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*/*"
}

# Package backend Lambda inline as a zip
data "archive_file" "backend_lambda" {
  type        = "zip"
  output_path = "backend_lambda.zip"

  source {
    content = <<EOF
import os
import urllib3

def handler(event, context):
    api_url = os.environ.get("API_URL")
    http = urllib3.PoolManager()
    # Append a dummy path segment so the proxy resource matches
    r = http.request("POST", f"{api_url}/test")
    return {
        "statusCode": r.status,
        "body": r.data.decode('utf-8')
    }
EOF
    filename = "lambda_function.py"
  }
}

# Backend Lambda function
resource "aws_lambda_function" "backend" {
  function_name = "backend-lambda"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "lambda_function.handler"
  runtime       = "python3.12"
  timeout       = 60

  filename         = data.archive_file.backend_lambda.output_path
  source_code_hash = filebase64sha256(data.archive_file.backend_lambda.output_path)

  vpc_config {
    subnet_ids         = [aws_subnet.private.id]
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  environment {
    variables = {
      API_URL = aws_api_gateway_stage.test.invoke_url
    }
  }
}
