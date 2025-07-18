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

module "vpc_in_us_west_2" {
  source = "terraform-aws-modules/vpc/aws"

  providers = {
  aws                                               = aws
}

  name = "vpc_in_us_west_2"
  cidr = "10.0.0.0/20"

  azs             = ["us-west-2c", "us-west-2d"]
  private_subnets = ["10.0.0.0/22", "10.0.4.0/22"]
  public_subnets  = ["10.0.8.0/22", "10.0.12.0/22"]

  enable_nat_gateway = true
  enable_vpn_gateway = true

  tags = {
    Terraform = "true"
    Environment = "dev"
    ManagedBy = "skosanton"
  }
}

module "vpc_in_us_east_1" {
  source = "terraform-aws-modules/vpc/aws"

  providers = {
  aws                                               = aws.backup
}

  name = "vpc_in_us_east_1"
  cidr = "10.0.16.0/20"

  azs             = ["us-east-1e", "us-east-1f"]
  private_subnets = ["10.0.16.0/22", "10.0.20.0/22"]
  public_subnets  = ["10.0.24.0/22", "10.0.28.0/22"]

  enable_nat_gateway = true
  enable_vpn_gateway = true

  tags = {
    Terraform = "true"
    Environment = "dev"
    ManagedBy = "skosanton"
  }
}

variable "public_key" {
  default = ""
  description = "you can generate your with SSH and add it here as a default or just pass it like terraform apply -var=public_key= ......"
}

resource "aws_key_pair" "skosanton_mega_key" {
  key_name   = "skosanton_mega_key"
  public_key = var.public_key
}


module "EC2_Puppet_in_Primary_Region" {
  source = "git::https://github.com/skosanton/terraform.git//modules/tfmod_ec2_2region"

  providers = {
    aws                                               = aws
    aws.backup                                        = aws.backup
  }

  count                                               = 1
  starting_subnet_index                               = 1
  additional_roles_with_permissions                   = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root", "arn:aws:iam::${data.aws_caller_identity.current.account_id}:group/admins"] 
  environment                                         = local.environment
  project_name                                        = local.project
  default_security_groups_managed_by                  = "skosanton"
  key_pair                                            = "skosanton_mega_key"
  use_previously_created_config                       = false

  server_role_name                                    = "Puppet"
  number_of_ec2_instances                             = local.destroy_all_instances == true ? 0 : local.switch_to_backup_config == true ? 0 : local.number_of_puppet_ec2_instances
  ec2_instance_type                                   = "c6i.4xlarge"
  ec2_ssd_size                                        = 200
  ec2_volume_type                                     = "gp3"

  userdata_script                                     = "puppet-Enterprise-primary-install.sh" 
  variables_to_pass_to_script = {       
    puppet_master_dnsaltnames = format("%#v", concat(local.all_dns_names_for_certificates, ["puppet"]))
  }

  list_of_ports = {
    0 = {tcp = {8081 = { 8081 = concat(["0.0.0.0/0"],)}}},
    1 = {tcp = {4433 = { 4433 = concat(["0.0.0.0/0"],)}}},
    2 = {tcp = {8170 = { 8170 = concat(["0.0.0.0/0"],)}}},
    3 = {tcp = {8140 = { 8143 = concat(["0.0.0.0/0"],)}}},
    4 = {tcp = {443 = { 443 = concat(["0.0.0.0/0"],)}}},
    5 = {tcp = {80 = { 80 = concat(["0.0.0.0/0"],)}}},
    6 = {tcp = {8800 = { 8800 = concat(["0.0.0.0/0"],)}}},
    7 = {udp = {80 = { 80 = concat(["0.0.0.0/0"],)}}},
    8 = {udp = {443 = { 443 = concat(["0.0.0.0/0"],)}}},
  }
}

module "EC2_Puppet_in_Secondary_Region" {
  source = "git::https://github.com/skosanton/terraform.git//modules/tfmod_ec2_2region"

  providers = {
    aws                                               = aws.backup
    aws.backup                                        = aws
  }

  count                                               = 1
  starting_subnet_index                               = 0
  additional_roles_with_permissions                   = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root", "arn:aws:iam::${data.aws_caller_identity.current.account_id}:group/admins"] 
  environment                                         = local.environment
  project_name                                        = local.project
  default_security_groups_managed_by                  = "skosanton"
  key_pair                                            = "skosanton_mega_key"
  use_previously_created_config                       = true

  server_role_name                                    = "Puppet"
  number_of_ec2_instances                             = local.destroy_all_instances == true ? 0 : local.switch_to_backup_config == true ? local.number_of_puppet_ec2_instances : 0
  ec2_instance_type                                   = "c6i.4xlarge"
  ec2_ssd_size                                        = 200
  ec2_volume_type                                     = "gp3"

  userdata_script                                     = "puppet-Enterprise-primary-install.sh"
  variables_to_pass_to_script = {       
    puppet_master_dnsaltnames   = format("%#v", concat(local.all_dns_names_for_certificates, ["puppet"]))
  }

  list_of_ports = {
    0 = {tcp = {8081 = { 8081 = concat(["0.0.0.0/0"],)}}},
    1 = {tcp = {4433 = { 4433 = concat(["0.0.0.0/0"],)}}},
    2 = {tcp = {8170 = { 8170 = concat(["0.0.0.0/0"],)}}},
    3 = {tcp = {8140 = { 8143 = concat(["0.0.0.0/0"],)}}},
    4 = {tcp = {443 = { 443 = concat(["0.0.0.0/0"],)}}},
    5 = {tcp = {80 = { 80 = concat(["0.0.0.0/0"],)}}},
    6 = {tcp = {8800 = { 8800 = concat(["0.0.0.0/0"],)}}},
    7 = {udp = {80 = { 80 = concat(["0.0.0.0/0"],)}}},
    8 = {udp = {443 = { 443 = concat(["0.0.0.0/0"],)}}},
  }

  s3_backup_bucket_iam_policy_arn              = module.EC2_Puppet_in_Primary_Region[0].aws_iam_policy_s3_terraform_backup_policy_arn
  backup_bucket_to_use                         = module.EC2_Puppet_in_Primary_Region[0].s3_ec2_backup_bucket_name

  depends_on = [
    module.EC2_Puppet_in_Primary_Region
  ]
}