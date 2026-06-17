data "databricks_spark_version" "latest_lts" {
  long_term_support = true
}

data "databricks_node_type" "general_purpose" {
  # category    = "m7gd.xlarge"
  local_disk = true
  category   = "General Purpose"
}

data "databricks_catalog" "main" {
  name = "main"
}

# --- Unity Catalog policy documents ---
# Note: Root bucket IAM policies removed - only needed in development workspace

# - External (dpx-s3-prod) bucket -
# Trust policy document
data "aws_iam_policy_document" "uc_simple_trust_policy_external_production" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"

    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::100000000001:role/unity-catalog-prod-UCMasterRole-14S5ZJVKOTYTL",
        "arn:aws:iam::${var.aws_account_id}:role/dpx-databricks-uc-external-production",
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"
      values   = ["22222222-2222-2222-2222-222222222222"]
    }
  }
}

# IAM policy document
data "aws_iam_policy_document" "s3_acess_policy_external_production" {
  # S3 Bucket Permissions
  statement {
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket",
      "s3:GetBucketLocation",
      "s3:ListBucketMultipartUploads",
      "s3:ListMultipartUploadParts",
      "s3:AbortMultipartUpload",
    ]
    resources = [
      "arn:aws:s3:::${var.aws_production_bucket}/*",
      "arn:aws:s3:::${var.aws_production_bucket}",
    ]
    effect = "Allow"
  }
  # Self-Assume Role Permissions (Crucial for Databricks Storage Credentials)
  statement {
    actions   = ["sts:AssumeRole"]
    resources = ["arn:aws:iam::${var.aws_account_id}:role/dpx-databricks-uc-external-production"]
    effect    = "Allow"
  }
}

# IAM policy document for file events
# This IAM policy grants Databricks permission to update your bucket's event notification configuration, 
# create an SNS topic, create an SQS queue, and subscribe the SQS queue to the SNS topic
data "aws_iam_policy_document" "file_events_policy_external_production" {
  statement {
    sid    = "ManagedFileEventsSetupStatement"
    effect = "Allow"
    actions = [
      "s3:GetBucketNotification",
      "s3:PutBucketNotification",
      "sns:ListSubscriptionsByTopic",
      "sns:GetTopicAttributes",
      "sns:SetTopicAttributes",
      "sns:CreateTopic",
      "sns:TagResource",
      "sns:Publish",
      "sns:Subscribe",
      "sqs:CreateQueue",
      "sqs:DeleteMessage",
      "sqs:ReceiveMessage",
      "sqs:SendMessage",
      "sqs:GetQueueUrl",
      "sqs:GetQueueAttributes",
      "sqs:SetQueueAttributes",
      "sqs:TagQueue",
      "sqs:ChangeMessageVisibility",
      "sqs:PurgeQueue",
    ]
    resources = [
      "arn:aws:s3:::${var.aws_production_bucket}",
      "arn:aws:sqs:*:*:evstream-*",
      "arn:aws:sns:*:*:evstream-*",
    ]
  }
  statement {
    sid    = "ManagedFileEventsListStatement"
    effect = "Allow"
    actions = [
      "sqs:ListQueues",
      "sqs:ListQueueTags",
      "sns:ListTopics",
    ]
    resources = [
      "arn:aws:sqs:*:*:evstream-*",
      "arn:aws:sns:*:*:evstream-*",
    ]
  }
  statement {
    sid    = "ManagedFileEventsTeardownStatement"
    effect = "Allow"
    actions = [
      "sns:Unsubscribe",
      "sns:DeleteTopic",
      "sqs:DeleteQueue",
    ]
    resources = [
      "arn:aws:sqs:*:*:evstream-*",
      "arn:aws:sns:*:*:evstream-*",
    ]
  }
}