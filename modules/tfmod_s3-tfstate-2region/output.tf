output "s3_bucket_name" {
  value = module.s3-tfstate.s3_bucket_id
}

output "dynamodb_table_arn" {
  value = module.dynamodb-table.dynamodb_table_arn
}