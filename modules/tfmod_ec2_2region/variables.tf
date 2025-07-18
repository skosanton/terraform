variable "vpc" {
  default     = ""
  type        = string
  description = "Name of AIS provided VPC"
}

variable "project_name" {
  default     = "test"
  type        = string
  description = "Project_name"
}

variable "ec2_instance_type" {
  default     = "c5.4xlarge"
  type        = string
  description = "Instance type to launch"
}

variable "ec2_ssd_size" {
  default     = 200
  type        = number
  description = "the size of the volume"
}

variable "ec2_volume_type" {
  default     = "gp3"
  type        = string
  description = "the type of the volume"
}


variable "ais_approved_ssm_image" {
  default     = "/AIS/AMI/AmazonLinux2/Id"
  type        = string
  description = "AMI to launch"
}

variable "key_pair" {
  default     = "ais-breakglass"
  type        = string
  description = "key pair for EC2 SSH"
}

variable "s3_backup_bucket_iam_policy_arn" {
  default     = ""
  type        = string
  description = "s3_backup_bucket_iam_policy_arn"
}

variable "s3_backup_bucket_name" {
  default     = "s3-terraform-backup"
  type        = string
  description = "s3 backup bucket name"
}

variable "number_of_ec2_instances" {
  default     = 0
  type        = number
  description = ""
}

variable "userdata_script" {
  default     = "proxy.sh"
  type        = string
  description = "Script from userdata folder in a root directory of TF"
}

variable "environment" {
  default     = "forgot to add variable for environment"
  type        = string
  description = ""
}

variable "use_previously_created_config" {
  default     = false
  type        = bool
  description = ""
}

variable "list_of_ports" {
  default     = {}
  type        = map(any)
  description = "list of ports for SG and NLB"
}

variable "additional_roles_with_permissions" {
  default     = []
  type        = list(any)
  description = ""
}

variable "variables_to_pass_to_script" {
  default     = {}
  type        = map(any)
  description = ""
}

variable "backup_bucket_to_use" {
  default     = ""
  type        = string
  description = ""
}

variable "server_role_name" {
  type        = string
  description = ""
  default     = ""
}

variable "default_security_groups_managed_by" {
  type        = string
  description = ""
  default     = "AIS"
}

variable "starting_subnet_index" {
  type        = number
  description = ""
  default     = 0
}

variable "instance_metadata_tags" {
  type        = string
  description = ""
  default     = "disabled"
}

variable "ec2_instance_state" {
  default     = "running"
  type        = string
  description = "to set ec2 instance state. Available options are: stopped or running"
}

variable "create_mtls_cert" {
  default     = false
  type        = bool
  description = ""
}

variable "mtls_certificate_dns_names" {
  default     = []
  type        = list(any)
  description = ""
}

variable "mtls_dsid_group" {
  default     = null
  description = ""
}

variable "mtls_cert_type" {
  default     = "tls_client_internal_2"
  type        = string
  description = ""
}

variable "lambda_func_arn_vpc_s3_updater" {
  type    = string
  default = "VPC-Endpoint-Policy-Updater-vpc-endpoint-policy-updater"
}

variable "domain_name" {
  type = string
  default = "yourdomain.com"
}