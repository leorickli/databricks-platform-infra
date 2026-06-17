locals {
  private_subnet_map = zipmap(
    module.vpc.private_subnets_cidr_blocks,
    module.vpc.private_subnets
  )

  private_subnets_for_databricks_development = [
    for cidr in local.databricks_private_subnets_development : local.private_subnet_map[cidr]
  ]

  private_subnets_for_databricks_production = [
    for cidr in local.databricks_private_subnets_production : local.private_subnet_map[cidr]
  ]

  private_subnets_for_databricks_sandbox = [
    for cidr in local.databricks_private_subnets_sandbox : local.private_subnet_map[cidr]
  ]

  private_subnets_for_databricks_staging = [
    for cidr in local.databricks_private_subnets_staging : local.private_subnet_map[cidr]
  ]
}

module "databricks_account" {
  source = "./modules/databricks_account"

  providers = {
    databricks = databricks.mws
  }

  aws_account_id                  = local.db_creds.aws_account_id
  aws_vpc_id                      = module.vpc.vpc_id
  aws_region                      = var.aws_region
  aws_private_subnets_development = local.private_subnets_for_databricks_development
  aws_private_subnets_production  = local.private_subnets_for_databricks_production
  aws_private_subnets_sandbox  = local.private_subnets_for_databricks_sandbox
  aws_private_subnets_staging     = local.private_subnets_for_databricks_staging
  aws_vpc_s3_endpoint             = aws_vpc_endpoint.s3_gateway_shared.prefix_list_id
  aws_development_bucket          = aws_s3_bucket.development.bucket
  aws_production_bucket           = aws_s3_bucket.production.bucket
  aws_sandbox_bucket           = aws_s3_bucket.sandbox.bucket
  aws_staging_bucket              = aws_s3_bucket.staging.bucket
  aws_glue_job_name               = aws_glue_job.acme_ingestion.name
  # Kinesis streams paused 2026-05-18 — see kinesis.tf. Module vars now have
  # default = null so these inputs are optional.
  # aws_kinesis_acme_bronze_arn      = aws_kinesis_stream.acme_bronze.arn
  # aws_kinesis_acme_silver_arn      = aws_kinesis_stream.acme_silver.arn
  # aws_kinesis_globex_bronze_arn      = aws_kinesis_stream.globex_bronze.arn
  # aws_kinesis_globex_silver_arn      = aws_kinesis_stream.globex_silver.arn
  databricks_account_id = local.db_creds.databricks_account_id
}

module "databricks_workspace_development" {
  source = "./modules/databricks_workspace_development"

  providers = {
    databricks = databricks.workspace_development
  }

  aws_account_id                       = local.db_creds.aws_account_id
  aws_development_bucket               = aws_s3_bucket.development.bucket
  aws_data_access_instance_profile_arn = module.databricks_account.data_access_instance_profile_arn
  aws_glue_job_instance_profile_arn    = module.databricks_account.glue_job_instance_profile_arn
  databricks_account_id                = local.db_creds.databricks_account_id
  databricks_development_workspace_id  = module.databricks_account.development_workspace_id
  databricks_production_workspace_id   = module.databricks_account.production_workspace_id
  databricks_metastore_id              = module.databricks_account.metastore_id
  databricks_user_teammate                = module.databricks_account.user_teammate
  databricks_user_developer             = module.databricks_account.user_developer
  databricks_group_developers          = module.databricks_account.group_developers
  databricks_group_ml_developers       = module.databricks_account.group_ml_developers
  databricks_webapp_sp_uuid            = module.databricks_account.webapp_sp_uuid
  databricks_root_storage_bucket       = module.databricks_account.databricks_root_storage_bucket
  databricks_cross_account_role        = module.databricks_account.databricks_cross_account_role
}

module "databricks_workspace_production" {
  source = "./modules/databricks_workspace_production"

  providers = {
    databricks = databricks.workspace_production
  }

  aws_account_id                       = local.db_creds.aws_account_id
  aws_production_bucket                = aws_s3_bucket.production.bucket
  aws_data_access_instance_profile_arn = module.databricks_account.data_access_instance_profile_arn
  aws_glue_job_instance_profile_arn    = module.databricks_account.glue_job_instance_profile_arn
  databricks_account_id                = local.db_creds.databricks_account_id
  databricks_production_workspace_id   = module.databricks_account.production_workspace_id
  databricks_metastore_id              = module.databricks_account.metastore_id
  databricks_user_teammate                = module.databricks_account.user_teammate
  databricks_user_developer             = module.databricks_account.user_developer
  databricks_dbt_sp_uuid               = module.databricks_account.dbt_sp_uuid
  databricks_webapp_sp_uuid            = module.databricks_account.webapp_sp_uuid
  databricks_group_developers          = module.databricks_account.group_developers
  databricks_group_prod_viewers        = module.databricks_account.group_prod_viewers
  databricks_cross_account_role        = module.databricks_account.databricks_cross_account_role
}

module "databricks_workspace_sandbox" {
  source = "./modules/databricks_workspace_sandbox"

  providers = {
    databricks = databricks.workspace_sandbox
  }

  aws_account_id                       = local.db_creds.aws_account_id
  aws_data_access_instance_profile_arn = module.databricks_account.data_access_instance_profile_arn
  databricks_user_developer             = module.databricks_account.user_developer
  databricks_user_teammate                = module.databricks_account.user_teammate
}

module "databricks_workspace_staging" {
  source = "./modules/databricks_workspace_staging"

  providers = {
    databricks = databricks.workspace_staging
  }

  aws_account_id                       = local.db_creds.aws_account_id
  aws_staging_bucket                   = aws_s3_bucket.staging.bucket
  aws_data_access_instance_profile_arn = module.databricks_account.data_access_instance_profile_arn
  aws_glue_job_instance_profile_arn    = module.databricks_account.glue_job_instance_profile_arn
  databricks_user_teammate                = module.databricks_account.user_teammate
  databricks_user_developer             = module.databricks_account.user_developer
  databricks_dbt_sp_uuid               = module.databricks_account.dbt_sp_uuid
  databricks_webapp_sp_uuid            = module.databricks_account.webapp_sp_uuid
  databricks_group_developers          = module.databricks_account.group_developers
  databricks_staging_workspace_id      = module.databricks_account.staging_workspace_id
  databricks_production_workspace_id   = module.databricks_account.production_workspace_id
}