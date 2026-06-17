variable "aws_account_id" {
  type        = string
  description = "A 12-digit number, such as 012345678901, that uniquely identifies an AWS account"
}

variable "aws_vpc_id" {
  description = "The ID of the VPC where Databricks resources will be deployed"
  type        = string
}

variable "aws_vpc_s3_endpoint" {
  description = "The Prefix List ID of the S3 Gateway VPC Endpoint"
  type        = string
}

variable "aws_region" {
  type        = string
  description = "AWS region to deploy to"
}

variable "aws_private_subnets_development" {
  description = "List of IDs of the existing development private subnets in AWS where Databricks should deploy clusters"
  type        = list(string)
}

variable "aws_private_subnets_production" {
  description = "List of IDs of the existing production private subnets in AWS where Databricks should deploy clusters"
  type        = list(string)
}

variable "aws_private_subnets_sandbox" {
  description = "List of IDs of the existing sandbox private subnets in AWS where Databricks should deploy clusters"
  type        = list(string)
}

variable "aws_development_bucket" {
  description = "AWS S3 development data bucket"
  type        = string
}

variable "aws_production_bucket" {
  description = "AWS S3 production data bucket"
  type        = string
}

variable "aws_sandbox_bucket" {
  description = "AWS S3 sandbox data bucket"
  type        = string
}

variable "aws_private_subnets_staging" {
  description = "List of IDs of the existing staging private subnets in AWS where Databricks should deploy clusters"
  type        = list(string)
}

variable "aws_staging_bucket" {
  description = "AWS S3 staging data bucket"
  type        = string
}

variable "aws_glue_job_name" {
  description = "The name of the AWS Glue job to grant access to"
  type        = string
}

# Made optional 2026-05-18 while Kinesis streams are paused at the root
# (see ../../kinesis.tf). Revert to `type = string` with no default when
# the streams are restored.
variable "aws_kinesis_acme_bronze_arn" {
  description = "The ARN of the Kinesis stream for the ACME bronze layer"
  type        = string
  default     = null
}

variable "aws_kinesis_acme_silver_arn" {
  description = "The ARN of the Kinesis stream for the ACME silver layer"
  type        = string
  default     = null
}

variable "aws_kinesis_globex_bronze_arn" {
  description = "The ARN of the Kinesis stream for the GLOBEX bronze layer"
  type        = string
  default     = null
}

variable "aws_kinesis_globex_silver_arn" {
  description = "The ARN of the Kinesis stream for the GLOBEX silver layer"
  type        = string
  default     = null
}

variable "databricks_account_id" {
  type        = string
  description = "Databricks Account ID"
}

variable "tags" {
  default     = {}
  type        = map(string)
  description = "Optional tags to add to created resources"
}