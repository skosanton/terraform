# AWS S3 State for Terraform



## This module creates S3 bucket with KMS key replica in two regions



### Prerequisites 

You need to configure your AWS providers so it would look like that

```
provider "aws" {
  region                    = "us-west-2"
}

provider "aws" {
  alias                     = "backup"
  region                    = "us-east-1"
}

terraform {
  required_version            = "= 1.5.7"
  required_providers {
    aws = {
      source                  = "hashicorp/aws"
      version                 = ">= 4.31"
     }
  }
}
```


### Example of usage:

```
module "s3_tfstate_bucket_2_regions" {
  source = "git::https://github.com/skosanton/terraform.git//modules/tfmod_s3-tfstate-2region"

  providers = {
    aws                                               = aws
    aws.backup                                        = aws.backup
  }

  count                                               = 1

  s3_tfstate_bucket_name                              = "s3_terraform_state"
  environment                                         = "dev"
  project_name                                        = "alpha"

}
```