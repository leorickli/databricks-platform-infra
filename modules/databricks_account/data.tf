# Creates the permission slip (policy text) in JSON format
data "aws_iam_policy_document" "assume_role_for_ec2" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = ["ec2.amazonaws.com"]
      type        = "Service"
    }
  }
}

data "databricks_service_principal" "lmx_sp" {
  display_name = "lmx-servicePrincipal"
}

data "databricks_aws_assume_role_policy" "this" {
  provider    = databricks
  external_id = var.databricks_account_id
}

data "databricks_aws_crossaccount_policy" "this" {
  provider    = databricks
  policy_type = "customer"
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "databricks_aws_bucket_policy" "this" {
  bucket = aws_s3_bucket.root_storage_bucket.bucket
}

data "databricks_user" "user_developer" {
  user_name = "developer@example.com"
}

# Writes the permissions slip (JSON policy text) to the development bucket
data "databricks_aws_bucket_policy" "development" {
  full_access_role = aws_iam_role.data_storage_role.arn
  bucket           = var.aws_development_bucket
}

# Writes the permissions slip (JSON policy text) to the production bucket
data "databricks_aws_bucket_policy" "production" {
  full_access_role = aws_iam_role.data_storage_role.arn
  bucket           = var.aws_production_bucket
}

# Writes the permissions slip (JSON policy text) to the sandbox bucket
data "databricks_aws_bucket_policy" "sandbox" {
  full_access_role = aws_iam_role.data_storage_role.arn
  bucket           = var.aws_sandbox_bucket
}

# Writes the permissions slip (JSON policy text) to the staging bucket
data "databricks_aws_bucket_policy" "staging" {
  full_access_role = aws_iam_role.data_storage_role.arn
  bucket           = var.aws_staging_bucket
}