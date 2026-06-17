variable "aws_account_id" {
  type        = string
  description = "A 12-digit number, such as 012345678901, that uniquely identifies an AWS account"
}

variable "aws_data_access_instance_profile_arn" {
  description = "The ARN of the IAM instance profile for Databricks cluster data access"
  type        = string
}

variable "databricks_user_developer" {
  type        = string
  description = "The email of user Developer Example"
}

variable "databricks_user_teammate" {
  type        = string
  description = "The email of user Teammate Example"
}
