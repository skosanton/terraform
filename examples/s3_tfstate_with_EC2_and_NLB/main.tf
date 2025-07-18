provider "aws" {
  region = "us-west-2"
}

provider "aws" {
  alias  = "backup"
  region = "us-east-1"
}

terraform {
  required_version = "= 1.5.7"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.31"
    }
  }
}


terraform {
  backend "s3" {
    bucket         = "s3-terraform-state-alpha-9001"
    dynamodb_table = "s3-terraform-state-alpha-9001"
    key            = "terraform.state"
    region         = "us-west-2"
  }

}

module "s3_tfstate_bucket_2_regions" {
  source = "git::https://github.com/skosanton/terraform.git//modules/tfmod_s3-tfstate-2region"

  providers = {
    aws        = aws
    aws.backup = aws.backup
  }

  count = 1

  s3_tfstate_bucket_name            = "s3-terraform-state"
  environment                       = "dev"
  project_name                      = "alpha"
  additional_roles_with_permissions = []

}

