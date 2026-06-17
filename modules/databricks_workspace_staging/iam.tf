# --- Instance profiles ---
resource "databricks_instance_profile" "data_access" {
  instance_profile_arn = var.aws_data_access_instance_profile_arn
  skip_validation      = true
}

resource "databricks_instance_profile" "glue_job" {
  instance_profile_arn = var.aws_glue_job_instance_profile_arn
  skip_validation      = true
}

# Grants for SQL Endpoint
resource "databricks_permissions" "dbt_warehouse" {
  sql_endpoint_id = databricks_sql_endpoint.dbt_warehouse.id

  access_control {
    service_principal_name = var.databricks_dbt_sp_uuid
    permission_level       = "CAN_USE"
  }
}

# - Grants for the catalogs -
resource "databricks_grants" "client_catalog_grants" {
  for_each = var.client_names #Inside the unity_catalog.tf file

  catalog = databricks_catalog.catalogs[each.key].id
  grant {
    principal  = var.databricks_user_developer
    privileges = ["ALL_PRIVILEGES"]
  }
  grant {
    principal  = var.databricks_user_teammate
    privileges = ["USE_CATALOG", "USE_SCHEMA", "SELECT"]
  }
  grant {
    principal = var.databricks_dbt_sp_uuid
    privileges = [
      "USE_CATALOG",
      "USE_SCHEMA",
      "CREATE_TABLE",
      "CREATE_SCHEMA",
      "CREATE_MATERIALIZED_VIEW",
      "SELECT",
      "MODIFY",
    ]
  }
  # Developers get read access on staging so the team can query the
  # pseudo-prod data while soak-testing changes.
  grant {
    principal  = var.databricks_group_developers
    privileges = ["USE_CATALOG", "USE_SCHEMA", "SELECT"]
  }
}

# Note: Main catalog grants are managed in the development workspace only
# to avoid conflicts between workspaces since Unity Catalog grants are shared
