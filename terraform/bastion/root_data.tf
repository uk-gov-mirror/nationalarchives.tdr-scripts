data "aws_ssm_parameter" "cost_centre" {
  name = "/mgmt/cost_centre"
}

data "aws_ami" amazon_linux_ami {
  owners      = ["amazon"]
  name_regex  = "^amzn2-ami-hvm-2.0.\\d{8}.0-x86_64-gp2$"
  most_recent = true
}

data "aws_rds_cluster" "consignment_api" {
  cluster_identifier = split(".", data.aws_ssm_parameter.database_url.value)[0]
}

data "aws_ssm_parameter" "database_url" {
  name = "/${local.environment}/${var.service}/database/url"
}

data "aws_ssm_parameter" "database_username" {
  name = "/${local.environment}/${var.service}/database/username"
}

data "aws_ssm_parameter" "database_password" {
  name = "/${local.environment}/${var.service}/database/password"
}

data "aws_ssm_parameter" "mgmt_account_number" {
  name = "/mgmt/management_account"
}

data "aws_security_group" "db_security_group" {
  tags = {
    "Name" = "${var.service}-database-bastion-security-group-${local.environment}"
  }
}

data "aws_subnet" "private_subnet" {
  tags = {
    "Name" = "tdr-private-subnet-0-${local.environment}"
  }
}

data "aws_caller_identity" "current" {}
