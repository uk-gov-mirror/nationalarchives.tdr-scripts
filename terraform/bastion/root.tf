module "encryption_key" {
  source      = "./tdr-terraform-modules/kms"
  project     = var.project
  function    = "bastion-encryption"
  environment = local.environment
  common_tags = local.common_tags
}

resource "aws_iam_role" "bastion_db_connect_role" {
  name = "TDRBastionAccessDbRole${title(local.environment)}"
  assume_role_policy = templatefile("${path.module}/templates/bastion_access_db_assume_role.json.tpl", {account_id = data.aws_caller_identity.current.account_id, environment = title(local.environment)})
}

resource "aws_iam_policy" "bastion_db_connect_policy" {
  name = "TDRBastionAccessDbPolicy${title(local.environment)}"
  policy = templatefile("${path.module}/templates/bastion_access_db_policy.json.tpl", {account_id = data.aws_caller_identity.current.account_id, cluster_id = data.aws_rds_cluster.consignment_api.cluster_resource_id})
}

resource "aws_iam_role_policy_attachment" "db_connect_policy_attach" {
  policy_arn = aws_iam_policy.bastion_db_connect_policy.arn
  role = aws_iam_role.bastion_db_connect_role.id
}

resource "aws_iam_policy" "bastion_assume_role_policy" {
  name = "TDRBastionAssumeDbRolePolicy${title(local.environment)}"
  policy = templatefile("${path.module}/templates/bastion_assume_role.json.tpl", { role_arn = aws_iam_role.bastion_db_connect_role.arn})
}

data "aws_db_instance" "instance" {
  db_instance_identifier = tolist(data.aws_rds_cluster.consignment_api.cluster_members)[0]
}

resource "aws_iam_role_policy_attachment" "bastion_assumne_db_role_attach" {
  policy_arn = aws_iam_policy.bastion_assume_role_policy.arn
  role = module.bastion_ec2_instance.role_id
}

module "bastion_ec2_instance" {
  source              = "./tdr-terraform-modules/ec2"
  common_tags         = local.common_tags
  environment         = local.environment
  name                = "bastion"
  user_data           = "user_data_postgres"
  user_data_variables = { db_host = split(":", data.aws_db_instance.instance.endpoint)[0], db_username = data.aws_ssm_parameter.database_username.value, db_password = data.aws_ssm_parameter.database_password.value, account_number = data.aws_caller_identity.current.account_id, environment = title(local.environment) }
  ami_id              = data.aws_ami.amazon_linux_ami.id
  security_group_id   = data.aws_security_group.db_security_group.id
  kms_arn             = module.encryption_key.kms_key_arn
  subnet_id           = data.aws_subnet.private_subnet.id
  public_key          = var.public_key
}

module "bastion_delete_user_document" {
  source              = "./tdr-terraform-modules/ssm_document"
  content_template    = "bastion_delete_user"
  document_name       = "deleteuser"
  template_parameters = { db_host = data.aws_ssm_parameter.database_url.value, db_username = data.aws_ssm_parameter.database_username.value, db_password = data.aws_ssm_parameter.database_password.value }
}
