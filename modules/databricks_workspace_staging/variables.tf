variable "aws_staging_bucket" {
  description = "AWS S3 staging data bucket"
  type        = string
}

variable "aws_account_id" {
  type        = string
  description = "A 12-digit number that uniquely identifies an AWS account"
}

variable "aws_data_access_instance_profile_arn" {
  description = "The ARN of the IAM instance profile for Databricks cluster data access for the staging bucket"
  type        = string
}

variable "aws_glue_job_instance_profile_arn" {
  description = "The ARN of the IAM instance profile so a Databricks job can trigger a Glue job"
  type        = string
}

variable "databricks_staging_workspace_id" {
  type        = string
  description = "The ID of the staging Databricks workspace"
}

variable "databricks_production_workspace_id" {
  type        = string
  description = "The ID of the production Databricks workspace"
}

variable "databricks_user_teammate" {
  description = "The email of user Teammate Example"
  type        = string
}

variable "databricks_user_developer" {
  type        = string
  description = "The email of user Developer Example"
}

variable "databricks_dbt_sp_uuid" {
  type        = string
  description = "The UUID of the Databricks service principal for dbt"
}

variable "databricks_webapp_sp_uuid" {
  type        = string
  description = "The UUID (application_id) of the Databricks service principal for the web app (Lakebase serving access)"
}

variable "databricks_group_developers" {
  type        = string
  description = "The display name of the developers group"
}
