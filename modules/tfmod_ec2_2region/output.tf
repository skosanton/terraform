output "aws_iam_policy_s3_terraform_backup_policy_arn" {
  value = var.use_previously_created_config == true ? "" : aws_iam_policy.s3-terraform-backup_policy[0].arn
}

output "ec2-instance-ids" {
  value = module.ec2-instance[*].id
}

output "s3_ec2_backup_bucket_name" {
  value = var.use_previously_created_config == true ? "" : module.s3-backup_bucket[0].s3_bucket_id
}

output "ec2-instance-private-dns" {
  value = module.ec2-instance[*].private_dns
}

output "ec2-instance-private-ips" {
  value = module.ec2-instance[*].private_ip
}