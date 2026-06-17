# --- Lakebase (Autoscaling) — serving layer for the frontend webapp ---
#
# Workspace-scoped to PRODUCTION: this module is instantiated with the
# databricks.workspace_production provider (see root main.tf), so every resource
# here is created in the lmx-production workspace.
#
# Purpose: serve metadata.connection_status to the frontend via a Postgres synced
# table, replacing the ~7s SQL-serverless-warehouse cold start with sub-second
# reads. The webapp queries Postgres directly as lmx_webapp_sp (OAuth token as the
# Postgres password). Named generically ("lmx-serving") so it can serve other
# app-facing data (e.g. gold snippets) later, not just connection_status.
#
# A synced table is a FOREIGN (POSTGRESQL_FORMAT) table registered into an
# EXISTING catalog/schema — it does NOT need a dedicated Postgres-backed UC
# catalog. We keep each client contained in its own catalog (acme in acme_prod, etc.)
# under a new "serving" schema, and give each client its own Postgres database
# inside the shared project so their storage never collides.
#
# NOTE: the databricks_postgres_* resources use the Beta Postgres (Lakebase
# Autoscaling) API. Provider pinned to >= 1.116.0 via the repo lock file.

# Lakebase Autoscaling project. Creating the project also provisions its default
# branch ("main") and a default READ_WRITE compute endpoint sized per
# default_endpoint_settings below.
resource "databricks_postgres_project" "serving" {
  project_id = "lmx-serving"

  spec = {
    pg_version             = 17
    display_name           = "lmx-serving"
    enable_pg_native_login = false # OAuth / service-principal auth only
    default_branch         = "projects/lmx-serving/branches/main"

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

  # The production Terraform SP (owns acme_prod/lmx_prod; runs this provider). The
  # project auto-created a superuser Postgres role for it (role_id sp-<app id>).
  prod_tf_sp_app_id = "11111111-1111-1111-1111-111111111111"
}

# Per-client Postgres database inside the project (keeps per-client storage isolated;
# both would otherwise map to schema "serving" table "connection_status").
resource "databricks_postgres_database" "acme" {
  database_id = "acme"
  parent      = local.lakebase_main_branch
  spec = {
    postgres_database = "acme"
    # Owner = the project's auto-created superuser role for the prod Terraform SP.
    role = "${local.lakebase_main_branch}/roles/sp-${local.prod_tf_sp_app_id}"
  }
}

# The sync pipeline reads the source as the prod Terraform SP. That SP owns the
# acme_prod catalog but the connection_status table is created at runtime by the
# b10 job (owned by the job identity), so the SP needs an explicit SELECT on it.
resource "databricks_grant" "tf_sp_select_connection_status" {
  table      = "acme_prod.metadata.connection_status"
  principal  = local.prod_tf_sp_app_id
  privileges = ["SELECT"]
}

# The acme_prod.serving UC schema (home for these FOREIGN tables) is created as part
# of the standard per-client schema suite in unity_catalog.tf
# (databricks_schema.serving_schemas), so every catalog gets a "serving" schema.

# Synced table: full-history mirror of acme_prod.metadata.connection_status into
# Postgres, registered in UC as acme_prod.serving.connection_status (FOREIGN /
# POSTGRESQL_FORMAT). TRIGGERED incremental sync (source has Change Data Feed
# enabled). Composite PK (connection_id, checked_at). This is a FULL-TABLE mirror
# — there is no column projection here, so every source column is synced
# automatically; ARRAY<STRUCT> columns (hourly_metrics, data_gaps) land as JSONB.
#
# SCHEMA CHANGES ARE NOT AUTO-PROPAGATED. A TRIGGERED synced table keeps the
# Postgres schema it was first created with; adding/removing source columns (e.g.
# the data_gap_count / data_gaps columns added for completeness subtask 3.4) is
# only picked up by RECREATING this resource. Note the recreated table is owned by
# the managed writer role (databricks_writer_24579), NOT this SP, so default
# privileges do not cover it — the webapp SELECT GRANT must be re-applied by hand.
#
# RUNBOOK — pushing a source schema change live to the frontend:
#   0. Get the new columns into the SOURCE first (ALTER TABLE ADD COLUMNS, or let
#      one b10 run add them via mergeSchema) — the recreate snapshots whatever
#      schema exists at replace time.
#   1. Recreate the synced table (re-snapshots full history with the new schema):
#        terraform apply -replace='module.databricks_workspace_production.databricks_postgres_synced_table.acme_connection_status'
#   2. Re-grant SELECT to lmx_webapp_sp (the recreate drops the out-of-band grant).
#      Connect as a superuser role, then in psql against the `acme` database:
#        -- (a) find the webapp SP role (the only UUID role that is not the prod TF SP):
#        SELECT rolname FROM pg_roles
#        WHERE rolname ~ '^[0-9a-f]{8}-' AND rolname <> '11111111-1111-1111-1111-111111111111';
#        -- (b) grant (paste the UUID from (a), keep the double quotes):
#        GRANT SELECT ON serving.connection_status TO "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx";
#        -- (c) verify — expect a row  "<uuid>"=r/databricks_writer_24579 :
#        \dp serving.connection_status
#   Connect with:
#     PGPASSWORD=$(databricks auth token -p lmx-prod | jq -r .access_token) \
#       psql "host=<endpoint-host> dbname=acme user=developer@example.com sslmode=require"
resource "databricks_postgres_synced_table" "acme_connection_status" {
  synced_table_id = "acme_prod.serving.connection_status"

  spec = {
    source_table_full_name             = "acme_prod.metadata.connection_status"
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
# Lets lmx_webapp_sp authenticate to the Lakebase endpoint via Databricks OAuth
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
# pipeline whenever the source acme_prod.metadata.connection_status changes (i.e.
# right after a b10/b11 append), so freshness tracks the source instead of a
# guessed cron. min_time_between_triggers debounces bursts.
resource "databricks_job" "connection_status_sync" {
  name = "lmx-serving - acme.connection_status sync refresh"

  task {
    task_key = "refresh_synced_table"
    pipeline_task {
      pipeline_id = databricks_postgres_synced_table.acme_connection_status.status.pipeline_id
    }
  }

  trigger {
    table_update {
      table_names                       = ["acme_prod.metadata.connection_status"]
      min_time_between_triggers_seconds = 3600
    }
  }
}
