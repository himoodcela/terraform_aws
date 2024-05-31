terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = " 2.4.0"
    }
  }

  required_version = "~> 1.2"
}
  

  variable "aws_region" {
  description = "AWS region for all resources."

  type    = string
  default = "ap-northeast-2"
}

variable "iam_role_policy_arn" {
  description = "ARN of the IAM role policy to attach to the lambda role."
  
  type = string
  default = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

variable "apigatewayv2_api_main" {
  description = "API Gateway v2 API for the main API."
  
  type = object({
    name          = string
    protocol_type = string
  })
  default = {
    name          = "main"
    protocol_type = "HTTP"
  }
}

provider "aws" {
  region = "ap-northeast-2"

  default_tags {
    tags = {
      tag_name = "lambda-api-gateway"
    }
  }

}

data "archive_file" "lambda_handler_archive_file" {
  type        = "zip"
  source_file  = "./handler/lambda_function.py"
  output_path = "/handler.zip"
}
  
resource "random_pet" "lambda_bucket_name" {
  prefix = "lambda-bucket"
  length = 4
}

resource "aws_iam_role" "lambda_role" {
  name = "handler-lambda-role"
    
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda_role_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = var.iam_role_policy_arn
}

resource "aws_s3_bucket" "my_bucket" {
  bucket = "minh22"
  

  website {
    index_document = "index.html"
    error_document = "error.html"
}
}



resource "aws_s3_bucket" "lambda_bucket" {
  bucket = random_pet.lambda_bucket_name.id

    website {
    index_document = "index.html"
    error_document = "error.html"
  }


}

resource "aws_s3_bucket_ownership_controls" "lambda_bucket_ownership_controls" {
  bucket = aws_s3_bucket.lambda_bucket.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "lambda_bucket_acl" {
  depends_on = [aws_s3_bucket_ownership_controls.lambda_bucket_ownership_controls]

  bucket = aws_s3_bucket.lambda_bucket.id
  acl = "private"
}


  
resource "aws_s3_object" "lambda_handler_bucket_object" {
    bucket = aws_s3_bucket.lambda_bucket.id
    key    = "handler.zip"
    source = data.archive_file.lambda_handler_archive_file.output_path
    acl    = "public-read"
    etag = filemd5(data.archive_file.lambda_handler_archive_file.output_path)

    depends_on = [
        data.archive_file.lambda_handler_archive_file,
    ]
}

output "website_url" {
  value = aws_s3_bucket.my_bucket.website_endpoint
}

resource "aws_s3_bucket_policy" "lambda_bucket_policy" {
  bucket = aws_s3_bucket.lambda_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = "*"
        Action = "s3:GetObject"
        Resource = "${aws_s3_bucket.lambda_bucket.arn}/*"
      }
    ]
  })
}



resource "aws_lambda_function" "lambda_handler" {
  function_name    = "LambdaHandler"
  role             = aws_iam_role.lambda_role.arn
  handler          = "app"
  source_code_hash = data.archive_file.lambda_handler_archive_file.output_base64sha256 // or filebase64sha256(handler.zip)
  runtime          = "python3.12"

  s3_bucket = aws_s3_bucket.lambda_bucket.id
  s3_key    = aws_s3_object.lambda_handler_bucket_object.key

  depends_on = [
    aws_s3_object.lambda_handler_bucket_object,
  ]
}

resource "aws_cloudwatch_log_group" "lambda_cloudwatch_log" {
  name              = "/aws/lambda/${aws_lambda_function.lambda_handler.function_name}"
  retention_in_days = 14
}

resource "aws_apigatewayv2_api" "lambda_api_gateway" {
  name          = var.apigatewayv2_api_main.name
  protocol_type = var.apigatewayv2_api_main.protocol_type
}

resource "aws_apigatewayv2_stage" "lambda_api_gateway_stage" {
  api_id      = aws_apigatewayv2_api.lambda_api_gateway.id
  name        = "dev"
  auto_deploy = true

   access_log_settings {
      destination_arn = aws_cloudwatch_log_group.api_gw.arn

      format = jsonencode({
        requestId               = "$context.requestId"
        sourceIp                = "$context.identity.sourceIp"
        requestTime             = "$context.requestTime"
        protocol                = "$context.protocol"
        httpMethod              = "$context.httpMethod"
        resourcePath            = "$context.resourcePath"
        routeKey                = "$context.routeKey"
        status                  = "$context.status"
        responseLength          = "$context.responseLength"
        integrationErrorMessage = "$context.integrationErrorMessage"
        }
      )
    }
}

resource "aws_apigatewayv2_integration" "lambda_api_gateway_integration" {
  api_id             = aws_apigatewayv2_api.lambda_api_gateway.id
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
  integration_uri    = aws_lambda_function.lambda_handler.invoke_arn
}

resource "aws_apigatewayv2_route" "get_lambda_api_gateway_route" {
  api_id    = aws_apigatewayv2_api.lambda_api_gateway.id

  route_key = "GET /hello"
  target = "integrations/${aws_apigatewayv2_integration.lambda_api_gateway_integration.id}"
}

resource "aws_cloudwatch_log_group" "api_gw" {
  name              = "/aws/apigateway/${aws_apigatewayv2_api.lambda_api_gateway.name}"
  retention_in_days = 7
}

resource "aws_lambda_permission" "lambda_api_gateway_permission" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_handler.function_name
  principal     = "apigateway.amazonaws.com"
  
  source_arn    = "${aws_apigatewayv2_api.lambda_api_gateway.execution_arn}/*/*"
}

output "lambda_role" {
  description = "IAM role for the lambda function."
  value = aws_iam_role.lambda_role
}

output "lambda_bucket_object" {
  description = "S3 bucket object for the lambda handler."
  value = aws_s3_object.lambda_handler_bucket_object
}

output "function_name" {
  description = "Name of the lambda function."
  value = aws_lambda_function.lambda_handler.function_name
}


output "base_url" {
  description = "Base URL for the API Gateway v2 API."
  value = aws_apigatewayv2_api.lambda_api_gateway.api_endpoint
}

output "get_base_url" {
  value = aws_apigatewayv2_stage.lambda_api_gateway_stage.invoke_url
}