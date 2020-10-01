module "encryption_key" {
  source      = "./tdr-terraform-modules/kms"
  project     = var.project
  function    = "bastion-encryption"
  environment = local.environment
  common_tags = local.common_tags
}

module "bastion_ec2_instance" {
  source              = "./tdr-terraform-modules/ec2"
  common_tags         = local.common_tags
  environment         = local.environment
  name                = "bastion"
  user_data           = "user_data_postgres"
  user_data_variables = { db_host = data.aws_ssm_parameter.database_url.value, db_username = data.aws_ssm_parameter.database_username.value, db_password = data.aws_ssm_parameter.database_password.value }
  ami_id              = data.aws_ami.amazon_linux_ami.id
  security_group_id   = data.aws_security_group.db_security_group.id
  kms_arn             = module.encryption_key.kms_key_arn
  subnet_id           = data.aws_subnet.private_subnet.id
  public_key = var.public_key
}
