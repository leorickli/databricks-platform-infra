resource "aws_security_group" "databricks_sg" {
  name        = "lmx-databricks-sg"
  vpc_id      = var.aws_vpc_id
  description = "Security group for Databricks clusters - controls network access"

  # --- Egress Rules ---
  # Allow outbound HTTPS traffic to the Databricks control plane
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow outbound HTTPS to Databricks control plane and internet (if needed)"
  }

  # Allow outbound HTTPS traffic specifically to the S3 VPC endpoint
  egress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    prefix_list_ids = [var.aws_vpc_s3_endpoint]
    description     = "Allow outbound HTTPS to S3 via VPC Endpoint"
  }

  # Allow outbound traffic for DNS resolution
  egress {
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow outbound UDP for DNS"
  }

  egress {
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow outbound TCP for DNS"
  }

  # Allow outbound traffic for NTP (Network Time Protocol)
  egress {
    from_port   = 123
    to_port     = 123
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow outbound UDP for NTP"
  }

  # Allow outbound traffic to Databricks control plane on new required ports (8443-8451)
  egress {
    from_port   = 8443
    to_port     = 8451
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow outbound connections to Databricks control plane on ports 8443-8451"
  }

  # Allow all outbound TCP traffic within the security group (for inter-cluster communication)
  egress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    self        = true
    description = "Allow outbound TCP within the Databricks cluster security group"
  }

  # Allow all outbound UDP traffic within the security group (for inter-cluster communication)
  egress {
    from_port   = 0
    to_port     = 65535
    protocol    = "udp"
    self        = true
    description = "Allow outbound UDP within the Databricks cluster security group"
  }

  # Allow outbound traffic for SMTPS
  egress {
    from_port   = 465
    to_port     = 465
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow outbound SMTPS for sending emails"
  }

  # Allow outbound traffic for SMTP Submission
  egress {
    from_port   = 587
    to_port     = 587
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow outbound SMTP Submission for sending emails"
  }

  # Allow outbound traffic for Kafka/Confluent Cloud (standard Kafka ports)
  egress {
    from_port   = 9092
    to_port     = 9095
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow outbound connections to Kafka/Confluent Cloud brokers"
  }

  # Allow outbound traffic to PostgreSQL
  egress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.16.0.0/16"]
    description = "Allow outbound to internal Aurora PostgreSQL"
  }

  # --- Ingress Rules ---
  # Allow all traffic within the security group (for inter-cluster communication)
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
    description = "Allow all traffic within the Databricks cluster security group"
  }

  tags = {
    Name = "lmx-databricks-sg"
  }
}

module "vpc_endpoints" {
  source  = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
  version = "3.2.0"

  vpc_id             = var.aws_vpc_id
  security_group_ids = [aws_security_group.databricks_sg.id]

  endpoints = {
    sts = {
      service             = "sts"
      private_dns_enabled = true
      # development only as it already contains one subnet for each AZ
      subnet_ids = var.aws_private_subnets_development
      tags = {
        Name = "lmx-sts-vpc-endpoint"
      }
    },
    kinesis-streams = {
      service             = "kinesis-streams"
      private_dns_enabled = true
      # development only as it already contains one subnet for each AZ
      subnet_ids = var.aws_private_subnets_development
      tags = {
        Name = "lmx-kinesis-vpc-endpoint"
      }
    },
  }

  tags = {
    Name = "lmx-databricks-endpoints"
  }
}