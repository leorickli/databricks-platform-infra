# --- Glue ---
resource "aws_iam_role" "glue_role" {
  name = "lmx-glue-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "glue.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Name = "lmx-glue"
  }
}

resource "aws_iam_role_policy" "glue_policy" {
  name = "AWSGlueServicePolicy"
  role = aws_iam_role.glue_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "arn:aws:logs:*:*:*:/aws-glue/*"
      },
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
          "s3:DeleteObject"
        ],
        Resource = [
          aws_s3_bucket.development.arn,
          "${aws_s3_bucket.development.arn}/*",
          aws_s3_bucket.production.arn,
          "${aws_s3_bucket.production.arn}/*",
          aws_s3_bucket.operational.arn,
          "${aws_s3_bucket.operational.arn}/glue/*"
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets",
          "ec2:DescribeVpcs"
        ],
        Resource = "*"
      }
    ]
  })
}

# --- API Gateway --- 
resource "aws_iam_role" "api_gateway_cloudwatch_logs_role" {
  name = "lmx-api-gateway-cloudwatch-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "apigateway.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "api_gateway_cloudwatch_logs_policy_attachment" {
  role       = aws_iam_role.api_gateway_cloudwatch_logs_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

# --- Lambda ---
resource "aws_iam_role" "lambda_processor_role" {
  name = "lmx-lambda-processor-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_processor_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Paused 2026-05-18 — references aws_kinesis_stream.acme_ingestion which is
# commented out in kinesis.tf. Restore together.
# resource "aws_iam_role_policy" "lambda_kinesis_policy" {
#   name = "lambda-kinesis-policy"
#   role = aws_iam_role.lambda_processor_role.id
#
#   policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [{
#       Effect = "Allow",
#       Action = [
#         "kinesis:PutRecord",
#         "kinesis:PutRecords"
#       ],
#       Resource = aws_kinesis_stream.acme_ingestion.arn
#     }]
#   })
# }

# --- Databricks Kinesis Access ---
# This is the IAM Role that grants access to the Kinesis stream.
resource "aws_iam_role" "databricks_kinesis_role" {
  name = "lmx-databricks-kinesis-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = "sts:AssumeRole",
        Principal = {
          AWS = "arn:aws:iam::100000000006:role/lmx-databricks-storage-credential-role"
        }
      }
    ]
  })
}

# Paused 2026-05-18 — references all 5 kinesis streams (commented in kinesis.tf).
# Role above is left in place; only the policy attachment is removed.
# resource "aws_iam_role_policy" "databricks_kinesis_read_policy" {
#   name = "kinesis-read-policy"
#   role = aws_iam_role.databricks_kinesis_role.id
#
#   policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [{
#       Effect = "Allow",
#       Action = [
#         "kinesis:GetRecords",
#         "kinesis:GetShardIterator",
#         "kinesis:DescribeStream",
#         "kinesis:ListShards"
#       ],
#       Resource = [
#         aws_kinesis_stream.acme_ingestion.arn,
#         aws_kinesis_stream.acme_bronze.arn,
#         aws_kinesis_stream.acme_silver.arn,
#       ]
#     }]
#   })
# }