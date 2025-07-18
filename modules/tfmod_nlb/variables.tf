variable "vpc" {
  default     = ""
  type        = string
  description = "Name of VPC"
}

variable "project_name" {
  default     = "test"
  type        = string
  description = "Project_name"
}

variable "environment" {
  default     = "forgot to add variable for environment"
  type        = string
  description = ""
}

variable "list_of_ports_and_targets" {
  default = []
  type    = list(any)
}

variable "acm_certificate_arn" {
  default     = ""
  type        = string
  description = ""
}

variable "target_type" {
  default     = "instance"
  type        = string
  description = ""
}

variable "alpn_policy" {
  default     = "HTTP2Preferred"
  type        = string
  description = ""
}

variable "ssl_policy" {
  default     = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  type        = string
  description = ""
}

variable "subnets" {
  default = []
  type    = list(any)
}

variable "enable_cross_zone_load_balancing" {
  default = true
  type    = bool
}

variable "set_subnets_manually" {
  default = false
  type    = bool
}