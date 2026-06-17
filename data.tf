# --- Databricks credentials/secrets ---
# Stored in AWS Secrets Manager
data "aws_secretsmanager_secret_version" "databricks_creds" {
  secret_id = "lmx/terraform"
}

# Parse the JSON secret
locals { db_creds = jsondecode(data.aws_secretsmanager_secret_version.databricks_creds.secret_string) }

# --- General ---
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_region" "current" {}

# --- For API Gateway ---
data "aws_acm_certificate" "this" {
  domain   = "api.lmx.com"
  statuses = ["ISSUED"]
}

data "aws_route53_zone" "this" {
  name = "lmx.com"
}