# --- Users ---
resource "databricks_user" "user_teammate" {
  user_name        = "teammate@example.com"
  display_name     = "Teammate Example"
  workspace_access = true
}

resource "databricks_user_role" "teammate_account_admin" {
  user_id = databricks_user.user_teammate.id
  role    = "account_admin"
}

resource "databricks_user" "alex" {
  user_name    = "alex@example.com"
  display_name = "Alex Example"
}

resource "databricks_user" "jordan" {
  user_name    = "jordan@example.com"
  display_name = "Jordan Example"
}

resource "databricks_user" "developer_test" {
  user_name    = "developer.test@example.com"
  display_name = "Developer Example (Test)"
}

resource "databricks_user" "morgan" {
  user_name    = "morgan@example.com"
  display_name = "Morgan Example"
}

# --- Service Principals ---
resource "databricks_service_principal" "lmx_webapp_sp" {
  display_name          = "lmx-webapp-servicePrincipal"
  databricks_sql_access = true
}

# --- Groups ---
resource "databricks_group" "account_admins" {
  display_name               = "account admins"
  workspace_access           = true
  allow_cluster_create       = true
  allow_instance_pool_create = true
  databricks_sql_access      = true
}

resource "databricks_group" "data_engineers" {
  display_name               = "data engineers"
  workspace_access           = true
  allow_cluster_create       = true
  allow_instance_pool_create = true
  databricks_sql_access      = true
}

resource "databricks_group" "developers" {
  display_name               = "developers"
  workspace_access           = true
  allow_cluster_create       = false
  allow_instance_pool_create = false
  databricks_sql_access      = true
}

resource "databricks_group" "ml_developers" {
  display_name               = "ml_developers"
  workspace_access           = true
  allow_cluster_create       = true
  allow_instance_pool_create = true
  databricks_sql_access      = true
}

resource "databricks_group" "ds_admin" {
  display_name               = "ds_admin"
  workspace_access           = true
  allow_cluster_create       = true
  allow_instance_pool_create = true
  databricks_sql_access      = true
}

resource "databricks_group" "ds_data_owner" {
  display_name               = "ds_data_owner"
  workspace_access           = true
  allow_cluster_create       = false
  allow_instance_pool_create = false
  databricks_sql_access      = true
}

resource "databricks_group" "ds_data_provider" {
  display_name               = "ds_data_provider"
  workspace_access           = true
  allow_cluster_create       = false
  allow_instance_pool_create = false
  databricks_sql_access      = true
}

resource "databricks_group" "ds_data_consumer" {
  display_name               = "ds_data_consumer"
  workspace_access           = true
  allow_cluster_create       = false
  allow_instance_pool_create = false
  databricks_sql_access      = true
}

resource "databricks_group" "prod_viewers" {
  display_name               = "prod_viewers"
  workspace_access           = true
  allow_cluster_create       = false
  allow_instance_pool_create = false
  databricks_sql_access      = true
}

resource "databricks_group_member" "developer_account_admins" {
  group_id  = databricks_group.account_admins.id
  member_id = data.databricks_user.user_developer.id
}

resource "databricks_group_member" "teammate_account_admins" {
  group_id  = databricks_group.account_admins.id
  member_id = databricks_user.user_teammate.id
}

resource "databricks_group_member" "lmx_sp_admins" {
  group_id  = databricks_group.account_admins.id
  member_id = data.databricks_service_principal.lmx_sp.sp_id
}

resource "databricks_group_member" "alex_developers" {
  group_id  = databricks_group.developers.id
  member_id = databricks_user.alex.id
}

resource "databricks_group_member" "jordan_developers" {
  group_id  = databricks_group.developers.id
  member_id = databricks_user.jordan.id
}

resource "databricks_group_member" "developer_test_developers" {
  group_id  = databricks_group.developers.id
  member_id = databricks_user.developer_test.id
}

resource "databricks_group_member" "morgan_developers" {
  group_id  = databricks_group.developers.id
  member_id = databricks_user.morgan.id
}

resource "databricks_group_member" "morgan_prod_viewers" {
  group_id  = databricks_group.prod_viewers.id
  member_id = databricks_user.morgan.id
}

# --- Assignments to Workspace ---
# - User Assignments to Workspace -
resource "databricks_mws_permission_assignment" "user_teammate_development" {
  workspace_id = databricks_mws_workspaces.development.workspace_id
  principal_id = databricks_user.user_teammate.id
  permissions  = ["ADMIN"]
}

resource "databricks_mws_permission_assignment" "user_teammate_production" {
  workspace_id = databricks_mws_workspaces.production.workspace_id
  principal_id = databricks_user.user_teammate.id
  permissions  = ["ADMIN"]
}

resource "databricks_mws_permission_assignment" "user_developer_development" {
  workspace_id = databricks_mws_workspaces.development.workspace_id
  principal_id = data.databricks_user.user_developer.id
  permissions  = ["ADMIN"]
}

resource "databricks_mws_permission_assignment" "user_developer_production" {
  workspace_id = databricks_mws_workspaces.production.workspace_id
  principal_id = data.databricks_user.user_developer.id
  permissions  = ["ADMIN"]
}
# - Service Principal Assignments to Workspace -
resource "databricks_mws_permission_assignment" "sp_webapp_production" {
  workspace_id = databricks_mws_workspaces.production.workspace_id
  principal_id = databricks_service_principal.lmx_webapp_sp.id
  permissions  = ["USER"]
}

# - Group Assignments to Workspace -
resource "databricks_mws_permission_assignment" "group_developers" {
  workspace_id = databricks_mws_workspaces.development.workspace_id
  principal_id = databricks_group.developers.id
  permissions  = ["USER"]
}

resource "databricks_mws_permission_assignment" "group_ml_developers" {
  workspace_id = databricks_mws_workspaces.development.workspace_id
  principal_id = databricks_group.ml_developers.id
  permissions  = ["USER"]
}

resource "databricks_mws_permission_assignment" "group_prod_viewers" {
  workspace_id = databricks_mws_workspaces.production.workspace_id
  principal_id = databricks_group.prod_viewers.id
  permissions  = ["USER"]
}

# - Staging Workspace Assignments -
# depends_on time_sleep: permission APIs are only available after the metastore
# is fully assigned to this brand-new workspace.
resource "databricks_mws_permission_assignment" "user_developer_staging" {
  workspace_id = databricks_mws_workspaces.staging.workspace_id
  principal_id = data.databricks_user.user_developer.id
  permissions  = ["ADMIN"]
  depends_on   = [time_sleep.wait_for_staging_permissions_api]
}

resource "databricks_mws_permission_assignment" "user_teammate_staging" {
  workspace_id = databricks_mws_workspaces.staging.workspace_id
  principal_id = databricks_user.user_teammate.id
  permissions  = ["ADMIN"]
  depends_on   = [time_sleep.wait_for_staging_permissions_api]
}

resource "databricks_mws_permission_assignment" "group_developers_staging" {
  workspace_id = databricks_mws_workspaces.staging.workspace_id
  principal_id = databricks_group.developers.id
  permissions  = ["USER"]
  depends_on   = [time_sleep.wait_for_staging_permissions_api]
}

# webapp SP must be provisioned in the staging workspace before Lakebase can
# create a Postgres role for it (module.databricks_workspace_staging.lakebase).
resource "databricks_mws_permission_assignment" "sp_webapp_staging" {
  workspace_id = databricks_mws_workspaces.staging.workspace_id
  principal_id = databricks_service_principal.lmx_webapp_sp.id
  permissions  = ["USER"]
  depends_on   = [time_sleep.wait_for_staging_permissions_api]
}

# - Sandbox Workspace Assignments -
# depends_on metastore_assignment: permission APIs are only available after the
# metastore is fully assigned to the workspace.
resource "databricks_mws_permission_assignment" "user_developer_sandbox" {
  workspace_id = databricks_mws_workspaces.sandbox.workspace_id
  principal_id = data.databricks_user.user_developer.id
  permissions  = ["ADMIN"]
  depends_on   = [time_sleep.wait_for_sandbox_permissions_api]
}

resource "databricks_mws_permission_assignment" "user_teammate_sandbox" {
  workspace_id = databricks_mws_workspaces.sandbox.workspace_id
  principal_id = databricks_user.user_teammate.id
  permissions  = ["ADMIN"]
  depends_on   = [time_sleep.wait_for_sandbox_permissions_api]
}

resource "databricks_mws_permission_assignment" "group_ds_admin" {
  workspace_id = databricks_mws_workspaces.sandbox.workspace_id
  principal_id = databricks_group.ds_admin.id
  permissions  = ["ADMIN"]
  depends_on   = [time_sleep.wait_for_sandbox_permissions_api]
}

resource "databricks_mws_permission_assignment" "group_ds_data_owner" {
  workspace_id = databricks_mws_workspaces.sandbox.workspace_id
  principal_id = databricks_group.ds_data_owner.id
  permissions  = ["USER"]
  depends_on   = [time_sleep.wait_for_sandbox_permissions_api]
}

resource "databricks_mws_permission_assignment" "group_ds_data_provider" {
  workspace_id = databricks_mws_workspaces.sandbox.workspace_id
  principal_id = databricks_group.ds_data_provider.id
  permissions  = ["USER"]
  depends_on   = [time_sleep.wait_for_sandbox_permissions_api]
}

resource "databricks_mws_permission_assignment" "group_ds_data_consumer" {
  workspace_id = databricks_mws_workspaces.sandbox.workspace_id
  principal_id = databricks_group.ds_data_consumer.id
  permissions  = ["USER"]
  depends_on   = [time_sleep.wait_for_sandbox_permissions_api]
}

# --- Roles ---
resource "aws_iam_role" "cross_account_role" {
  name               = "lmx-databricks-role-crossaccount"
  assume_role_policy = data.databricks_aws_assume_role_policy.this.json

  tags = {
    Resource = "Databricks"
  }
}

resource "aws_iam_role_policy" "this" {
  name   = "lmx-databricks-role-policy"
  role   = aws_iam_role.cross_account_role.id
  policy = data.databricks_aws_crossaccount_policy.this.json
}

# Policy to allow the Databricks cross-account role to pass roles
resource "aws_iam_role_policy" "pass_role_for_data_access" {
  name = "lmx-databricks-pass-role"
  role = aws_iam_role.cross_account_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = "iam:PassRole",
        Resource = [
          aws_iam_role.data_storage_role.arn,
          aws_iam_role.glue_job_role.arn
        ]
      }
    ]
  })
}

# --- IAM management for Databricks Clusters ---
# Creates the primary IAM role for the Databricks cluster EC2 instances
resource "aws_iam_role" "data_storage_role" {
  name               = "lmx-databricks-storage-credential-role"
  description        = "IAM role for Databricks cluster access to AWS services (S3, Kinesis, etc.)"
  assume_role_policy = data.aws_iam_policy_document.assume_role_for_ec2.json

  tags = {
    Resource = "Databricks"
  }
}

# Paused 2026-05-18 — Kinesis streams in root kinesis.tf are commented out.
# resource "aws_iam_role_policy" "databricks_kinesis_write_policy" {
#   name = "write-to-kinesis-policy"
#   role = aws_iam_role.data_storage_role.id
#
#   policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [{
#       Effect = "Allow",
#       Action = [
#         "kinesis:PutRecord",
#         "kinesis:PutRecords",
#         "kinesis:DescribeStream",
#         "kinesis:ListStreams"
#       ],
#       Resource = [
#         var.aws_kinesis_acme_bronze_arn,
#         var.aws_kinesis_acme_silver_arn,
#       ]
#     }]
#   })
# }

resource "aws_iam_role_policy" "databricks_ses_policy" {
  name = "ses-send-email-policy"
  role = aws_iam_role.data_storage_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = [
        "ses:SendEmail",
        "ses:SendRawEmail"
      ],
      # SES permissions are granted for the entire region, so Resource is "*"
      Resource = "*"
    }]
  })
}

resource "aws_iam_role_policy" "databricks_assume_kinesis_role" {
  name = "assume-kinesis-role-policy"
  role = aws_iam_role.data_storage_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = "sts:AssumeRole",
      Resource = "arn:aws:iam::${var.aws_account_id}:role/lmx-databricks-kinesis-role"
    }]
  })
}

# Takes the permission slip and officially posts it on development bucket
resource "aws_s3_bucket_policy" "development" {
  bucket = var.aws_development_bucket
  policy = data.databricks_aws_bucket_policy.development.json
}

# Takes the permission slip and officially posts it on production bucket
resource "aws_s3_bucket_policy" "production" {
  bucket = var.aws_production_bucket
  policy = data.databricks_aws_bucket_policy.production.json
}

# Takes the permission slip and officially posts it on sandbox bucket
resource "aws_s3_bucket_policy" "sandbox" {
  bucket = var.aws_sandbox_bucket
  policy = data.databricks_aws_bucket_policy.sandbox.json
}

# Takes the permission slip and officially posts it on staging bucket
resource "aws_s3_bucket_policy" "staging" {
  bucket = var.aws_staging_bucket
  policy = data.databricks_aws_bucket_policy.staging.json
}

# EC2 Instance Profile for Data Access for the development bucket
resource "aws_iam_instance_profile" "data_access_instance_profile" {
  name = "lmx-databricks-data-access-profile"
  role = aws_iam_role.data_storage_role.name
}

# --- IAM management for Glue jobs
# Creates a role for Databricks jobs to trigger Glue jobs
resource "aws_iam_role" "glue_job_role" {
  name               = "lmx-databricks-glue-trigger-role"
  description        = "IAM role for Databricks to trigger a Glue job"
  assume_role_policy = data.aws_iam_policy_document.assume_role_for_ec2.json

  tags = {
    Resource = "Databricks"
  }
}

# Grants the specific permissions needed by the trigger notebook.
resource "aws_iam_policy" "databricks_glue_policy" {
  name        = "glue-trigger-policy"
  description = "Policy for Databricks to start and get status for the Glue job"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "glue:StartJobRun",
          "glue:GetJobRun"
        ]
        Resource = [
          "arn:aws:glue:${var.aws_region}:${var.aws_account_id}:job/${var.aws_glue_job_name}"
        ]
      }
    ]
  })
}

# Attaches the policy to the role
resource "aws_iam_role_policy_attachment" "attach_glue_policy" {
  role       = aws_iam_role.glue_job_role.name
  policy_arn = aws_iam_policy.databricks_glue_policy.arn
}

# EC2 Instance Profile so a Databricks job can trigger a Glue job
resource "aws_iam_instance_profile" "glue_job_instance_profile" {
  name = "lmx-databricks-glue-job-profile"
  role = aws_iam_role.glue_job_role.name
}