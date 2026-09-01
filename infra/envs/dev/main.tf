terraform {
  required_version = ">= 1.15.8"

  backend "s3" {}

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "terraform"
    }
  }

  ignore_tags {
    keys = ["Environment", "Project", "ManagedBy"]
  }
}

data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" {
  state = "available"
}

# --- 1. Networking (VPC, Subnets, Gateway) ---

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-${var.environment}-vpc"
  }
}

resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 4, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-${var.environment}-public-${count.index + 1}"
  }
}

resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, count.index + 2)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "${var.project_name}-${var.environment}-private-${count.index + 1}"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-${var.environment}-igw"
  }
}

resource "aws_eip" "nat" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name = "${var.project_name}-${var.environment}-nat"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-public-rt"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-private-rt"
  }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# --- 2. Security Groups ---

resource "aws_security_group" "db_proxy" {
  name        = "${var.project_name}-${var.environment}-db-proxy-sg"
  description = "Security group for RDS Proxy"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "rds" {
  name        = "${var.project_name}-${var.environment}-rds-sg"
  description = "Security group for RDS PostgreSQL instance"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.db_proxy.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- 3. Secrets Manager & DB Credentials ---

resource "random_password" "master_password" {
  length  = 32
  special = false
}

locals {
  db_secrets = ["master", "auth", "platform", "docbridge"]
}

resource "aws_secretsmanager_secret" "db_secrets" {
  for_each                = toset(local.db_secrets)
  name                    = "${var.project_name}/${var.environment}/db/${each.key}"
  recovery_window_in_days = 0 # Immediate deletion on teardown per runbook section 4 / 5.5
}

resource "aws_secretsmanager_secret_version" "db_master_secret_val" {
  secret_id = aws_secretsmanager_secret.db_secrets["master"].id
  secret_string = jsonencode({
    username = "postgres"
    password = random_password.master_password.result
    engine   = "postgres"
    host     = aws_db_instance.dev.address
    port     = 5432
  })
}

# --- 4. RDS PostgreSQL Instance ---

resource "aws_db_subnet_group" "dev" {
  name       = "${var.project_name}-${var.environment}-subnet-group"
  subnet_ids = aws_subnet.private[*].id
}

resource "aws_db_instance" "dev" {
  identifier                 = "${var.project_name}-${var.environment}"
  engine                     = "postgres"
  engine_version             = var.db_engine_version
  instance_class             = var.db_instance_class
  allocated_storage          = var.allocated_storage
  storage_type               = "gp3"
  storage_encrypted          = true
  publicly_accessible        = false
  db_subnet_group_name       = aws_db_subnet_group.dev.name
  vpc_security_group_ids     = [aws_security_group.rds.id]
  username                   = "postgres"
  password                   = random_password.master_password.result
  skip_final_snapshot        = true
  deletion_protection        = false
  auto_minor_version_upgrade = true
}

# --- 5. RDS Proxy ---

resource "aws_iam_role" "rds_proxy_role" {
  name = "${var.project_name}-${var.environment}-rds-proxy-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "rds.amazonaws.com"
      }
    }]
  })

  lifecycle {
    ignore_changes = [tags, tags_all]
  }
}

resource "aws_iam_role_policy" "rds_proxy_policy" {
  name = "${var.project_name}-${var.environment}-rds-proxy-policy"
  role = aws_iam_role.rds_proxy_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action   = ["secretsmanager:GetSecretValue"]
      Effect   = "Allow"
      Resource = [for s in aws_secretsmanager_secret.db_secrets : s.arn]
    }]
  })
}

resource "aws_db_proxy" "dev" {
  name                   = "${var.project_name}-${var.environment}"
  debug_logging          = false
  engine_family          = "POSTGRESQL"
  idle_client_timeout    = 1800
  require_tls            = true
  role_arn               = aws_iam_role.rds_proxy_role.arn
  vpc_security_group_ids = [aws_security_group.db_proxy.id]
  vpc_subnet_ids         = aws_subnet.private[*].id

  auth {
    auth_scheme = "SECRETS"
    iam_auth    = "DISABLED"
    secret_arn  = aws_secretsmanager_secret.db_secrets["master"].arn
  }
}

resource "aws_db_proxy_default_target_group" "dev" {
  db_proxy_name = aws_db_proxy.dev.name

  connection_pool_config {
    max_connections_percent = 100
  }
}

resource "aws_db_proxy_target" "dev" {
  db_instance_identifier = aws_db_instance.dev.identifier
  db_proxy_name          = aws_db_proxy.dev.name
  target_group_name      = aws_db_proxy_default_target_group.dev.name
}

# --- 6. S3 Staging Bucket ---

resource "aws_kms_key" "staging" {
  description             = "KMS key for ${var.project_name}-${var.environment} staging bucket"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  lifecycle {
    ignore_changes = [tags, tags_all]
  }
}

resource "aws_s3_bucket" "staging" {
  bucket        = "${var.project_name}-${var.environment}-staging-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "staging" {
  bucket = aws_s3_bucket.staging.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.staging.arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "staging" {
  bucket = aws_s3_bucket.staging.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "staging" {
  bucket = aws_s3_bucket.staging.id

  rule {
    id     = "expire-30d-abort-multipart-7d"
    status = "Enabled"

    expiration {
      days = 30
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

resource "aws_s3_bucket_policy" "staging_tls_only" {
  bucket = aws_s3_bucket.staging.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "EnforceTLSRequestsOnly"
      Effect    = "Deny"
      Principal = "*"
      Action    = "s3:*"
      Resource = [
        aws_s3_bucket.staging.arn,
        "${aws_s3_bucket.staging.arn}/*"
      ]
      Condition = {
        Bool = {
          "aws:SecureTransport" = "false"
        }
      }
    }]
  })
}

# --- 7. CloudFront SPA Distribution ---

resource "aws_s3_bucket" "spa" {
  bucket        = "${var.project_name}-${var.environment}-spa-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "spa" {
  bucket = aws_s3_bucket.spa.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_cloudfront_origin_access_control" "spa" {
  name                              = "${var.project_name}-${var.environment}-spa-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "spa" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  origin {
    domain_name              = aws_s3_bucket.spa.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.spa.id
    origin_id                = "S3-${aws_s3_bucket.spa.id}"
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.spa.id}"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}