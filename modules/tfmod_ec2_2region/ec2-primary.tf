### Settings for Puppet Enterprise. There are some settings in variables.tf also, but most needed is here in locals block ###

### CREATING SECURITY GROUP FOR PUPPET ENTERPRISE ###

resource "random_integer" "tag" {
  min = 1000
  max = 9999
}


resource "aws_security_group" "security_group" {
  name        = "${var.project_name}-ec2-${var.server_role_name}-${random_integer.tag.result}_SG"
  description = "${var.project_name}-ec2-${var.server_role_name}-${random_integer.tag.result}_SG"
  vpc_id      = data.aws_vpc.vpc.id




  dynamic "ingress" {
    for_each = var.list_of_ports
    content {
      from_port   = keys(values(ingress.value)[0])[0]
      to_port     = keys(values(values(ingress.value)[0])[0])[0]
      protocol    = keys(ingress.value)[0]
      cidr_blocks = values(values(values(ingress.value)[0])[0])[0]
    }
  }

  tags = merge(
    {
      Name        = "${var.project_name}-ec2-${var.server_role_name}-${random_integer.tag.result}_SG"
      Terraform   = "true"
      Environment = var.environment
    }
  )

  lifecycle {
    ignore_changes = [vpc_id]
  }
}


module "mtls_certificate_for_ec2" {
  source = "git:https://github.com/skosanton/terraform.git//modules/tfmod_ec2_2region"

  count = var.create_mtls_cert == true ? var.number_of_ec2_instances : 0

  management_group_dsid           = var.mtls_dsid_group
  identity_group_dsid             = var.mtls_dsid_group
  cert_type                 = var.mtls_cert_type
  environment                     = var.environment
  project                         = var.project_name
  dns_alt_names_for_web_gui = concat(var.mtls_certificate_dns_names, ["${var.project_name}-ec2-${var.server_role_name}-${random_integer.tag.result}-${count.index + 1}.${var.domain_name}"])
  create_cert               = true
}

data "template_file" "ec2_userdata_tmplt" {

  count = var.number_of_ec2_instances

  template = file("./userdata/${var.userdata_script}")
  vars = merge({
    s3_backup_bucket_name = var.use_previously_created_config == true ? var.backup_bucket_to_use : "${var.s3_backup_bucket_name}-${var.project_name}-${random_integer.tag.result}"
    },
    var.create_mtls_cert == false ? {} : { ca-chain = module.mtls_certificate_for_ec2[count.index].ca-chain,
      public-cert                                   = module.mtls_certificate_for_ec2[count.index].public-cert,
      cert-key                                      = module.mtls_certificate_for_ec2[count.index].cert-key
  }, var.variables_to_pass_to_script)
}


module "ec2-instance" {
  source = "./ec2-instance"


  count = var.number_of_ec2_instances

  name          = "${var.project_name}-ec2-${var.server_role_name}-${random_integer.tag.result}-${count.index + 1}"
  instance_type = var.ec2_instance_type
  key_name      = var.key_pair
  monitoring    = true
  vpc_security_group_ids = [aws_security_group.security_group.id,
    data.aws_security_group.sharedservicessecuritygroup.id,
    data.aws_security_groups.proxy_sg.ids[0],
  data.aws_security_groups.InsideVPCSecurityGroup.ids[0]]
  subnet_id         = count.index == var.starting_subnet_index || count.index % 2 == var.starting_subnet_index ? data.aws_subnet.denali_private_0.id : data.aws_subnet.denali_private_1.id
  availability_zone = count.index == var.starting_subnet_index || count.index % 2 == var.starting_subnet_index ? data.aws_availability_zones.available.names[0] : data.aws_availability_zones.available.names[1]
  ami               = data.aws_ssm_parameter.ais_approved_ssm_ami.value

  create_iam_instance_profile = true
  iam_role_description        = "IAM role for ${var.project_name}-ec2-${var.server_role_name}-${random_integer.tag.result}-${count.index + 1} instance"
  iam_role_name               = "${var.project_name}-ec2-${var.server_role_name}-${random_integer.tag.result}-${count.index + 1}"
  iam_role_tags = merge(
    { Name      = "${var.project_name}-ec2-${var.server_role_name}-${random_integer.tag.result}-${count.index + 1}"
      Terraform = "true"
  Environment = var.environment })

  iam_role_permissions_boundary = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/ais-permissions-boundaries"

  iam_role_policies = {
    SSM              = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    Logs             = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/AISSystemLogsPolicy"
    s3_backup_bucket = var.use_previously_created_config == false ? aws_iam_policy.s3-terraform-backup_policy[0].arn : var.s3_backup_bucket_iam_policy_arn
  }

  user_data                   = data.template_file.ec2_userdata_tmplt[count.index].rendered
  user_data_replace_on_change = false

  metadata_options = {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 8
    instance_metadata_tags      = var.instance_metadata_tags
  }

  enable_volume_tags = true
  root_block_device = [
    {
      encrypted   = true
      volume_type = var.ec2_volume_type
      volume_size = var.ec2_ssd_size
    },
  ]

  hibernation        = false
  ec2_instance_state = var.ec2_instance_state

  tags = merge(
    {
      Name                  = "${var.project_name}-ec2-${var.server_role_name}-${random_integer.tag.result}-${count.index + 1}"
      Terraform             = "true"
      Environment           = var.environment
      s3_backup_bucket_name = var.use_previously_created_config == true ? var.backup_bucket_to_use : "${var.s3_backup_bucket_name}-${var.project_name}-${random_integer.tag.result}"
    }
  )

  depends_on = [module.mtls_certificate_for_ec2]
}

## push that bucket to use S3 VPC endpoint instead of proxy as described in: 
# resource "aws_cloudformation_stack" "s3_vpc_endpoint_updater" {

#   count = var.use_previously_created_config == true ? 0 : 1

#   name          = "S3VpcEndpointUpdaterStack-${var.project_name}-${random_integer.tag.result}"
#   template_body = <<-TEMPLATE
#     AWSTemplateFormatVersion: "2010-09-09"
#     Description: Test
#     Resources:
#       UpdateS3VPCEndpoint:
#         Type: Custom::VpcEndpointUpdater
#         Properties:
#           ServiceToken: "${data.aws_lambda_function.s3_vpc_endpoint_updater.arn}"
#           VpcEndpointId: "${data.aws_vpc_endpoint.s3.id}"
#           Principal: "*"
#           Action: "s3:*"
#           Effect: "Allow"
#           Resource:
#             - "${module.s3-backup_bucket[0].s3_bucket_arn}"
#             - "${module.s3-backup_bucket[0].s3_bucket_arn}/*"
#   TEMPLATE
# }