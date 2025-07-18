# Terraform module to create EC2 instances with s3 bucket shared between 2 regions

## Description

This module creates EC2 instances in AWS using 2 regions. You can use it for creating of one or multiple EC2 instances in one or second or both regions.

What exactly it creates:
- EC2 instance
- EC2 instance profile
- S3 bucket that is going to be directly available from all EC2 instances within the same project
- SSM access, so you can connect to your instance console securely in SSH way
- Security Group for EC2 instances
- KMS multi region keys, that will be automatically imported to second region
- It will automatically chose 2 Denali Provided Private subnets and is going to rotate them for every EC2 instance. For example, if you have subnet `denali-provided-private-subnet-a-1`, `denali-provided-private-subnet-b-1`, `denali-provided-private-subnet-c-1`, it will work only with two of them. So first EC2 instance will be created in `denali-provided-private-subnet-a-1`, second in `denali-provided-private-subnet-b-1`, third in `denali-provided-private-subnet-a-1`, etc. You can reverse the order by setting up `starting_subnet_index = 1`. default is 0. You could use that in case if you have multiple servers with different roles, so you would create multiple modules for each role and you could separate each server from another by setting different AZ by using that index.


## Prerequisites

Before using this module, you have to add information about 2 regions to Terraform config, like:

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
Here you says that you are going to use us-west-2 as primary and us-east-1 as backup/secondary region.


## Example of usage

At first I would recommend to use local variables, so you could manage your code easier. It is a small config with most important parts that will make the life easier. It has to be a part of Terraform code and each example below is working with that config. Here you setup your environment, project name, how many instances of each modules do you need, if you want to destroy all the instances and if you want to switch to backup config. Switching to backup config means that all the instances in current region will be destroyed and it will create the instances in second region if you configure it. For that to work you would need several modules. It will be in examples below.

```
locals {
  environment                                         = "prod"
  project                                             = "professor"
  switch_to_backup_config                             = false
  destroy_all_instances                               = false
  number_of_puppet_ec2_instances                      = 1
  number_of_compiler_instances                        = 1
  number_of_cd4pe_instances                           = 1
  number_of_job_hardware_instances                    = 1
}
```



### Example 1 - Bare minimum configuration to create only server in one region

```
module "EC2_Puppet_in_Primary_Region" {
  source = "git::https://github.com/skosanton/terraform.git//modules/tfmod_ec2_2region"

  providers = {
    aws                                               = aws
    aws.backup                                        = aws.backup
  }

  count                                               = 1
  additional_roles_with_permissions                   = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root", "arn:aws:iam::${data.aws_caller_identity.current.account_id}:group/admin"] 
  environment                                         = local.environment
  project_name                                        = local.project
  default_security_groups_managed_by                  = "GNS"
  use_previously_created_config                       = false

  server_role_name                                    = "Puppet"
  number_of_ec2_instances                             = local.destroy_all_instances == true ? 0 : local.switch_to_backup_config == true ? 0 : local.number_of_puppet_ec2_instances
  ami_name                                            = "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*" 
  ami_owner                                           = "099720109477"
  ami_virtualization_type                             = "hvm"
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
```

In this example it will create one EC2 instance in us-west-2 region. It will also create all the things I mentioned in the [description](https://github.com/skosanton/terraform/blob/main/README.md#description) at the top of that page. 

About the parameters sent to the module:
- `use_previously_created_config` is probably most important one. It must be `false` to the first module for one `project_name`. So, if you want to use just one module as in the example above, you should keep it `false`. `false` means that you have not created any configuration for that particular project `project_name`, so it will create all those things from the [description](https://github.com/skosanton/terraform/blob/main/README.md#description) at the top of the page. If you set it to `true` then that module is going to assume that you already cretead all those things before and you want to use existing one. You will see how to use it in the example below.
- `project_name`. Short name of the project. Should be short because of the characters limit. I believe it is max 9 characters. `project_name` is important if you want to create multiple modules using this code and you want all of them to be tight together. EC2 instances from different modules, but the same `project_name` will have an access to the same shared s3 bucket.
- `number_of_ec2_instances`. It is examle how many instances of EC2 you want to create.
- `count` should always be 1. It does not mean how many servers it is going to create. It means that you want to use this module and you need all the configuration to be created. It is important for main module never to be 0. By setting it to 1 you are telling to create s3 bucket, policies, KMS keys. 
- `additional_roles_with_permissions`. Here you pass the additional roles you would like to have an access to the shared EC2 s3 bucket
- `default_security_groups_managed_by`. If you have multiple owners of subnets you can create a tag `ManagedBy` and assign the value here, so it will sort and find correct subnets
- `environment`. It is just for tagging resources in AWS.
- `key_pair`. The name of the key pair for EC2 instance to use
- `server_role_name`. It is be in a name of EC2 instance and in the tags
- `ami_name`. Name of the AMI to use. If you want to have latest, use something like "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"
- `ami_owner`. AMI owner. For ex. "099720109477"
- `ami_virtualization_type`. Virtualization type. For ex. "hvm"
- `ec2_instance_type`. [Type](https://aws.amazon.com/ec2/instance-types/) of EC2 instance.
- `ec2_ssd_size`. SSD size in GB
- `ec2_volume_type`. [Type](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ebs-volume-types.html) of volume.
- `userdata_script`. If you want to use some script on first boot (userdata in AWS) you can put a name of the script here like "script.sh". The script itself must be in "userdata" folder of your Terraform code
- `variables_to_pass_to_script`. If you want to pass some variables to the script. In the script itself you should call that variable like `${puppet_master_dnsaltnames}`
- `list_of_ports`. It is a Security Group configuration.   # The structure of list_of_ports is:
  ```
  # 0 = {tcp = {8081 = { 8081 = concat(["0.0.0.0/0"],)}}},
  # Where:
  # 0 is a unique number from 0 and up to any number, but should be unique for each line in map
  # tcp is a protocol. can be any supported in AWS. Usually tcp or udp
  # 8081 (first one) is a starting number from range of ports
  # 8081 (second one) is an ending number from range of ports. If the same as first, it means you open just single port. If bigger, then multiple
  # ["0.0.0.0/0"] is a CIDR, can be multiple CIDRs like ["10.0.0.0/8", "192.168.10.0/24"],[module.somemodule.cidr_from_some_resource] 
  ```

P.S. You can see the name of the shared EC2 s3 bucket if you open EC2 instance Tags. It will be tag named `s3_backup_bucket_name`




### Example 2 - Configuration to create two different servers in one region with shared S3 bucket and shared configs.

```
module "EC2_Puppet_in_Primary_Region" {
  source = "git::https://github.com/skosanton/terraform.git//modules/tfmod_ec2_2region"

  providers = {
    aws                                               = aws
    aws.backup                                        = aws.backup
  }

  count                                               = 1
  starting_subnet_index                               = 1
  additional_roles_with_permissions                   = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root", "arn:aws:iam::${data.aws_caller_identity.current.account_id}:group/admin"] 
  environment                                         = local.environment
  project_name                                        = local.project
  default_security_groups_managed_by                  = "GNS"
  key_pair                                            = "skosanton_mega_key"
  use_previously_created_config                       = false

  server_role_name                                    = "Puppet"
  number_of_ec2_instances                             = local.destroy_all_instances == true ? 0 : local.switch_to_backup_config == true ? 0 : local.number_of_puppet_ec2_instances
  ami_name                                            = "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*" 
  ami_owner                                           = "099720109477"
  ami_virtualization_type                             = "hvm"
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



module "EC2_Puppet_compiler_in_Primary_Region" {
  source = "git::https://github.com/skosanton/terraform.git//modules/tfmod_ec2_2region"

  providers = {
    aws                                               = aws
    aws.backup                                        = aws.backup
  }

  count                                               = 1
  starting_subnet_index                               = 0
  additional_roles_with_permissions                   = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root", "arn:aws:iam::${data.aws_caller_identity.current.account_id}:group/admin"] 
  environment                                         = local.environment
  project_name                                        = local.project 
  default_security_groups_managed_by                  = "GNS"
  key_pair                                            = "skosanton_mega_key"
  use_previously_created_config                       = true

  server_role_name                                    = "Puppet_compiler"
  number_of_ec2_instances                             = local.destroy_all_instances == true ? 0 : local.switch_to_backup_config == true ? 0 : local.number_of_compiler_instances
  ami_name                                            = "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*" 
  ami_owner                                           = "099720109477"
  ami_virtualization_type                             = "hvm"
  ec2_instance_type                                   = "m6i.xlarge"
  ec2_ssd_size                                        = 80
  ec2_volume_type                                     = "gp3"

  userdata_script                                     = "puppet-compiler.sh"
  variables_to_pass_to_script = {       
    dns_name_for_puppet_agents    = local.dns_name_for_puppet_agents
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
```

In this example we added one more server. If first one was main Puppet server, the second one is Puppet Compiler. Another example would be if one is web server and second one is database. With the configuration like that, both of them will have an access to shared s3 bucket. But you need to run Terraform apply twice to make those changes. You can see that we added `backup_bucket_to_use` and `s3_backup_bucket_iam_policy_arn`, so the second second module will know what is the backup folder and how to connect to it. You would need only to change a name of the module there, nothing more. Important part here is that we have to set `use_previously_created_config` to `true` here, so it will use all the resources created by first module. If you set it to `false`, it will creaet another backup folder and config files. If that is what you want, please use another `project_name` to avoid conflicts.




### Example 3 - Configuration to create two different servers in one region with shared S3 bucket and shared configs and config in second region in case of failure of first one.

```
module "EC2_Puppet_in_Primary_Region" {
  source = "git::https://github.com/skosanton/terraform.git//modules/tfmod_ec2_2region"

  providers = {
    aws                                               = aws
    aws.backup                                        = aws.backup
  }

  count                                               = 1
  starting_subnet_index                               = 1
  additional_roles_with_permissions                   = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root", "arn:aws:iam::${data.aws_caller_identity.current.account_id}:group/admin"] 
  environment                                         = local.environment
  project_name                                        = local.project
  default_security_groups_managed_by                  = "GNS"
  key_pair                                            = "skosanton_mega_key"
  use_previously_created_config                       = false

  server_role_name                                    = "Puppet"
  number_of_ec2_instances                             = local.destroy_all_instances == true ? 0 : local.switch_to_backup_config == true ? 0 : local.number_of_puppet_ec2_instances
  ami_name                                            = "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*" 
  ami_owner                                           = "099720109477"
  ami_virtualization_type                             = "hvm"
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



module "EC2_Puppet_compiler_in_Primary_Region" {
  source = "git::https://github.com/skosanton/terraform.git//modules/tfmod_ec2_2region"

  providers = {
    aws                                               = aws
    aws.backup                                        = aws.backup
  }

  count                                               = 1
  starting_subnet_index                               = 0
  additional_roles_with_permissions                   = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root", "arn:aws:iam::${data.aws_caller_identity.current.account_id}:group/admin"] 
  environment                                         = local.environment
  project_name                                        = local.project 
  default_security_groups_managed_by                  = "GNS"
  key_pair                                            = "skosanton_mega_key"
  use_previously_created_config                       = true

  server_role_name                                    = "Puppet_compiler"
  number_of_ec2_instances                             = local.destroy_all_instances == true ? 0 : local.switch_to_backup_config == true ? 0 : local.number_of_compiler_instances
  ami_name                                            = "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*" 
  ami_owner                                           = "099720109477"
  ami_virtualization_type                             = "hvm"  
  ec2_instance_type                                   = "m6i.xlarge"
  ec2_ssd_size                                        = 80
  ec2_volume_type                                     = "gp3"

  userdata_script                                     = "puppet-compiler.sh"
  variables_to_pass_to_script = {       
    dns_name_for_puppet_agents    = local.dns_name_for_puppet_agents
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


module "EC2_Puppet_in_Secondary_Region" {
  source = "git::https://github.com/skosanton/terraform.git//modules/tfmod_ec2_2region"

  providers = {
    aws                                               = aws.backup
    aws.backup                                        = aws
  }

  count                                               = 1
  starting_subnet_index                               = 0
  additional_roles_with_permissions                   = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root", "arn:aws:iam::${data.aws_caller_identity.current.account_id}:group/admin"] 
  environment                                         = local.environment
  project_name                                        = local.project
  default_security_groups_managed_by                  = "GNS"
  key_pair                                            = "skosanton_mega_key"
  use_previously_created_config                       = true

  server_role_name                                    = "Puppet"
  number_of_ec2_instances                             = local.destroy_all_instances == true ? 0 : local.switch_to_backup_config == true ? local.number_of_puppet_ec2_instances : 0
  ami_name                                            = "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*" 
  ami_owner                                           = "099720109477"
  ami_virtualization_type                             = "hvm"
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



module "EC2_Puppet_compiler_in_Secondary_Region" {
  source = "git::https://github.com/skosanton/terraform.git//modules/tfmod_ec2_2region"

  providers = {
    aws                                               = aws.backup
    aws.backup                                        = aws
  }

  count                                               = 1
  starting_subnet_index                               = 0
  additional_roles_with_permissions                   = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root", "arn:aws:iam::${data.aws_caller_identity.current.account_id}:group/admin"] 
  environment                                         = local.environment
  project_name                                        = local.project 
  default_security_groups_managed_by                  = "GNS"
  key_pair                                            = "skosanton_mega_key"
  use_previously_created_config                       = true

  server_role_name                                    = "Puppet_compiler"
  number_of_ec2_instances                             = local.destroy_all_instances == true ? 0 : local.switch_to_backup_config == true ? local.number_of_compiler_instances : 0
  ami_name                                            = "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*" 
  ami_owner                                           = "099720109477"
  ami_virtualization_type                             = "hvm"
  ec2_instance_type                                   = "m6i.xlarge"
  ec2_ssd_size                                        = 80
  ec2_volume_type                                     = "gp3"

  userdata_script                                     = "puppet-compiler.sh"
  variables_to_pass_to_script = {       
    dns_name_for_puppet_agents    = local.dns_name_for_puppet_agents
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
```

You can see that there is almost no difference here. Main part for second region is that you switch the aliases in this part:
```
  providers = {
    aws                                               = aws.backup
    aws.backup                                        = aws
  }
```

Now `aws = aws.backup` while for primary it is `aws = aws`. Also, next block is changed:
```
  number_of_ec2_instances = local.destroy_all_instances == true ? 0 : local.switch_to_backup_config == true ? local.number_of_compiler_instances : 0
```
So, for second region it will create the instances only if `local.switch_to_backup_config` set to `true`. 