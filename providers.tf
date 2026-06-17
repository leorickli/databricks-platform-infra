terraform {
  required_version = ">= 1.11.4"

  backend "s3" {
    bucket       = "lmx-s3-operational"
    key          = "terraform/dev/terraform.tfstate"
    region       = "eu-central-1" # Variables can't be used here
    encrypt      = true
    use_lockfile = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.97.0"
    }
    databricks = {
      source  = "databricks/databricks"
      version = ">=1.77.0"

      configuration_aliases = [
        databricks.mws,
        databricks.workspace_development,
        databricks.workspace_production,
        databricks.workspace_sandbox,
        databricks.workspace_staging
      ]
    }

    time = {
      source  = "hashicorp/time"
      version = "~> 0.13.1"
    }
  }
}

provider "aws" {
  region = "eu-central-1" # Variables can't be used here
}

# Account-Level Databricks Provider
provider "databricks" {
  alias         = "mws"
  host          = "https://accounts.cloud.databricks.com"
  account_id    = local.db_creds.databricks_account_id
  client_id     = local.db_creds.databricks_client_id
  client_secret = local.db_creds.databricks_client_secret
}

# Development-Level Databricks Provider
provider "databricks" {
  alias = "workspace_development"
  host  = module.databricks_account.development_workspace_url
  token = module.databricks_account.development_databricks_token
}

# Production-Level Databricks Provider
provider "databricks" {
  alias = "workspace_production"
  host  = module.databricks_account.production_workspace_url
  token = module.databricks_account.production_databricks_token
}

# Sandbox-Level Databricks Provider
provider "databricks" {
  alias = "workspace_sandbox"
  host  = module.databricks_account.sandbox_workspace_url
  token = module.databricks_account.sandbox_databricks_token
}

# Staging-Level Databricks Provider
provider "databricks" {
  alias = "workspace_staging"
  host  = module.databricks_account.staging_workspace_url
  token = module.databricks_account.staging_databricks_token
}