# --- Domain and DNS Configuration ---
# Create the API Gateway Custom Domain and point DNS to it
resource "aws_api_gateway_domain_name" "this" {
  domain_name              = data.aws_acm_certificate.this.domain
  regional_certificate_arn = data.aws_acm_certificate.this.arn

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

# Inserts API Gateway Custom Domain to Route 53
resource "aws_route53_record" "this" {
  name    = aws_api_gateway_domain_name.this.domain_name
  zone_id = data.aws_route53_zone.this.zone_id
  type    = "A"

  alias {
    name                   = aws_api_gateway_domain_name.this.regional_domain_name
    zone_id                = aws_api_gateway_domain_name.this.regional_zone_id
    evaluate_target_health = true
  }
}

# --- API Gateway Core Resources ---
resource "aws_api_gateway_rest_api" "this" {
  name        = "lmx-data-ingestion-api"
  description = "Receives push notifications (webhooks) from APIs"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_resource" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = "data"
}

resource "aws_api_gateway_method" "this" {
  rest_api_id      = aws_api_gateway_rest_api.this.id
  resource_id      = aws_api_gateway_resource.this.id
  http_method      = "POST"
  authorization    = "NONE"
  api_key_required = true
}

resource "aws_api_gateway_integration" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.this.id
  http_method = aws_api_gateway_method.this.http_method

  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  uri                     = aws_lambda_function.data_decode.invoke_arn
}

resource "aws_api_gateway_method_response" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.this.id
  http_method = aws_api_gateway_method.this.http_method
  status_code = "200"
}

resource "aws_api_gateway_integration_response" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.this.id
  http_method = aws_api_gateway_method.this.http_method
  status_code = aws_api_gateway_method_response.this.status_code

  # Return an empty body for success
  response_templates = {
    "application/json" = ""
  }
}

resource "aws_api_gateway_api_key" "this" {
  name    = "acme-API-key"
  enabled = true

  # Created so it's possible to manually disable on GUI
  lifecycle { ignore_changes = [enabled] }
}

# --- CloudWatch Logs ---
resource "aws_api_gateway_account" "this" {
  cloudwatch_role_arn = aws_iam_role.api_gateway_cloudwatch_logs_role.arn

  depends_on = [
    aws_iam_role_policy_attachment.api_gateway_cloudwatch_logs_policy_attachment
  ]
}

resource "aws_cloudwatch_log_group" "api_gateway_logs" {
  name              = "/aws/apigateway/${aws_api_gateway_rest_api.this.name}"
  retention_in_days = 7

  tags = {
    Environment = "dev"
    Project     = "Data Ingestion API"
  }
}

# --- Deployment and Stage ---
resource "aws_api_gateway_deployment" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.this.id,
      aws_api_gateway_method.this.id,
      aws_api_gateway_integration.this.id,
    ]))
  }

  depends_on = [aws_lambda_permission.api_gateway_invoke]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "v1" {
  deployment_id = aws_api_gateway_deployment.this.id
  rest_api_id   = aws_api_gateway_rest_api.this.id
  stage_name    = "v1"

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway_logs.arn

    format = jsonencode({
      requestId           = "$context.requestId"
      sourceIp            = "$context.identity.sourceIp"
      requestTime         = "$context.requestTime"
      httpMethod          = "$context.httpMethod"
      path                = "$context.path"
      status              = "$context.status"
      protocol            = "$context.protocol"
      responseLength      = "$context.responseLength"
      apiKeyId            = "$context.identity.apiKeyId"
      "integration.error" = "$context.integration.error"
    })
  }

  depends_on = [aws_api_gateway_account.this]
}

resource "aws_api_gateway_usage_plan" "this" {
  name = "acme-usage-plan"

  api_stages {
    api_id = aws_api_gateway_rest_api.this.id
    stage  = aws_api_gateway_stage.v1.stage_name
  }

  throttle_settings {
    burst_limit = 20
    rate_limit  = 10
  }
}

resource "aws_api_gateway_usage_plan_key" "this" {
  key_id        = aws_api_gateway_api_key.this.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.this.id
}

# Connect the custom domain to stage
resource "aws_api_gateway_base_path_mapping" "this" {
  api_id      = aws_api_gateway_rest_api.this.id
  stage_name  = aws_api_gateway_stage.v1.stage_name
  domain_name = aws_api_gateway_domain_name.this.id
}