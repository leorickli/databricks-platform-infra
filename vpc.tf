locals {
  vpc_name = "dpx-vpc"
  vpc_cidr = "10.16.0.0/16"
  azs      = slice(data.aws_availability_zones.available.names, 0, 2)

  public_subnets                         = ["10.16.0.0/24"]
  databricks_private_subnets_development = ["10.16.16.0/24", "10.16.17.0/24"]
  databricks_private_subnets_production  = ["10.16.18.0/24", "10.16.19.0/24"]
  databricks_private_subnets_sandbox  = ["10.16.20.0/24", "10.16.21.0/24"]
  databricks_private_subnets_staging     = ["10.16.22.0/24", "10.16.23.0/24"]
  glue_private_subnets                   = ["10.16.32.0/24"]
  ec2_subnets                            = ["10.16.48.0/24"]
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.21.0"

  name = local.vpc_name
  cidr = local.vpc_cidr
  azs  = local.azs

  public_subnets = local.public_subnets
  private_subnets = concat(
    local.databricks_private_subnets_development,
    local.databricks_private_subnets_production,
    local.glue_private_subnets,
    local.ec2_subnets,
    local.databricks_private_subnets_sandbox,
    local.databricks_private_subnets_staging,
  )

  enable_dns_hostnames = true
  enable_nat_gateway   = true
  single_nat_gateway   = true
  create_igw           = true

  tags = {
    Name = "dpx-vpc"
  }
}

# S3 VPC Gateway Endpoint
resource "aws_vpc_endpoint" "s3_gateway_shared" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway" # Gateway endpoint for S3

  # Associate the endpoint with the route table of the private subnets
  route_table_ids = module.vpc.private_route_table_ids

  tags = {
    Name = "dpx-s3-shared-gateway-endpoint"
  }
}

# --- Security Group for Glue ---
resource "aws_security_group" "glue_sg" {
  name        = "dpx-glue-sg"
  vpc_id      = module.vpc.vpc_id
  description = "Security group for AWS Glue job - controls network access"

  # Egress Rules
  # Allow outbound HTTPS traffic to the internet (routed via NAT Gateway from private subnet)
  egress {
    description = "Allow outbound HTTPS traffic to the internet"
    from_port   = 443 # HTTPS
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow outbound HTTPS traffic specifically to the S3 VPC endpoint
  egress {
    description = "Allow outbound HTTPS to S3 via VPC Endpoint"
    from_port   = 443 # HTTPS
    to_port     = 443
    protocol    = "tcp"
    # Reference the prefix list ID of the S3 Gateway Endpoint
    prefix_list_ids = [aws_vpc_endpoint.s3_gateway_shared.prefix_list_id]
  }

  tags = {
    Name = "dpx-glue-sg"
  }
}