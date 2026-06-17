# --- Storage Credential and External Location ---
# These were BOOTSTRAPPED out-of-band by scripts/setup_staging_uc.py (to break
# the storage-credential / IAM-role external-ID circular dependency) and then
# adopted into Terraform via `import` blocks (see ../../imports_staging.tf).
#
# The backing AWS IAM role (dpx-databricks-uc-external-staging) and its inline
# policies remain script-managed — the credential references it by ARN string,
# exactly as the prod module does, so there is no TF dependency on the role.
#
# NOTE: created with ISOLATION_MODE_OPEN (visible to all workspaces on the
# metastore). Prod uses ISOLATION_MODE_ISOLATED bound to its workspace; to
# tighten staging the same way, flip both isolation_mode values and apply.
resource "databricks_storage_credential" "stg_bucket" {
  name = "dpx-databricks-storage-credential-external-staging"
  aws_iam_role {
    role_arn = "arn:aws:iam::${var.aws_account_id}:role/dpx-databricks-uc-external-staging"
  }
  isolation_mode = "ISOLATION_MODE_OPEN"
  comment        = "Managed out-of-band (setup_staging_uc.py); import into TF."
}

resource "databricks_external_location" "stg_bucket" {
  name            = "dpx-databricks-external-location-external-staging"
  url             = "s3://${var.aws_staging_bucket}/"
  credential_name = databricks_storage_credential.stg_bucket.name
  isolation_mode  = "ISOLATION_MODE_OPEN"
  force_destroy   = true
  comment         = "Managed out-of-band (setup_staging_uc.py); import into TF."
}

# --- 3-Level Namespace (catalog.schema.object) ---
variable "client_names" {
  description = "Set of client names for distinct catalogs"
  type        = set(string)
  default     = ["dpx", "acme", "globex"]
}

# Static identifier catalogs
resource "databricks_catalog" "catalogs" {
  for_each = var.client_names

  name           = "${each.key}_stg"
  storage_root   = "s3://${var.aws_staging_bucket}/${each.key}/"
  force_destroy  = true
  comment        = "Staging environment catalog for all data assets and operational schemas for the ${each.key} client."
  isolation_mode = "ISOLATED"

  properties = {
    type = "client"
  }

  depends_on = [databricks_external_location.stg_bucket]
}

# Static identifier schemas
resource "databricks_schema" "land_schemas" {
  for_each = var.client_names

  catalog_name = databricks_catalog.catalogs[each.key].id
  name         = "land"
  comment      = "Land layer for ${each.key}."
  properties = {
    layer = "land"
  }
}

resource "databricks_schema" "bronze_schemas" {
  for_each = var.client_names

  catalog_name = databricks_catalog.catalogs[each.key].id
  name         = "bronze"
  comment      = "Bronze layer for ${each.key}."
  properties = {
    layer = "bronze"
  }
}

resource "databricks_schema" "silver_schemas" {
  for_each = var.client_names

  catalog_name = databricks_catalog.catalogs[each.key].id
  name         = "silver"
  comment      = "Silver layer for ${each.key}."
  properties = {
    layer = "silver"
  }
}

resource "databricks_schema" "gold_schemas" {
  for_each = var.client_names

  catalog_name = databricks_catalog.catalogs[each.key].id
  name         = "gold"
  comment      = "Gold layer for ${each.key}."
  properties = {
    layer = "gold"
  }
}

resource "databricks_schema" "views_schemas" {
  for_each = var.client_names

  catalog_name = databricks_catalog.catalogs[each.key].id
  name         = "views"
  comment      = "Views layer for ${each.key}."
  properties = {
    layer = "views"
  }
}

resource "databricks_schema" "metadata_schemas" {
  for_each = var.client_names

  catalog_name = databricks_catalog.catalogs[each.key].id
  name         = "metadata"
  comment      = "Metadata layer for ${each.key}."
  properties = {
    layer = "metadata"
  }
}

resource "databricks_schema" "operational_schemas" {
  for_each = var.client_names

  catalog_name = databricks_catalog.catalogs[each.key].id
  name         = "operational"
  comment      = "Operational layer for ${each.key}."
  properties = {
    layer = "operational"
  }
}

resource "databricks_schema" "ml_schemas" {
  for_each = var.client_names

  catalog_name = databricks_catalog.catalogs[each.key].id
  name         = "ml"
  comment      = "Machine Learning layer for ${each.key}."
  properties = {
    layer = "ml"
  }
}

resource "databricks_schema" "serving_schemas" {
  for_each = var.client_names

  catalog_name = databricks_catalog.catalogs[each.key].id
  name         = "serving"
  comment      = "Serving layer (Lakebase Postgres-backed FOREIGN tables) for ${each.key}."
  properties = {
    layer = "serving"
  }
}

resource "databricks_volume" "checkpoint_volumes" {
  for_each = var.client_names

  name         = "checkpoints"
  catalog_name = databricks_catalog.catalogs[each.key].name
  schema_name  = databricks_schema.operational_schemas[each.key].name
  volume_type  = "MANAGED"
  comment      = "Volume for Autoloader checkpoints."
}

# Workspace Catalog Binding
resource "databricks_workspace_binding" "staging_catalogs" {
  for_each = var.client_names

  securable_name = databricks_catalog.catalogs[each.key].name
  workspace_id   = var.databricks_staging_workspace_id
}

# Also bind stg catalogs to production so they remain visible there
resource "databricks_workspace_binding" "staging_catalogs_in_production" {
  for_each = var.client_names

  securable_name = databricks_catalog.catalogs[each.key].name
  workspace_id   = var.databricks_production_workspace_id
}
