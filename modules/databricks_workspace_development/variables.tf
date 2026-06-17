variable "aws_development_bucket" {
  description = "AWS S3 development data bucket"
  type        = string
}

variable "aws_account_id" {
  type        = string
  description = "A 12-digit number, such as 012345678901, that uniquely identifies an AWS account"
}

variable "aws_data_access_instance_profile_arn" {
  description = "The ARN of the IAM instance profile for Databricks cluster data access for the development bucket"
  type        = string
}

variable "aws_glue_job_instance_profile_arn" {
  description = "The ARN of the IAM instance profile so a Databricks job can trigger a Glue job"
  type        = string
}

variable "databricks_root_storage_bucket" {
  description = "The unique name of the Databricks root storage bucket"
  type        = string
}

variable "databricks_account_id" {
  type        = string
  description = "Databricks Account ID"
}

variable "databricks_development_workspace_id" {
  description = "The ID of the development workspace"
  type        = string
}

variable "databricks_production_workspace_id" {
  description = "The ID of the production workspace (dev catalogs are also bound here for cross-env visibility)"
  type        = string
}

variable "databricks_metastore_id" {
  description = "The ID of the metastore"
  type        = string
}

variable "databricks_user_teammate" {
  description = "The email of user Teammate Example"
  type        = string
}

variable "databricks_user_developer" {
  type        = string
  description = "The email of user Developer Example"
}

variable "databricks_group_developers" {
  type        = string
  description = "The display name of the developers group"
}

variable "databricks_group_ml_developers" {
  type        = string
  description = "The display name of the ml_developers group"
}

variable "databricks_webapp_sp_uuid" {
  type        = string
  description = "The UUID of the Databricks service principal for the web app"
}

variable "databricks_cross_account_role" {
  description = "The IAM role that for Databricks cross account"
  type        = string
}