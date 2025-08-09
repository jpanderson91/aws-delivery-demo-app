# Terraform Configuration Template

# Provider configuration
terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
}

# AWS Provider
provider "aws" {
  region = var.aws_region
  profile = var.aws_profile

  default_tags {
    tags = {
      Project            = var.project_name
      Environment        = var.environment
      ManagedBy          = "Terraform"
      Owner              = var.owner
  CostCenter         = var.cost_center
    }
  }
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Random suffix for globally unique resources
resource "random_id" "suffix" {
  byte_length = 4
}

# Local values for consistent naming
locals {
  # Naming convention: {project}-{environment}-{service}-{random}
  name_prefix = "${var.project_name}-${var.environment}"

  # Resource names with random suffix for global uniqueness
  bucket_name    = "${local.name_prefix}-artifacts-${random_id.suffix.hex}"
  lambda_prefix  = "${local.name_prefix}-lambda"

  # Common tags for all resources
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Owner       = var.owner
    CostCenter  = var.cost_center
  }
}

# S3 bucket for artifacts (optional, not used directly in this minimal stack)
resource "aws_s3_bucket" "artifacts" {
  bucket = local.bucket_name
  tags   = local.common_tags
}

# DynamoDB Table for customers
resource "aws_dynamodb_table" "customers" {
  name         = "${local.name_prefix}-customers"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "customer_id"

  attribute {
    name = "customer_id"
    type = "S"
  }

  tags = local.common_tags

  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }
}

# Store the table name in SSM Parameter for the Lambda to read
resource "aws_ssm_parameter" "customers_table_name" {
  name  = "/demo-app/dynamodb/table-name"
  type  = "String"
  value = aws_dynamodb_table.customers.name
  tags  = local.common_tags
}

# Package Lambda from source using archive_file
data "archive_file" "customer_lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/../src/lambda/customer_api.py"
  output_path = "${path.module}/build/customer_api.zip"
}

# IAM role for Lambda execution
data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_exec" {
  name               = "${local.lambda_prefix}-exec-${random_id.suffix.hex}"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
  tags               = local.common_tags
}

data "aws_iam_policy_document" "lambda_policy" {
  statement {
    sid     = "DynamoDBAccess"
    actions = [
      "dynamodb:PutItem",
      "dynamodb:GetItem",
      "dynamodb:UpdateItem",
      "dynamodb:Scan",
      "dynamodb:Query"
    ]
    resources = [aws_dynamodb_table.customers.arn]
  }
  statement {
    sid     = "SSMGetParameter"
    actions = ["ssm:GetParameter"]
    resources = [
      "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/demo-app/dynamodb/table-name"
    ]
  }
  statement {
    sid     = "Logs"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "lambda_inline" {
  name   = "${local.lambda_prefix}-policy-${random_id.suffix.hex}"
  role   = aws_iam_role.lambda_exec.id
  policy = data.aws_iam_policy_document.lambda_policy.json
}

# Lambda Function
resource "aws_lambda_function" "customer_api" {
  function_name = "${local.lambda_prefix}-customer-api"
  filename      = data.archive_file.customer_lambda_zip.output_path
  source_code_hash = data.archive_file.customer_lambda_zip.output_base64sha256
  handler       = "customer_api.lambda_handler"
  runtime       = "python3.11"
  role          = aws_iam_role.lambda_exec.arn

  environment {
    variables = {
      TTL_DAYS = var.ttl_days
    }
  }

  tags = local.common_tags
}

# API Gateway REST API
resource "aws_api_gateway_rest_api" "api" {
  name = "${local.name_prefix}-api"
  tags = local.common_tags
}

resource "aws_api_gateway_resource" "customers" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "customers"
}

# Root ANY -> Lambda (so base URL works)
resource "aws_api_gateway_method" "root_any" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_rest_api.api.root_resource_id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "root_lambda" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_rest_api.api.root_resource_id
  http_method = aws_api_gateway_method.root_any.http_method
  type        = "AWS_PROXY"
  integration_http_method = "POST"
  uri         = aws_lambda_function.customer_api.invoke_arn
}

# CORS for root
resource "aws_api_gateway_method" "root_options" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_rest_api.api.root_resource_id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "root_options" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_rest_api.api.root_resource_id
  http_method = aws_api_gateway_method.root_options.http_method
  type        = "MOCK"
  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "root_options_200" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_rest_api.api.root_resource_id
  http_method = aws_api_gateway_method.root_options.http_method
  status_code = "200"
  response_models = {
    "application/json" = "Empty"
  }
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true,
    "method.response.header.Access-Control-Allow-Methods" = true,
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "root_options_200" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_rest_api.api.root_resource_id
  http_method = aws_api_gateway_method.root_options.http_method
  status_code = aws_api_gateway_method_response.root_options_200.status_code
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key'",
    "method.response.header.Access-Control-Allow-Methods" = "'GET,POST,PUT,DELETE,OPTIONS'",
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

resource "aws_api_gateway_method" "customers_any" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.customers.id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "customers_lambda" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.customers.id
  http_method = aws_api_gateway_method.customers_any.http_method
  type        = "AWS_PROXY"
  integration_http_method = "POST"
  uri         = aws_lambda_function.customer_api.invoke_arn
}

# CORS preflight for /customers
resource "aws_api_gateway_method" "customers_options" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.customers.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "customers_options" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.customers.id
  http_method = aws_api_gateway_method.customers_options.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "customers_options_200" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.customers.id
  http_method = aws_api_gateway_method.customers_options.http_method
  status_code = "200"

  response_models = {
    "application/json" = "Empty"
  }

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true,
    "method.response.header.Access-Control-Allow-Methods" = true,
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "customers_options_200" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.customers.id
  http_method = aws_api_gateway_method.customers_options.http_method
  status_code = aws_api_gateway_method_response.customers_options_200.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key'",
    "method.response.header.Access-Control-Allow-Methods" = "'GET,POST,PUT,DELETE,OPTIONS'",
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

resource "aws_lambda_permission" "apigw_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.customer_api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}

resource "aws_api_gateway_deployment" "api" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  triggers = {
    redeploy = sha1(jsonencode({
  resources        = aws_api_gateway_resource.customers.id,
  method_any       = aws_api_gateway_method.customers_any.id,
  integ_any        = aws_api_gateway_integration.customers_lambda.id,
  method_opt       = aws_api_gateway_method.customers_options.id,
  integ_opt        = aws_api_gateway_integration.customers_options.id,
  resp_opt_m       = aws_api_gateway_method_response.customers_options_200.id,
  resp_opt_i       = aws_api_gateway_integration_response.customers_options_200.id,
  root_method_any  = aws_api_gateway_method.root_any.id,
  root_integ_any   = aws_api_gateway_integration.root_lambda.id,
  root_method_opt  = aws_api_gateway_method.root_options.id,
  root_integ_opt   = aws_api_gateway_integration.root_options.id,
  root_resp_opt_m  = aws_api_gateway_method_response.root_options_200.id,
  root_resp_opt_i  = aws_api_gateway_integration_response.root_options_200.id
    }))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "dev" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  deployment_id = aws_api_gateway_deployment.api.id
  stage_name    = var.environment
  tags          = local.common_tags
}
