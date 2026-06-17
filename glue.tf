# Define the script names here
locals {
  acme_glue_job = "acme_glue_job"
}

# Acme Glue job
resource "aws_glue_job" "acme_ingestion" {
  name              = local.acme_glue_job
  description       = "Glue job for batch ingestion scheduled by Databricks Workflows."
  glue_version      = "5.0"
  worker_type       = "G.1X"
  number_of_workers = 2
  timeout           = 120
  execution_class   = "STANDARD"
  role_arn          = aws_iam_role.glue_role.arn

  command {
    script_location = "s3://${aws_s3_bucket.operational.bucket}/glue/scripts/${local.acme_glue_job}.py"
    python_version  = "3"
  }

  default_arguments = {
    "--job-language"        = "python"
    "--enable-job-insights" = "true"
  }

  source_control_details {
    provider      = "GITHUB"
    owner         = "Getdataplatform"
    repository    = "lmx-data"
    branch        = "main"
    folder        = "src/clients/acme/glue"
    auth_strategy = "AWS_SECRETS_MANAGER"
    auth_token    = local.db_creds.aws_glue_cicd_github
  }

  # So it doesn't ask to update auth_token every time you use `terraform plan` or `terraform apply`
  lifecycle { ignore_changes = [source_control_details] }
}

# # Jobs now scheduled by Databricks Workflows
# resource "aws_glue_trigger" "acme_ingestion" {
#   name     = "daily at 11:00am"
#   schedule = "cron(0 11 * * ? *)"
#   type     = "SCHEDULED"

#   actions {
#     job_name = aws_glue_job.acme_ingestion.name
#   }
# }