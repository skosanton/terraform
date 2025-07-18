# Create bucket policy that going to be attached to the bucket
data "aws_iam_policy_document" "backup_bucket_policy" {

  count = var.use_previously_created_config == true ? 0 : 1

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
      "arn:aws:s3:::${var.s3_backup_bucket_name}-${var.project_name}-${random_integer.tag.result}",
      "arn:aws:s3:::${var.s3_backup_bucket_name}-${var.project_name}-${random_integer.tag.result}/*",
    ]
  }
}

data "aws_iam_roles" "roles" {

  count = var.use_previously_created_config == true ? 0 : 1

  name_regex = "^${var.project_name}-ec2-"
}

# Create KMS customer managed key that going to be used to encrypt s3 bucket for TF State file
resource "aws_kms_key" "backup_bucket_key" {

  count = var.use_previously_created_config == true ? 0 : 1

  description             = "KMS key to encrypt files in ${var.s3_backup_bucket_name}-${var.project_name}-${random_integer.tag.result}"
  deletion_window_in_days = 7
  multi_region            = true
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "Enable IAM User Permissions",
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : concat(
            var.additional_roles_with_permissions, data.aws_iam_roles.roles[0].arns[*]
          )
        },
        "Action" : "kms:*",
        "Resource" : "*"
      }
    ]
  })
  tags = merge(
    {
      Terraform    = "true"
      Project_name = var.project_name
      Multi-region = "true"
      Replica      = "false"
      Name         = "${var.s3_backup_bucket_name}-${var.project_name}-${random_integer.tag.result} KMS"
      Environment  = "${var.environment}"
    }
  )
}

resource "aws_kms_alias" "backup_bucket_key" {

  count = var.use_previously_created_config == true ? 0 : 1

  name          = "alias/s3_backup_bucket_key-${var.project_name}-${random_integer.tag.result}"
  target_key_id = aws_kms_key.backup_bucket_key[0].key_id
}

resource "aws_kms_replica_key" "backup_bucket_key_replica" {

  count = var.use_previously_created_config == true ? 0 : 1

  provider                = aws.backup
  description             = "Multi-Region replica key for ${var.project_name} backup s3 bucket: ${var.s3_backup_bucket_name}-${var.project_name}-${random_integer.tag.result}"
  deletion_window_in_days = 7
  primary_key_arn         = aws_kms_key.backup_bucket_key[0].arn
  enabled                 = true
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "Enable IAM User Permissions",
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : concat(
            var.additional_roles_with_permissions, data.aws_iam_roles.roles[0].arns[*]
          )
        },
        "Action" : "kms:*",
        "Resource" : "*"
      }
    ]
  })
  tags = merge(
    {
      Terraform    = "true"
      Project_name = var.project_name
      Multi-region = "true"
      Replica      = "true"
      Environment  = "${var.environment}"
    }
  )
}

resource "aws_kms_alias" "backup_bucket_key_replica" {

  count = var.use_previously_created_config == true ? 0 : 1

  provider      = aws.backup
  name          = "alias/s3_backup_bucket_key_replica-${var.project_name}-${random_integer.tag.result}"
  target_key_id = aws_kms_replica_key.backup_bucket_key_replica[0].key_id
}

# Create S3 bucket for TF State file.
module "s3-backup_bucket" {

  count = var.use_previously_created_config == true ? 0 : 1

  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "3.4.0"

  bucket        = "${var.s3_backup_bucket_name}-${var.project_name}-${random_integer.tag.result}"
  force_destroy = true

  # Bucket policies
  attach_policy                         = true
  policy                                = data.aws_iam_policy_document.backup_bucket_policy[0].json
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
        kms_master_key_id = aws_kms_key.backup_bucket_key[0].arn
        sse_algorithm     = "aws:kms"
      }
    }
  }

}


# Create a IAM policy to attach to servers as part of Instance Profile role to have an access to the bucket

resource "aws_iam_policy" "s3-terraform-backup_policy" {

  count = var.use_previously_created_config == true ? 0 : 1

  name        = "s3-terraform-${var.project_name}-${random_integer.tag.result}-backup_policy"
  path        = "/"
  description = "IAM policy to attach to servers as part of Instance Profile role to have an access to the bucket"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : ["s3:ListBucket"],
        "Resource" : [module.s3-backup_bucket[0].s3_bucket_arn]
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "s3:AbortMultipartUpload",
          "s3:ListMultipartUploadParts",
          "kms:Decrypt",
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject"
        ],
        "Resource" : ["${module.s3-backup_bucket[0].s3_bucket_arn}/*",
        aws_kms_key.backup_bucket_key[0].arn]
      }
    ]
  })
}