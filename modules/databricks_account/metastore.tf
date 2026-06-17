resource "databricks_mws_networks" "development" {
  account_id         = var.databricks_account_id
  network_name       = "dpx-databricks-network-development"
  security_group_ids = [aws_security_group.databricks_sg.id]
  subnet_ids         = var.aws_private_subnets_development
  vpc_id             = var.aws_vpc_id
}

resource "databricks_mws_networks" "production" {
  account_id         = var.databricks_account_id
  network_name       = "dpx-databricks-network-production"
  security_group_ids = [aws_security_group.databricks_sg.id]
  subnet_ids         = var.aws_private_subnets_production
  vpc_id             = var.aws_vpc_id
}

resource "databricks_mws_networks" "sandbox" {
  account_id         = var.databricks_account_id
  network_name       = "dpx-databricks-network-sandbox"
  security_group_ids = [aws_security_group.databricks_sg.id]
  subnet_ids         = var.aws_private_subnets_sandbox
  vpc_id             = var.aws_vpc_id
}

resource "databricks_mws_networks" "staging" {
  account_id         = var.databricks_account_id
  network_name       = "dpx-databricks-network-staging"
  security_group_ids = [aws_security_group.databricks_sg.id]
  subnet_ids         = var.aws_private_subnets_staging
  vpc_id             = var.aws_vpc_id
}

resource "databricks_mws_storage_configurations" "this" {
  account_id                 = var.databricks_account_id
  bucket_name                = aws_s3_bucket.root_storage_bucket.bucket
  storage_configuration_name = "dpx-databricks-storage"
}

resource "databricks_mws_credentials" "this" {
  role_arn         = aws_iam_role.cross_account_role.arn
  credentials_name = "dpx-databricks-creds"
  depends_on = [
    aws_iam_role_policy.this,
    aws_iam_role_policy.pass_role_for_data_access
  ]
}

resource "databricks_mws_workspaces" "development" {
  account_id     = var.databricks_account_id
  aws_region     = var.aws_region
  workspace_name = "dpx-development"

  credentials_id           = databricks_mws_credentials.this.credentials_id
  storage_configuration_id = databricks_mws_storage_configurations.this.storage_configuration_id
  network_id               = databricks_mws_networks.development.network_id

  token {
    comment = "Terraform"
  }
}

resource "databricks_mws_workspaces" "production" {
  account_id     = var.databricks_account_id
  aws_region     = var.aws_region
  workspace_name = "dpx-production"

  credentials_id           = databricks_mws_credentials.this.credentials_id
  storage_configuration_id = databricks_mws_storage_configurations.this.storage_configuration_id
  network_id               = databricks_mws_networks.production.network_id

  token {
    comment = "Terraform"
  }
}

resource "databricks_mws_workspaces" "sandbox" {
  account_id     = var.databricks_account_id
  aws_region     = var.aws_region
  workspace_name = "dpx-sandbox"

  credentials_id           = databricks_mws_credentials.this.credentials_id
  storage_configuration_id = databricks_mws_storage_configurations.this.storage_configuration_id
  network_id               = databricks_mws_networks.sandbox.network_id

  token {
    comment = "Terraform"
  }
}

resource "databricks_mws_workspaces" "staging" {
  account_id     = var.databricks_account_id
  aws_region     = var.aws_region
  workspace_name = "dpx-staging"

  credentials_id           = databricks_mws_credentials.this.credentials_id
  storage_configuration_id = databricks_mws_storage_configurations.this.storage_configuration_id
  network_id               = databricks_mws_networks.staging.network_id

  token {
    comment = "Terraform"
  }
}

resource "databricks_metastore" "this" {
  name          = "dataplatform-metastore"
  storage_root  = "s3://${aws_s3_bucket.root_storage_bucket.bucket}/metastore"
  owner         = "developer@example.com"
  region        = var.aws_region
  force_destroy = true
}

resource "databricks_metastore_assignment" "development" {
  metastore_id = databricks_metastore.this.id
  workspace_id = databricks_mws_workspaces.development.workspace_id
}

resource "databricks_metastore_assignment" "production" {
  metastore_id = databricks_metastore.this.id
  workspace_id = databricks_mws_workspaces.production.workspace_id
}

resource "databricks_metastore_assignment" "sandbox" {
  metastore_id = databricks_metastore.this.id
  workspace_id = databricks_mws_workspaces.sandbox.workspace_id
}

resource "databricks_metastore_assignment" "staging" {
  metastore_id = databricks_metastore.this.id
  workspace_id = databricks_mws_workspaces.staging.workspace_id
}

# Adding 20 second timer to avoid Failed credential validation check
resource "time_sleep" "wait" {
  create_duration = "20s"
  depends_on      = [aws_iam_role_policy.this]
}

# Adding 10 second timer to allow token from Databricks workspaces to propagate
resource "time_sleep" "wait_for_workspace_token_propagation" {
  create_duration = "10s"
  depends_on      = [databricks_mws_workspaces.development, databricks_mws_workspaces.production, databricks_mws_workspaces.sandbox, databricks_mws_workspaces.staging]
}

# Adding 60 second timer after metastore assignment to allow the sandbox workspace
# to fully initialize before permission assignment APIs become available
resource "time_sleep" "wait_for_sandbox_permissions_api" {
  create_duration = "120s"
  depends_on      = [databricks_metastore_assignment.sandbox]
}

# Adding 120 second timer after metastore assignment to allow the staging workspace
# to fully initialize before permission assignment APIs become available
resource "time_sleep" "wait_for_staging_permissions_api" {
  create_duration = "120s"
  depends_on      = [databricks_metastore_assignment.staging]
}

# Note: Main catalog grants are managed in the development workspace module only
# to avoid conflicts, since Unity Catalog grants are shared across all workspaces