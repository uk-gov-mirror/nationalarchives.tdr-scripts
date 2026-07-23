variable "tdr_account_number" {
  description = "The AWS account number where the TDR environment is hosted"
  type        = string
}

variable "project" {
  default = "tdr"
}

variable "default_aws_region" {
  default = "eu-west-2"
}

variable "public_key" {
  default = ""
}

variable "service" {
  default = "consignmentapi"
}

variable "connect_to_database" {
  default = false
}

variable "connect_to_export_efs" {
  default = false
}
