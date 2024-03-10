terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.40.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "4.26.0"
    }
  }
}

variable "aws_access_key" {
  type = string
}

variable "aws_secret_key" {
  type = string
}

variable "cloudflare_api_token" {
  type = string
}

provider "aws" {
  alias = "us_east_1"
  region = "us-east-1"
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token

}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}


resource "null_resource" "function_binary" {
  provisioner "local-exec" {
    command = "GOOS=linux GOARCH=arm64 CGO_ENABLED=0 GOFLAGS=-trimpath go build -C ${abspath(path.module)} -mod=readonly -ldflags='-s -w' -o bootstrap"
  }

  triggers = {
    when_file_changes = sha256(file("${path.module}/main.go"))
  }
}

data "archive_file" "function_archive" {
  depends_on = [null_resource.function_binary]

  type        = "zip"
  source_file = "${path.module}/bootstrap"
  output_path = "${path.module}/bootstrap.zip"
}

data "aws_iam_policy_document" "assume_lambda_role" {
  statement {
    actions = [
      "sts:AssumeRole"
    ]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  name               = "AssumeLambdaRole"
  description        = "Role for lambda to assume lambda"
  assume_role_policy = data.aws_iam_policy_document.assume_lambda_role.json
}

data "aws_iam_policy_document" "allow_lambda_logging" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]

    resources = ["arn:aws:logs:*:*:*"]
  }
}

resource "aws_iam_policy" "function_logging_policy" {
  name        = "AllowLambdaLoggingPolicy"
  description = "Policy for lambda cloudwatch logging"
  policy      = data.aws_iam_policy_document.allow_lambda_logging.json
}

resource "aws_iam_role_policy_attachment" "lambda_logging_policy_attachment" {
  role       = aws_iam_role.lambda.name
  policy_arn = aws_iam_policy.function_logging_policy.arn
}

resource "aws_lambda_function" "lambda_function" {
  function_name = "shark-api"
  description   = "Shark API"
  role          = aws_iam_role.lambda.arn
  architectures = ["arm64"]
  memory_size   = 128

  handler          = "bootstrap"
  filename         = "${path.module}/bootstrap.zip"
  source_code_hash = data.archive_file.function_archive.output_base64sha256

  runtime = "provided.al2"

}

resource "aws_cloudwatch_log_group" "log_group" {
  name              = "/aws/lambda/${aws_lambda_function.lambda_function.function_name}"
  retention_in_days = 7
}

resource "aws_apigatewayv2_api" "api_gateway" {
  name          = "shark-api"
  protocol_type = "HTTP"
  
  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET"]
  }
}

resource "aws_apigatewayv2_stage" "api_gateway_stage" {
  api_id = aws_apigatewayv2_api.api_gateway.id
  name = "$default"
  auto_deploy = true
}

resource "aws_cloudfront_cache_policy" "api_cache" {
  comment = "Default cache policy when CF compression enabled"
  default_ttl = 86400
  max_ttl = 31536000
  min_ttl = 1
  name = "SharkCachingOptimized"

  parameters_in_cache_key_and_forwarded_to_origin {
    enable_accept_encoding_brotli = true
    enable_accept_encoding_gzip   = true

    cookies_config {
      cookie_behavior = "none"
    }

    headers_config {
      header_behavior = "none"
    }

    query_strings_config {
      query_string_behavior = "none"
    }
  }
}

resource "aws_cloudfront_response_headers_policy" "api_cors" {
  name = "Shark-CORS-Policy"

  cors_config {
    access_control_allow_credentials = false
    access_control_max_age_sec = 600
    origin_override = true

    access_control_allow_headers {
      items = ["*"]
    }

    access_control_allow_methods {
      items = ["GET"]
    }

    access_control_allow_origins {
      items = ["*"]
    }
  }
}

resource "aws_acm_certificate" "api_certificate" {
  provider = aws.us_east_1
  domain_name = "api.shark.plasam.dev"
  validation_method = "DNS"
}

resource "aws_cloudfront_distribution" "shark_api" {
  aliases = [
    "api.shark.plasam.dev"
  ]
  enabled = true
  is_ipv6_enabled = true
  price_class = "PriceClass_100"

  default_cache_behavior {
    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods = ["GET", "HEAD", "OPTIONS"]
    cache_policy_id = aws_cloudfront_cache_policy.api_cache.id

    compress = true
    default_ttl = 0
    max_ttl = 0
    min_ttl = 0
    response_headers_policy_id = aws_cloudfront_response_headers_policy.api_cors.id
    smooth_streaming = false
    target_origin_id = aws_apigatewayv2_api.api_gateway.id

    trusted_key_groups = []
    trusted_signers = []
    viewer_protocol_policy = "allow-all"
  }

  origin {
    connection_attempts = 3
    connection_timeout = 10
    domain_name = "${aws_apigatewayv2_api.api_gateway.id}.execute-api.${data.aws_region.current.name}.amazonaws.com"
    origin_id = aws_apigatewayv2_api.api_gateway.id

    custom_origin_config {
      http_port = 80
      https_port = 443
      origin_protocol_policy = "https-only"
      origin_keepalive_timeout = 5
      origin_read_timeout = 30
      origin_ssl_protocols = ["TLSv1.2"]
    }
  }
  
  restrictions {
    geo_restriction {
      locations = []
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn = aws_acm_certificate.api_certificate.arn
    ssl_support_method = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
    cloudfront_default_certificate = false
  }
}

resource "aws_apigatewayv2_integration" "integration" {
  integration_type = "AWS_PROXY"
  payload_format_version = "2.0"
  api_id = aws_apigatewayv2_api.api_gateway.id
  integration_uri = aws_lambda_function.lambda_function.arn
}

resource "aws_apigatewayv2_route" "route" {
  api_id = aws_apigatewayv2_api.api_gateway.id
  route_key = "GET /v1/packs/{count}"
  target =  "integrations/${aws_apigatewayv2_integration.integration.id}" 
}

resource "aws_lambda_permission" "route_permission" {
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_function.function_name
  principal = "apigateway.amazonaws.com"
  source_arn = "arn:aws:execute-api:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${aws_apigatewayv2_api.api_gateway.id}/*/*/v1/packs/{count}"
}

resource "cloudflare_record" "api_record" {
  zone_id = "ba9f4a4b7da11075d6614a5642b380fd"
  name = "api.shark"
  value = aws_cloudfront_distribution.shark_api.domain_name
  type = "CNAME"
}