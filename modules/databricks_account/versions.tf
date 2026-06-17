terraform {
  required_providers {
    databricks = {
      source  = "databricks/databricks"
      version = ">=1.77.0"
    }

    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.97.0"
    }

    time = {
      source  = "hashicorp/time"
      version = "~> 0.13.1"
    }
  }
}

# resource "databricks_account_setting_v2" "personal_compute" {

#   personal_compute = {
#     value = "DELEGATE"
#   }
# }