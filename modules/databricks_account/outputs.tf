output "development_workspace_id" {
  value       = databricks_mws_workspaces.development.workspace_id
  description = "The ID of the 'development' Databricks workspace"
}

output "development_workspace_url" {
  value       = databricks_mws_workspaces.development.workspace_url
  description = "URL of the development Databricks workspace"
  sensitive   = true
}

output "development_databricks_token" {
  value       = databricks_mws_workspaces.development.token[0].token_value
  description = "Databricks PAT for the development workspace"
  sensitive   = true
}

output "production_workspace_id" {
  value       = databricks_mws_workspaces.production.workspace_id
  description = "The ID of the 'production' Databricks workspace"
}

output "production_workspace_url" {
  value       = databricks_mws_workspaces.production.workspace_url
  description = "URL of the production Databricks workspace"
  sensitive   = true
}

output "production_databricks_token" {
  value       = databricks_mws_workspaces.production.token[0].token_value
  description = "Databricks PAT for the production workspace"
  sensitive   = true
}

output "user_teammate" {
  value       = databricks_user.user_teammate.user_name
  description = "The email of user Teammate Example"
  sensitive   = true
}

output "user_developer" {
  value       = data.databricks_user.user_developer.user_name
  description = "The email of user Developer Example"
  sensitive   = true
}

# For grants on UC, it must be "application_id", "display_name" will not work
output "dbt_sp_uuid" {
  value       = databricks_service_principal.dpx_dbt_sp.application_id
  description = "The UUID of the Databricks service principal for dbt"
}

output "webapp_sp_uuid" {
  value       = databricks_service_principal.dpx_webapp_sp.application_id
  description = "The UUID (application_id) of the Databricks service principal for the web app"
}

output "group_developers" {
  value       = databricks_group.developers.display_name
  description = "The display name of the developers group"
}

output "group_ml_developers" {
  value       = databricks_group.ml_developers.display_name
  description = "The display name of the ml_developers group"
}

output "group_prod_viewers" {
  value       = databricks_group.prod_viewers.display_name
  description = "The display name of the prod_viewers group"
}

output "metastore_id" {
  value       = databricks_metastore.this.metastore_id
  description = "The ID of the metastore"
}


output "data_access_instance_profile_arn" {
  value       = aws_iam_instance_profile.data_access_instance_profile.arn
  description = "The ARN of the IAM instance profile for Databricks cluster data access for the development bucket"
}

output "glue_job_instance_profile_arn" {
  value       = aws_iam_instance_profile.glue_job_instance_profile.arn
  description = "The ARN of the IAM instance profile so a Databricks job can trigger a Glue job"
}

output "databricks_cross_account_role" {
  value       = aws_iam_role.cross_account_role.arn
  description = "The ARN for the Databricks cross-account role"
}

output "databricks_root_storage_bucket" {
  value       = aws_s3_bucket.root_storage_bucket.bucket
  description = "The unique name of the Databricks root storage bucket"
}

output "sandbox_workspace_id" {
  value       = databricks_mws_workspaces.sandbox.workspace_id
  description = "The ID of the 'sandbox' Databricks workspace"
}

output "sandbox_workspace_url" {
  value       = databricks_mws_workspaces.sandbox.workspace_url
  description = "URL of the sandbox Databricks workspace"
  sensitive   = true
}

output "sandbox_databricks_token" {
  value       = databricks_mws_workspaces.sandbox.token[0].token_value
  description = "Databricks PAT for the sandbox workspace"
  sensitive   = true
}

output "staging_workspace_id" {
  value       = databricks_mws_workspaces.staging.workspace_id
  description = "The ID of the 'staging' Databricks workspace"
}

output "staging_workspace_url" {
  value       = databricks_mws_workspaces.staging.workspace_url
  description = "URL of the staging Databricks workspace"
  sensitive   = true
}

output "staging_databricks_token" {
  value       = databricks_mws_workspaces.staging.token[0].token_value
  description = "Databricks PAT for the staging workspace"
  sensitive   = true
}

output "group_ds_admin" {
  value       = databricks_group.ds_admin.display_name
  description = "The display name of the ds_admin group"
}

output "group_ds_data_owner" {
  value       = databricks_group.ds_data_owner.display_name
  description = "The display name of the ds_data_owner group"
}

output "group_ds_data_provider" {
  value       = databricks_group.ds_data_provider.display_name
  description = "The display name of the ds_data_provider group"
}

output "group_ds_data_consumer" {
  value       = databricks_group.ds_data_consumer.display_name
  description = "The display name of the ds_data_consumer group"
}