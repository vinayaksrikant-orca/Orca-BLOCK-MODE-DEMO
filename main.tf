# INTENTIONALLY MISCONFIGURED TERRAFORM
# Triggers: IaC scan findings on Orca
# Covers: AWS S3, EC2, RDS, IAM, Security Groups, KMS, EKS

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region     = "us-east-1"
  # Hardcoded credentials in provider - secret scan trigger
  access_key = "AKIAIOSFODNN7EXAMPLE"
  secret_key = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
}

# ── S3 Misconfigurations ──────────────────────────────────────────────────────

# Public S3 bucket - data exposure
resource "aws_s3_bucket" "public_data" {
  bucket = "my-totally-public-bucket-12345"
}

resource "aws_s3_bucket_acl" "public_data_acl" {
  bucket = aws_s3_bucket.public_data.id
  acl    = "public-read-write"  # PUBLIC READ-WRITE - critical finding
}

# No versioning enabled
resource "aws_s3_bucket" "no_versioning" {
  bucket = "my-unversioned-bucket"
}

# No encryption on S3 bucket
resource "aws_s3_bucket" "unencrypted_bucket" {
  bucket = "my-unencrypted-bucket"
  # Missing: server_side_encryption_configuration
}

# Logging disabled
resource "aws_s3_bucket" "no_logging" {
  bucket = "my-no-logging-bucket"
  # Missing: logging block
}

# No MFA delete protection
resource "aws_s3_bucket_versioning" "no_mfa" {
  bucket = aws_s3_bucket.no_versioning.id
  versioning_configuration {
    status     = "Enabled"
    mfa_delete = "Disabled"  # MFA delete disabled
  }
}

# S3 public access block not configured
resource "aws_s3_bucket_public_access_block" "not_blocked" {
  bucket                  = aws_s3_bucket.public_data.id
  block_public_acls       = false   # NOT blocked
  block_public_policy     = false   # NOT blocked
  ignore_public_acls      = false   # NOT blocked
  restrict_public_buckets = false   # NOT blocked
}

# ── Security Group Misconfigurations ─────────────────────────────────────────

# Security group open to the world - all ports
resource "aws_security_group" "wide_open" {
  name        = "wide-open-sg"
  description = "Wide open security group for testing"

  # SSH open to internet
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]   # SSH open to ENTIRE internet
  }

  # RDP open to internet
  ingress {
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]   # RDP open to ENTIRE internet
  }

  # All ports open
  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]   # ALL TCP ports open to internet
  }

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]   # ALL traffic allowed - critical
  }

  # Unrestricted egress
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ── EC2 Misconfigurations ─────────────────────────────────────────────────────

resource "aws_instance" "vulnerable_ec2" {
  ami                    = "ami-0123456789abcdef0"  # old AMI
  instance_type          = "t2.micro"
  subnet_id              = "subnet-12345678"
  vpc_security_group_ids = [aws_security_group.wide_open.id]
  
  # Public IP enabled - unnecessary exposure
  associate_public_ip_address = true

  # No IMDSv2 enforced - metadata service v1 attack
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "optional"  # IMDSv2 not enforced
    http_put_response_hop_limit = 1
  }

  # EBS root volume not encrypted
  root_block_device {
    volume_type           = "gp2"
    volume_size           = 20
    encrypted             = false   # unencrypted root volume
    delete_on_termination = true
  }

  # Hardcoded user data with secrets
  user_data = <<-EOT
    #!/bin/bash
    export DB_PASSWORD="SuperSecret@Password123!"
    export AWS_SECRET="wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
    pip install -r requirements.txt
  EOT

  # No detailed monitoring
  monitoring = false

  tags = {
    Name = "vulnerable-instance"
  }
}

# ── RDS Misconfigurations ─────────────────────────────────────────────────────

resource "aws_db_instance" "insecure_rds" {
  identifier             = "insecure-production-db"
  engine                 = "mysql"
  engine_version         = "5.7"          # outdated version
  instance_class         = "db.t2.micro"
  allocated_storage      = 20

  # Hardcoded credentials
  username               = "admin"
  password               = "Password123!"  # hardcoded weak password

  # Publicly accessible
  publicly_accessible    = true            # database exposed to internet

  # No encryption
  storage_encrypted      = false           # unencrypted storage

  # Automated backups disabled
  backup_retention_period = 0              # backups disabled

  # No deletion protection
  deletion_protection    = false

  # No Multi-AZ
  multi_az               = false

  # Monitoring disabled
  monitoring_interval    = 0

  # SSL not enforced (no parameter group forcing SSL)
  skip_final_snapshot    = true
}

# ── IAM Misconfigurations ─────────────────────────────────────────────────────

# Overly permissive IAM policy - admin access wildcard
resource "aws_iam_policy" "overpermissive" {
  name = "overpermissive-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "*"         # ALL actions allowed - wildcard
        Resource = "*"         # ALL resources - wildcard
      }
    ]
  })
}

# IAM user with console access and no MFA policy
resource "aws_iam_user" "no_mfa_user" {
  name = "no-mfa-admin-user"
  
  # No MFA required
}

# IAM access keys for user (should use roles)
resource "aws_iam_access_key" "static_key" {
  user = aws_iam_user.no_mfa_user.name
  # Long-lived static credentials - security risk
}

resource "aws_iam_user_policy_attachment" "admin_attach" {
  user       = aws_iam_user.no_mfa_user.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"  # full admin
}

# ── KMS Misconfigurations ─────────────────────────────────────────────────────

resource "aws_kms_key" "weak_key" {
  description             = "Weak KMS key config"
  deletion_window_in_days = 7    # too short - should be 30
  enable_key_rotation     = false  # key rotation disabled
  
  # Key policy allows all actions
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "*"    # everyone can use this key
        }
        Action   = "kms:*"
        Resource = "*"
      }
    ]
  })
}

# ── CloudTrail Misconfigurations ──────────────────────────────────────────────

resource "aws_cloudtrail" "insecure_trail" {
  name                          = "insecure-trail"
  s3_bucket_name                = aws_s3_bucket.no_logging.id
  include_global_service_events = false  # global events not captured
  is_multi_region_trail         = false  # not multi-region
  enable_log_file_validation    = false  # log integrity not validated
  enable_logging                = false  # LOGGING DISABLED
}

# ── EKS Misconfigurations ─────────────────────────────────────────────────────

resource "aws_eks_cluster" "insecure_cluster" {
  name     = "insecure-eks-cluster"
  role_arn = aws_iam_role.eks_role.arn

  vpc_config {
    subnet_ids              = ["subnet-12345678"]
    endpoint_private_access = false  # private access disabled
    endpoint_public_access  = true   # public endpoint exposed
    public_access_cidrs     = ["0.0.0.0/0"]  # open to internet
  }

  # Logging not enabled
  # encryption_config not set - secrets not encrypted
}

resource "aws_iam_role" "eks_role" {
  name = "eks-cluster-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
    }]
  })
}

# ── Lambda Misconfigurations ──────────────────────────────────────────────────

resource "aws_lambda_function" "insecure_lambda" {
  filename      = "lambda.zip"
  function_name = "insecure-function"
  role          = aws_iam_role.eks_role.arn
  handler       = "index.handler"
  runtime       = "python3.6"    # EOL runtime

  # Hardcoded env var secrets
  environment {
    variables = {
      DB_PASSWORD     = "hardcoded_password_123"
      API_KEY         = "sk_live_4eC39HqLyjWDarjtT1zdp7dc"
      AWS_SECRET_KEY  = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
    }
  }

  # No reserved concurrency
  # No DLQ
  # No VPC config - cannot access VPC resources securely

  tracing_config {
    mode = "PassThrough"  # X-Ray tracing disabled
  }
}

# ── SNS / SQS Misconfigurations ───────────────────────────────────────────────

resource "aws_sqs_queue" "unencrypted_queue" {
  name = "insecure-queue"
  # No KMS encryption
  # No dead letter queue
}

resource "aws_sns_topic" "unencrypted_topic" {
  name = "insecure-topic"
  # No KMS encryption
}
