resource "random_integer" "tag" {
  min = 1000
  max = 9999
}

locals {
  tls = {
    for K, V in var.list_of_ports_and_targets : K => V
    if contains(keys(V), "TLS")
  }

  no_tls = {
    for K, V in var.list_of_ports_and_targets : K => V
    if !contains(keys(V), "TLS")
  }
}

module "nlb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "8.1.0"

  name = "NLB-for-${var.project_name}-${random_integer.tag.result}"

  load_balancer_type               = "network"
  enable_cross_zone_load_balancing = var.enable_cross_zone_load_balancing == true ? true : false
  internal                         = true

  vpc_id  = data.aws_vpc.vpc.id
  subnets = var.set_subnets_manually == false ? [data.aws_subnet.denali_enterprise_0.id, data.aws_subnet.denali_enterprise_1.id] : var.subnets

  target_groups = [
    for Number, ProtocolMap in var.list_of_ports_and_targets :
    [for Protocol, PortFromMap in ProtocolMap :
      [for PortFrom, PortToMap in PortFromMap :
        [for TargetPort, ListofTargets in PortToMap :
          {
            name_prefix      = "${replace(TargetPort, "/-.*/", "")}-"
            backend_protocol = "${replace(TargetPort, "/.*-/", "")}"
            backend_port     = tonumber("${replace(TargetPort, "/-.*/", "")}")
            target_type      = var.target_type

            targets = { for x in range(0, length(ListofTargets)) : "my_target_${x}" => {
              target_id = ListofTargets[x]
              port      = tonumber("${replace(TargetPort, "/-.*/", "")}")
              }
            }
            tags = merge(
              {
                Terraform   = "true"
                Environment = var.environment
              }
            )
  }][0]][0]][0]]


  http_tcp_listeners = [
    for Number, ProtocolMap in local.no_tls :
    [for Protocol, PortFromMap in ProtocolMap :
      [for PortFrom, PortToMap in PortFromMap :
        {
          port               = PortFrom
          protocol           = "${Protocol}"
          target_group_index = Number
  }][0]][0]]


  https_listeners = [
    for Number, ProtocolMap in local.tls :
    [for Protocol, PortFromMap in ProtocolMap :
      [for PortFrom, PortToMap in PortFromMap :
        {
          port               = PortFrom
          protocol           = "${Protocol}"
          certificate_arn    = "${Protocol}" == "TLS" ? var.acm_certificate_arn : null
          target_group_index = Number
          alpn_policy        = var.alpn_policy
          ssl_policy         = var.ssl_policy
  }][0]][0]]


  tags = merge(
    {
      Name        = "NLB-for-${var.project_name}-${random_integer.tag.result}"
      Terraform   = "true"
      Environment = var.environment
    }
  )
}