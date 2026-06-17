# --- Storage Credential and External Location creation ---
# - Root (dpx-databricks-root) bucket -
# Create the S3 policy
resource "aws_iam_policy" "s3_policy_root" {
  name        = "dpx-databricks-s3-policy-root"
  description = "Policy for Databricks UC access to S3 root bucket"
  policy      = data.aws_iam_policy_document.s3_acess_policy_root.json
}

# Create the events policy
resource "aws_iam_policy" "events_policy_root" {
  name        = "dpx-databricks-events-policy-root"
  description = "Policy for Databricks UC access to events"
  policy      = data.aws_iam_policy_document.file_events_policy_root.json
}

# The IAM role for Unity Catalog
resource "aws_iam_role" "data_access_root" {
  name               = "dpx-databricks-uc-root"
  assume_role_policy = data.aws_iam_policy_document.uc_simple_trust_policy_root.json
}

# Attach the S3 policy to the role
resource "aws_iam_role_policy_attachment" "s3_attach_root" {
  role       = "dpx-databricks-uc-root"
  policy_arn = aws_iam_policy.s3_policy_root.arn
}

# Attach the events policy to the role
resource "aws_iam_role_policy_attachment" "events_attach_root" {
  role       = "dpx-databricks-uc-root"
  policy_arn = aws_iam_policy.events_policy_root.arn
}

resource "databricks_storage_credential" "root_bucket" {
  name           = "dpx-databricks-storage-credential-root"
  isolation_mode = "ISOLATION_MODE_ISOLATED"
  //cannot reference aws_iam_role directly, as it will create circular dependency
  aws_iam_role {
    role_arn = "arn:aws:iam::${var.aws_account_id}:role/dpx-databricks-uc-root"
  }
  comment = "Managed by TF"
}

resource "databricks_external_location" "root_bucket" {
  name            = "dpx-databricks-external-location-root"
  url             = "s3://${var.databricks_root_storage_bucket}/metastore/${var.databricks_metastore_id}"
  credential_name = databricks_storage_credential.root_bucket.name
  force_destroy   = true
  comment         = "Managed by TF"
}

# - External (dpx-s3-dev) bucket -
# Create the S3 policy
resource "aws_iam_policy" "s3_policy_external_development" {
  name        = "dpx-databricks-s3-policy-external-development"
  description = "Policy for Databricks UC access to S3 dev bucket"
  policy      = data.aws_iam_policy_document.s3_acess_policy_external_development.json
}

# Create the events policy
resource "aws_iam_policy" "events_policy_external_development" {
  name        = "dpx-databricks-events-policy-external-development"
  description = "Policy for Databricks UC access to events"
  policy      = data.aws_iam_policy_document.file_events_policy_external_development.json
}

# The IAM role for Unity Catalog
resource "aws_iam_role" "data_access_external_development" {
  name               = "dpx-databricks-uc-external-development"
  assume_role_policy = data.aws_iam_policy_document.uc_simple_trust_policy_external_development.json
}

# Attach the S3 policy to the role
resource "aws_iam_role_policy_attachment" "s3_attach_external_development" {
  role       = "dpx-databricks-uc-external-development"
  policy_arn = aws_iam_policy.s3_policy_external_development.arn
}

# Attach the events policy to the role
resource "aws_iam_role_policy_attachment" "events_attach_external_development" {
  role       = "dpx-databricks-uc-external-development"
  policy_arn = aws_iam_policy.events_policy_external_development.arn
}

# It was also necessary to call an API so the storage credential ID gets 
# inserted in the Metastore. Refer to the documentaiton for more information.
resource "databricks_storage_credential" "dev_bucket" {
  name           = "dpx-databricks-storage-credential-external-development"
  isolation_mode = "ISOLATION_MODE_ISOLATED"
  //cannot reference aws_iam_role directly, as it will create circular dependency
  aws_iam_role {
    role_arn = "arn:aws:iam::${var.aws_account_id}:role/dpx-databricks-uc-external-development"
  }
  comment = "Managed by TF"
}

resource "databricks_external_location" "dev_bucket" {
  name            = "dpx-databricks-external-location-external-development"
  url             = "s3://${var.aws_development_bucket}/"
  credential_name = databricks_storage_credential.dev_bucket.name
  isolation_mode  = "ISOLATION_MODE_ISOLATED"
  force_destroy   = true
  comment         = "Managed by TF"
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

  name           = "${each.key}_dev"
  storage_root   = "s3://${var.aws_development_bucket}/${each.key}/"
  force_destroy  = true
  isolation_mode = "ISOLATED"
  comment        = "Development environment catalog for all data assets and operational schemas for the ${each.key} client."

  properties = {
    type = "client"
  }
}

# Static identifier schemas
resource "databricks_schema" "land_schemas" {
  for_each = var.client_names

  # 3. Reference the specific catalog instance using bracket notation
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

resource "databricks_volume" "checkpoint_volumes" {
  for_each = var.client_names

  name         = "checkpoints"
  catalog_name = databricks_catalog.catalogs[each.key].name
  schema_name  = databricks_schema.operational_schemas[each.key].name
  volume_type  = "MANAGED"
  comment      = "Volume for Autoloader checkpoints."
}

# Workspace Catalog Binding
resource "databricks_workspace_binding" "development_catalogs" {
  for_each = var.client_names

  securable_name = databricks_catalog.catalogs[each.key].name
  workspace_id   = var.databricks_development_workspace_id
}

# Also bind dev catalogs to production so they remain visible there
resource "databricks_workspace_binding" "development_catalogs_in_production" {
  for_each = var.client_names

  securable_name = databricks_catalog.catalogs[each.key].name
  workspace_id   = var.databricks_production_workspace_id
}