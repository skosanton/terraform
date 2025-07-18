data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_subnets" "denali_private_0" {
  filter {
    name   = "tag:Name"
    values = ["denali-provided-private-subnet*"]
  }
  filter {
    name   = "availability-zone"
    values = [data.aws_availability_zones.available.names[0]]
  }
}

data "aws_subnets" "denali_private_1" {
  filter {
    name   = "tag:Name"
    values = ["denali-provided-private-subnet*"]
  }
  filter {
    name   = "availability-zone"
    values = [data.aws_availability_zones.available.names[1]]
  }
}

data "aws_subnets" "denali_enterprise_0" {
  filter {
    name   = "tag:Name"
    values = ["denali-provided-enterprise-subnet*"]
  }
  filter {
    name   = "availability-zone"
    values = [data.aws_availability_zones.available.names[0]]
  }
}

data "aws_subnets" "denali_enterprise_1" {
  filter {
    name   = "tag:Name"
    values = ["denali-provided-enterprise-subnet*"]
  }
  filter {
    name   = "availability-zone"
    values = [data.aws_availability_zones.available.names[1]]
  }
}

data "aws_subnet" "denali_private_0" {
  id = data.aws_subnets.denali_private_0.ids[0]
}

data "aws_subnet" "denali_private_1" {
  id = data.aws_subnets.denali_private_1.ids[0]
}

data "aws_subnet" "denali_enterprise_0" {
  id = data.aws_subnets.denali_enterprise_0.ids[0]
}

data "aws_subnet" "denali_enterprise_1" {
  id = data.aws_subnets.denali_enterprise_1.ids[0]
}

data "aws_vpc" "vpc" {

  filter {
    name   = "tag-value"
    values = [var.vpc]
  }
  filter {
    name   = "tag-key"
    values = ["Name"]
  }
}

data "aws_security_group" "sharedservicessecuritygroup" {
  filter {
    name   = "tag:Name"
    values = ["SharedServicesSecurityGroup"]
  }
}

data "aws_security_groups" "proxy_sg" {
  tags = {
    Name      = "ais-provided-vpc-proxy-sg"
    ManagedBy = var.default_security_groups_managed_by
  }
}

data "aws_security_groups" "InsideVPCSecurityGroup" {
  tags = {
    Name      = "InsideVPCSecurityGroup"
    ManagedBy = var.default_security_groups_managed_by
  }
}

data "aws_ssm_parameter" "ais_approved_ssm_ami" {
  name = var.ais_approved_ssm_image
}

data "aws_lambda_function" "s3_vpc_endpoint_updater" {
  function_name = var.lambda_func_arn_vpc_s3_updater
}

data "aws_vpc_endpoint" "s3" {
  vpc_id       = data.aws_vpc.vpc.id
  service_name = "com.amazonaws.${data.aws_region.current.name}.s3"
}