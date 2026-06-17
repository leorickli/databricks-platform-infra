# --- Storage Credential and External Location creation ---
# Note: Root bucket storage credential is only needed in development workspace
# Production workspace uses the shared root external location for metastore access

# - External (dpx-s3-prod) bucket -
# Create the S3 policy
resource "aws_iam_policy" "s3_policy_external_production" {
  name        = "dpx-databricks-s3-policy-external-production"
  description = "Policy for Databricks UC access to S3 prod bucket"
  policy      = data.aws_iam_policy_document.s3_acess_policy_external_production.json
}

# Create the events policy
resource "aws_iam_policy" "events_policy_external_production" {
  name        = "dpx-databricks-events-policy-external-production"
  description = "Policy for Databricks UC access to events"
  policy      = data.aws_iam_policy_document.file_events_policy_external_production.json
}

# The IAM role for Unity Catalog
resource "aws_iam_role" "data_access_external_production" {
  name               = "dpx-databricks-uc-external-production"
  assume_role_policy = data.aws_iam_policy_document.uc_simple_trust_policy_external_production.json
}

# Attach the S3 policy to the role
resource "aws_iam_role_policy_attachment" "s3_attach_external_production" {
  role       = "dpx-databricks-uc-external-production"
  policy_arn = aws_iam_policy.s3_policy_external_production.arn
}

# Attach the events policy to the role
resource "aws_iam_role_policy_attachment" "events_attach_external_production" {
  role       = "dpx-databricks-uc-external-production"
  policy_arn = aws_iam_policy.events_policy_external_production.arn
}

# It was also necessary to call an API so the storage credential ID gets 
# inserted in the Metastore. Refer to the documentaiton for more information.
resource "databricks_storage_credential" "prod_bucket" {
  name           = "dpx-databricks-storage-credential-external-production"
  isolation_mode = "ISOLATION_MODE_ISOLATED"
  //cannot reference aws_iam_role directly, as it will create circular dependency
  aws_iam_role {
    role_arn = "arn:aws:iam::${var.aws_account_id}:role/dpx-databricks-uc-external-production"
  }
  comment = "Managed by TF"
}

resource "databricks_external_location" "prod_bucket" {
  name            = "dpx-databricks-external-location-external-production"
  url             = "s3://${var.aws_production_bucket}/"
  credential_name = databricks_storage_credential.prod_bucket.name
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

  name           = "${each.key}_prod"
  storage_root   = "s3://${var.aws_production_bucket}/${each.key}/"
  force_destroy  = true
  comment        = "Production environment catalog for all data assets and operational schemas for the ${each.key} client."
  isolation_mode = "ISOLATED"

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