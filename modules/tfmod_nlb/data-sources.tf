data "aws_caller_identity" "current" {}


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
     name = "tag-value"
     values = [var.vpc]
   }
   filter {
     name = "tag-key"
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
    ManagedBy = "AIS"
  }
}

data "aws_security_groups" "InsideVPCSecurityGroup" {
  tags = {
    Name      = "InsideVPCSecurityGroup"
    ManagedBy = "AIS"
  }
}
