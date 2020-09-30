data "aws_ssm_parameter" "cost_centre" {
  name = "/mgmt/cost_centre"
}

data "aws_ami" amazon_linux_ami {
  owners      = ["amazon"]
  name_regex  = "^amzn2-ami-hvm-2.0.\\d{8}.0-x86_64-gp2$"
  most_recent = true
}

data "aws_ssm_parameter" "database_url" {
  name = "/${local.environment}/consignmentapi/database/url"
}

data "aws_ssm_parameter" "database_username" {
  name = "/${local.environment}/consignmentapi/database/username"
}

data "aws_ssm_parameter" "database_password" {
  name = "/${local.environment}/consignmentapi/database/password"
}

data "aws_security_group" "db_security_group" {
  tags = {
    "Name" = "consignmentapi-database-bastion-security-group-${local.environment}"
  }
}