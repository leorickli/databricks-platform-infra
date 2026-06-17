# Adoption of the staging UC storage credential + external location that were
# bootstrapped by scripts/setup_staging_uc.py (see the resources in
# modules/databricks_workspace_staging/unity_catalog.tf).
#
# These import via the `databricks.workspace_staging` provider, which only works
# once the staging workspace exists — so apply the staging workspace FIRST
# (e.g. `terraform apply -target=module.databricks_account`), then a full apply
# resolves these imports.
#
# TEMPORARY: once `terraform plan` shows these two as imported with no further
# changes, delete this file — import blocks are one-shot and only need to be
# present for the apply that adopts the resources.

import {
  to = module.databricks_workspace_staging.databricks_storage_credential.stg_bucket
  id = "lmx-databricks-storage-credential-external-staging"
}

import {
  to = module.databricks_workspace_staging.databricks_external_location.stg_bucket
  id = "lmx-databricks-external-location-external-staging"
}
