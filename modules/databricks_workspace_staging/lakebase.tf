# --- Lakebase (Autoscaling) — serving layer for the frontend webapp (STAGING) ---
#
# Workspace-scoped to STAGING: this module is instantiated with the
# databricks.workspace_staging provider (see root main.tf), so every resource
# here is created in the dpx-staging workspace.
#
# This mirrors modules/databricks_workspace_production/lakebase.tf one-for-one,
# swapping prod identifiers for staging (dpx-serving-stg project, acme_stg
# catalog). See that file's header for the full rationale; the only structural
# differences are the names and that staging gets its own Lakebase project so
# its Postgres storage never collides with prod's.
#
# NOTE: the databricks_postgres_* resources use the Beta Postgres (Lakebase
# Autoscaling) API. Provider pinned to >= 1.116.0 via the repo lock file.

# Lakebase Autoscaling project. Creating the project also provisions its default
# branch ("main") and a default READ_WRITE compute endpoint sized per
# default_endpoint_settings below.
resource "databricks_postgres_project" "serving" {
  project_id = "dpx-serving-stg"

  spec = {
    pg_version             = 17
    display_name           = "dpx-serving-stg"
    enable_pg_native_login = false # OAuth / service-principal auth only
    default_branch         = "projects/dpx-serving-stg/branches/main"

    default_endpoint_settings = {
      autoscaling_limit_min_cu = 0.5
      autoscaling_limit_max_cu = 4
      suspend_timeout_duration = "1800s" # suspend (scale-to-zero) after 30 min idle
    }
  }
}

locals {
  # The project auto-provisions this default branch + a READ_WRITE "primary" endpoint.
  lakebase_main_branch = "${databricks_postgres_project.serving.name}/branches/main"

  # The Terraform SP that runs every workspace provider (dpx-servicePrincipal;
  # also owns the staging catalogs). The project auto-created a superuser
  # Postgres role for it (role_id sp-<app id>). Same account SP as prod.
  stg_tf_sp_app_id = "11111111-1111-1111-1111-111111111111"
}

# Per-client Postgres database inside the project (keeps acme/globex storage isolated;
# both would otherwise map to schema "serving" table "connection_status").
resource "databricks_postgres_database" "acme" {
  database_id = "acme"
  parent      = local.lakebase_main_branch
  spec = {
    postgres_database = "acme"
    # Owner = the project's auto-created superuser role for the Terraform SP.
    role = "${local.lakebase_main_branch}/roles/sp-${local.stg_tf_sp_app_id}"
  }
}

# The sync pipeline reads the source as the Terraform SP. That SP owns the
# acme_stg catalog but the connection_status table is created at runtime by the
# b10 job (owned by the job identity), so the SP needs an explicit SELECT on it.
resource "databricks_grant" "tf_sp_select_connection_status" {
  table      = "acme_stg.metadata.connection_status"
  principal  = local.stg_tf_sp_app_id
  privileges = ["SELECT"]
}

# The acme_stg.serving UC schema (home for these FOREIGN tables) is created as part
# of the standard per-client schema suite in unity_catalog.tf
# (databricks_schema.serving_schemas), so every catalog gets a "serving" schema.

# Synced table: full-history mirror of acme_stg.metadata.connection_status into
# Postgres, registered in UC as acme_stg.serving.connection_status (FOREIGN /
# POSTGRESQL_FORMAT). TRIGGERED incremental sync (source must have Change Data
# Feed enabled — see ALTER TABLE note in the apply runbook). Composite PK
# (connection_id, checked_at); hourly_metrics ARRAY<STRUCT> lands as JSONB.
resource "databricks_postgres_synced_table" "acme_connection_status" {
  synced_table_id = "acme_stg.serving.connection_status"

  spec = {
    source_table_full_name             = "acme_stg.metadata.connection_status"
    primary_key_columns                = ["connection_id", "checked_at"]
    scheduling_policy                  = "TRIGGERED"
    postgres_database                  = databricks_postgres_database.acme.database_id
    branch                             = local.lakebase_main_branch
    create_database_objects_if_missing = true
  }

  depends_on = [
    databricks_schema.serving_schemas["acme"],
    databricks_postgres_database.acme,
    databricks_grant.tf_sp_select_connection_status,
  ]
}

# --- Frontend access: Postgres role for the webapp service principal ---
# Lets dpx_webapp_sp authenticate to the Lakebase endpoint via Databricks OAuth
# (short-lived token used as the Postgres password). The table-level SELECT on
# serving.connection_status is a Postgres GRANT (run once via psql, executed as a
# project superuser) — that in-database grant is not covered by the
# databricks_postgres_* resources, so it is applied out of band, not here.
resource "databricks_postgres_role" "webapp" {
  parent  = local.lakebase_main_branch
  role_id = "sp-${var.databricks_webapp_sp_uuid}"
  spec = {
    postgres_role = var.databricks_webapp_sp_uuid
    identity_type = "SERVICE_PRINCIPAL"
    auth_method   = "LAKEBASE_OAUTH_V1"
  }
}

# Admin login role for the platform owner (metastore owner) so a human superuser
# can run in-database GRANTs/maintenance via `databricks psql` (the project is
# OAuth-only; without a role, developer cannot connect at all).
resource "databricks_postgres_role" "developer_admin" {
  parent  = local.lakebase_main_branch
  role_id = "developer-admin"
  spec = {
    postgres_role    = "developer@example.com"
    identity_type    = "USER"
    auth_method      = "LAKEBASE_OAUTH_V1"
    membership_roles = ["DATABRICKS_SUPERUSER"]
  }
}

# --- Keep the synced table fresh ---
# TRIGGERED synced tables don't auto-refresh; this job re-runs the managed sync
# pipeline whenever the source acme_stg.metadata.connection_status changes (i.e.
# right after a b10/b11 append), so freshness tracks the source instead of a
# guessed cron. min_time_between_triggers debounces bursts.
resource "databricks_job" "connection_status_sync" {
  name = "dpx-serving-stg - acme.connection_status sync refresh"

  task {
    task_key = "refresh_synced_table"
    pipeline_task {
      pipeline_id = databricks_postgres_synced_table.acme_connection_status.status.pipeline_id
    }
  }

  trigger {
    table_update {
      table_names                       = ["acme_stg.metadata.connection_status"]
      min_time_between_triggers_seconds = 3600
    }
  }
}
