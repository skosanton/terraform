variable "s3_tfstate_bucket_name" {
    default = "s3-terraform-state"
    type    = string
    description = "the name of the bucket"
}

variable "environment" {
  default = "add variable for environment"
  type = string
  description = ""  
}

variable "project_name" {
  default     = "test"
  type        = string
  description = "Project_name"
}

variable "additional_roles_with_permissions" {
  default     = []
  type        = list
  description = ""
}