# --- Instance profiles ---
resource "databricks_instance_profile" "data_access" {
  instance_profile_arn = var.aws_data_access_instance_profile_arn
  skip_validation      = true
}

resource "databricks_instance_profile" "glue_job" {
  instance_profile_arn = var.aws_glue_job_instance_profile_arn
  skip_validation      = true
}

# --- Grants ---
# Storage Credential grants
resource "databricks_grants" "external_creds_developer" {
  storage_credential = databricks_storage_credential.dev_bucket.id
  grant {
    principal  = var.databricks_user_developer
    privileges = ["ALL_PRIVILEGES"]
  }
}

# External Location grants
resource "databricks_grants" "external_location_developer" {
  external_location = databricks_external_location.dev_bucket.id
  grant {
    principal  = var.databricks_user_developer
    privileges = ["ALL_PRIVILEGES"]
  }
}

# Grants for the catalogs
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
    principal  = var.databricks_group_developers
    privileges = ["USE_CATALOG", "USE_SCHEMA", "SELECT"]
  }

  grant {
    principal  = var.databricks_group_ml_developers
    privileges = ["USE_CATALOG", "USE_SCHEMA", "SELECT", "CREATE_TABLE", "CREATE_SCHEMA", "MODIFY"]
  }

  grant {
    principal = var.databricks_webapp_sp_uuid
    privileges = [
      "USE_CATALOG",
      "USE_SCHEMA",
      "SELECT",
      "MODIFY",
    ]
  }
}

# Grants for the main catalog (must be identical in both dev and prod to avoid conflicts)
resource "databricks_grants" "main_dev_catalog" {
  catalog = data.databricks_catalog.main.id

  # Terraform SP retains MANAGE so future applies continue to work
  grant {
    principal  = data.databricks_current_user.terraform_sp.user_name
    privileges = ["ALL_PRIVILEGES", "MANAGE"]
  }

  # Developer gets full admin access
  grant {
    principal  = var.databricks_user_developer
    privileges = ["ALL_PRIVILEGES"]
  }

  # dbt service principal gets permissions (identical grants in both workspaces prevent cycling)
  grant {
    principal = "00000000-0000-0000-0000-000000000000"
    privileges = [
      "CREATE_MATERIALIZED_VIEW",
      "CREATE_SCHEMA",
      "CREATE_TABLE",
      "MODIFY",
      "SELECT",
      "USE_CATALOG",
      "USE_SCHEMA",
    ]
  }

  # ML developers group gets ML-specific permissions
  grant {
    principal = var.databricks_group_ml_developers
    privileges = [
      "USE_CATALOG",
      "USE_SCHEMA",
      "SELECT",
      "CREATE_TABLE",
      "CREATE_SCHEMA",
      "CREATE_MODEL",
      "EXECUTE"
    ]
  }
}

# --- Cluster Permissions ---
resource "databricks_permissions" "shared_cluster_developers" {
  cluster_id = databricks_cluster.shared_autoscaling.id

  access_control {
    group_name       = var.databricks_group_developers
    permission_level = "CAN_RESTART"
  }

  access_control {
    group_name       = var.databricks_group_ml_developers
    permission_level = "CAN_RESTART"
  }
}

resource "databricks_permissions" "cluster_policy_developers" {
  cluster_policy_id = databricks_cluster_policy.developers_policy.id

  access_control {
    group_name       = var.databricks_group_developers
    permission_level = "CAN_USE"
  }

  access_control {
    group_name       = var.databricks_group_ml_developers
    permission_level = "CAN_USE"
  }
}