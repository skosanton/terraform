# AWS NLB Terraform module



## This module creates NLB in AWS.



### Prerequisites 

You need to configure your AWS providers so it would look like that

```
provider "aws" {
  region                    = "us-west-2"
}

# Terraform Settings Block
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
module "NLB_Puppet_in_Primary_Region" {
  source = "git::https://github.com/skosanton/terraform.git//modules/tfmod_nlb"

  providers = {
    aws                                               = aws
  }

  count                                               = 2 # 0 means "Do not create". 1 will create one NLB, 2 and more will create 2 and more identical NLBs. You probably don't need that

  project_name                                        = "puppet"
  environment                                         = "dev"

  acm_certificate_arn                                 = aws_acm_certificate.puppet_cert.arn # Optional!ARN of certificate for TLS termination if you are using TLS protocol below
  
  list_of_ports_and_targets = { 
    {TCP_UDP = {8081 = { "8081-TCP_UDP" = concat(module.EC2_Puppet_in_Primary_Region[0].ec2-instance-ids,)}}},
    {TCP_UDP = {4433 = { "4433-TCP_UDP" = concat(module.EC2_Puppet_in_Primary_Region[0].ec2-instance-ids,)}}},
    {TCP_UDP = {8170 = { "8170-TCP_UDP" = concat(module.EC2_Puppet_in_Primary_Region[0].ec2-instance-ids,)}}},
    {TCP_UDP = {8140 = { "8140-TCP_UDP" = concat(module.EC2_Puppet_in_Primary_Region[0].ec2-instance-ids,)}}},
    {TCP_UDP = {8142 = { "8142-TCP_UDP" = concat(module.EC2_Puppet_in_Primary_Region[0].ec2-instance-ids,)}}},
    {TCP_UDP = {8143 = { "8143-TCP_UDP" = concat(module.EC2_Puppet_in_Primary_Region[0].ec2-instance-ids,)}}},
    {TCP_UDP = {443 = { "443-TCP_UDP" = concat(module.EC2_Puppet_in_Primary_Region[0].ec2-instance-ids,)}}},
    {TCP_UDP = {80 = { "80-TCP_UDP" = concat(module.EC2_Puppet_in_Primary_Region[0].ec2-instance-ids,)}}},
    {TCP_UDP = {8800 = { "8800-TCP_UDP" = concat(module.EC2_Puppet_cd4pe_in_Primary_Region[0].ec2-instance-ids,)}}},
    {TLS = {9443 = { "80-TCP" = concat(module.EC2_Puppet_cd4pe_in_Primary_Region[0].ec2-instance-ids,)}}},
    {TCP_UDP = {8000 = { "8000-TCP_UDP" = concat(module.EC2_Puppet_cd4pe_in_Primary_Region[0].ec2-instance-ids,)}}},
  }

}
```

### Structure of list_of_ports_and_targets:
     
  {TCP_UDP = {8081 = { "8081-TCP_UDP" = concat(module.EC2_Puppet_in_Primary_Region[0].ec2-instance-ids,)}}},
  
  Where:
  - TCP_UDP or TLS, UDP, TCP_UDP https://docs.aws.amazon.com//elasticloadbalancing/latest/network/load-balancer-listeners.html
  - 8081 (first one) is a Listener port of NLB. So NLB is going to listen this port
  - "8081-TCP_UDP" (second one) is a target port and protocol. ex. your EC2 instance port you want NLB to forward packages.
      P.S. Below you can see TLS listener forwarding to TCP target. That is why we need both parts.
  -  module.EC2_Puppet_in_Primary_Region[0].ec2-instance-ids  is IDs of the EC2 instances. It can be connected to multiple modules separated by commas
      You can also add any address instead of module.EC2_Puppet_in_Primary_Region[0].ec2-instance-ids. Like "concat(["nlb.aws.com"])"