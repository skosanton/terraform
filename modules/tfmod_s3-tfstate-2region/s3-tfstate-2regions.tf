resource "random_integer" "tag" {
  min = 1000
  max = 9999

  lifecycle {
    prevent_destroy = true
  }
}

# Create bucket policy that going to be attached to the bucket
data "aws_iam_policy_document" "bucket_policy" {
  statement {

    principals {
      type = "AWS"
      identifiers = concat(["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/admin"],
      var.additional_roles_with_permissions)
    }

    actions = [
      "s3:ListBucket",
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]

    resources = [
      "arn:aws:s3:::${var.s3_tfstate_bucket_name}-${var.project_name}-${random_integer.tag.result}",
      "arn:aws:s3:::${var.s3_tfstate_bucket_name}-${var.project_name}-${random_integer.tag.result}/*",
    ]
  }
}

# Create KMS customer managed key that going to be used to encrypt s3 bucket for TF State file
resource "aws_kms_key" "s3-tfstate" {
  description             = "KMS key to encrypt TF State file in S3"
  deletion_window_in_days = 7
  multi_region            = true
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "Enable IAM User Permissions",
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : concat(["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"], var.additional_roles_with_permissions)
        },
        "Action" : "kms:*",
        "Resource" : "*"
      }
    ]
  })
  tags = merge(
    {
      Terraform    = "true"
      Project_name = "${var.project_name}"
      Multi-region = "true"
      Replica      = "false"
      Name         = "KMS key for tf-state"
      Environment  = var.environment
    }
  )

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_kms_alias" "s3-tfstate-bucket-key" {
  name          = "alias/s3-tfstate-bucket-key-${var.project_name}-${random_integer.tag.result}"
  target_key_id = aws_kms_key.s3-tfstate.key_id
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_kms_replica_key" "s3-tfstate-bucket-key_replica" {
  provider                = aws.backup
  description             = "Multi-Region replica key for tf state: ${var.s3_tfstate_bucket_name}-${var.project_name}-${random_integer.tag.result}"
  deletion_window_in_days = 7
  primary_key_arn         = aws_kms_key.s3-tfstate.arn
  enabled                 = true
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "Enable IAM User Permissions",
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : concat(["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"], var.additional_roles_with_permissions)
        },
        "Action" : "kms:*",
        "Resource" : "*"
      }
    ]
  })
  tags = merge(
    {
      Terraform    = "true"
      Project_name = "${var.project_name}"
      Multi-region = "true"
      Replica      = "true"
      Environment  = var.environment
    }
  )

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_kms_alias" "s3-tfstate-bucket-key_replica" {
  provider      = aws.backup
  name          = "alias/s3-tfstate-bucket-key_replica-${var.project_name}-${random_integer.tag.result}"
  target_key_id = aws_kms_replica_key.s3-tfstate-bucket-key_replica.key_id

  lifecycle {
    prevent_destroy = true
  }
}

# Create S3 bucket for TF State file.
module "s3-tfstate" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "3.4.0"

  bucket        = "${var.s3_tfstate_bucket_name}-${var.project_name}-${random_integer.tag.result}"
  force_destroy = var.force_destroy

  # Bucket policies
  attach_policy                         = true
  policy                                = data.aws_iam_policy_document.bucket_policy.json
  attach_deny_insecure_transport_policy = true
  attach_require_latest_tls_policy      = true

  # S3 bucket-level Public Access Block configuration
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  # S3 Bucket Ownership Controls
  # https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_ownership_controls
  control_object_ownership = true
  object_ownership         = "BucketOwnerPreferred"

  expected_bucket_owner = data.aws_caller_identity.current.account_id

  # Enable versioning of the bucket
  versioning = {
    status     = true
    mfa_delete = false
  }

  # Enable bucket encrtyption
  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        kms_master_key_id = aws_kms_key.s3-tfstate.arn
        sse_algorithm     = "aws:kms"
      }
    }
  }
}


# Create Dynamodb table for TF State lock for multiuser change management
module "dynamodb-table" {
  source  = "terraform-aws-modules/dynamodb-table/aws"
  version = "3.1.1"

  name = "${var.s3_tfstate_bucket_name}-${var.project_name}-${random_integer.tag.result}"

  hash_key = "LockID"

  attributes = [
    {
      name = "LockID"
      type = "S"
    }
  ]
}