# --- Buckets ---
resource "aws_s3_bucket" "general" {
  bucket = "lmx-s3-general"

  tags = {
    Name = "s3-bucket-general"
  }
}

resource "aws_s3_bucket" "development" {
  bucket = "lmx-s3-dev"

  tags = {
    Name        = "s3-bucket-dev"
    Environment = "dev"
  }
}

resource "aws_s3_bucket" "production" {
  bucket = "lmx-s3-prod"

  tags = {
    Name        = "s3-bucket-prod"
    Environment = "prod"
  }
}

resource "aws_s3_bucket" "sandbox" {
  bucket = "lmx-s3-sandbox"

  tags = {
    Name        = "s3-bucket-sandbox"
    Environment = "sandbox"
  }
}

resource "aws_s3_bucket" "staging" {
  bucket = "lmx-s3-stg"

  tags = {
    Name        = "s3-bucket-stg"
    Environment = "stg"
  }
}

resource "aws_s3_bucket" "operational" {
  bucket = "lmx-s3-operational"

  tags = {
    Resource = "Operational"
  }
}

# --- Bucket versioning ---
resource "aws_s3_bucket_versioning" "general_versioning" {
  bucket = aws_s3_bucket.general.id
  versioning_configuration {
    status = "Disabled"
  }
}

resource "aws_s3_bucket_versioning" "development_versioning" {
  bucket = aws_s3_bucket.development.id
  versioning_configuration {
    status = "Disabled"
  }
}

resource "aws_s3_bucket_versioning" "production_versioning" {
  bucket = aws_s3_bucket.production.id
  versioning_configuration {
    status = "Disabled"
  }
}

resource "aws_s3_bucket_versioning" "sandbox_versioning" {
  bucket = aws_s3_bucket.sandbox.id
  versioning_configuration {
    status = "Disabled"
  }
}

resource "aws_s3_bucket_versioning" "staging_versioning" {
  bucket = aws_s3_bucket.staging.id
  versioning_configuration {
    status = "Disabled"
  }
}

resource "aws_s3_bucket_versioning" "operational_versioning" {
  bucket = aws_s3_bucket.operational.id
  versioning_configuration {
    status = "Enabled"
  }
}