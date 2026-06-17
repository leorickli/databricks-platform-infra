# --- Instance Profile ---
resource "databricks_instance_profile" "data_access" {
  instance_profile_arn = var.aws_data_access_instance_profile_arn
  skip_validation      = true
}

# Catalog-level grants will be added here as participants onboard and their
# company catalogs are created. Each catalog will have grants scoped to the
# ds_data_owner, ds_data_provider, and ds_data_consumer groups.
