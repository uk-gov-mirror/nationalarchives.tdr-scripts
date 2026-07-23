module "global_parameters" {
  source = "./tdr-configurations/terraform"
}

module "encryption_key" {
  source      = "./tdr-terraform-modules/kms"
  project     = var.project
  function    = "bastion-encryption"
  environment = local.environment
  common_tags = local.common_tags
}

resource "aws_iam_role" "bastion_db_connect_role" {
  name               = "TDRBastionAccessDbRole${title(local.environment)}"
  assume_role_policy = templatefile("${path.module}/templates/bastion_access_db_assume_role.json.tpl", { account_id = data.aws_caller_identity.current.account_id, environment = title(local.environment) })
}

resource "aws_iam_role_policy_attachment" "org_session_manager_logs_policy_attach" {
  policy_arn = data.aws_iam_policy.org-session-manager-logs.arn
  role       = data.aws_iam_role.bastion_role.name
}

resource "aws_iam_policy" "bastion_db_connect_policy" {
  name   = "TDRBastionAccessDbPolicy${title(local.environment)}"
  policy = templatefile("${path.module}/templates/bastion_access_db_policy.json.tpl", { account_id = data.aws_caller_identity.current.account_id, instance_id = data.aws_db_instance.consignment_api.resource_id })
}

resource "aws_iam_role_policy_attachment" "db_connect_policy_attach" {
  policy_arn = aws_iam_policy.bastion_db_connect_policy.arn
  role       = aws_iam_role.bastion_db_connect_role.id
}

resource "aws_iam_policy" "bastion_assume_role_policy" {
  count  = local.database_count
  name   = "TDRBastionAssumeDbRolePolicy${title(local.environment)}"
  policy = templatefile("${path.module}/templates/bastion_assume_role.json.tpl", { role_arn = aws_iam_role.bastion_db_connect_role.arn })
}

resource "aws_iam_policy" "bastion_connect_to_export_efs_policy" {
  count  = local.export_efs_count
  name   = "TDRBastionExportEFSConnectPolicy${title(local.environment)}"
  policy = templatefile("${path.module}/templates/bastion_connect_to_efs.json.tpl", { file_system_arn = data.aws_efs_file_system.export_file_system.arn })
}

resource "aws_iam_role_policy_attachment" "bastion_assume_db_role_attach" {
  count      = local.database_count
  policy_arn = aws_iam_policy.bastion_assume_role_policy[count.index].arn
  role       = data.aws_iam_role.bastion_role.name
}

resource "aws_iam_role_policy_attachment" "bastion_access_export_efs_attach" {
  count      = local.export_efs_count
  policy_arn = aws_iam_policy.bastion_connect_to_export_efs_policy[count.index].arn
  role       = data.aws_iam_role.bastion_role.name
}

module "bastion_ami" {
  source      = "./tdr-terraform-modules/ami"
  project     = var.project
  function    = "bastion-ec2"
  environment = local.environment
  common_tags = local.common_tags
  region      = var.default_aws_region
  kms_key_id  = module.encryption_key.kms_key_arn
  source_ami  = data.aws_ami.amazon_linux_ami.id
}

module "bastion_ec2_instance" {
  source      = "./tdr-terraform-modules/ec2"
  common_tags = local.common_tags
  environment = local.environment
  name        = "bastion"
  user_data = templatefile("./templates/user_data_bastion.sh.tpl", {
    db_host               = split(":", data.aws_db_instance.consignment_api.endpoint)[0],
    account_number        = data.aws_caller_identity.current.account_id,
    environment           = title(local.environment),
    export_file_system_id = data.aws_efs_file_system.export_file_system.id,
    connect_to_export_efs = var.connect_to_export_efs,
    connect_to_database   = var.connect_to_database
  })
  ami_id            = module.bastion_ami.encrypted_ami_id
  security_group_id = module.bastion_ec2_security_group.security_group_id
  subnet_id         = data.aws_subnet.private_subnet.id
  public_key        = var.public_key
  role_name         = data.aws_iam_role.bastion_role.name
}

module "bastion_ec2_security_group" {
  source            = "./tdr-terraform-modules/security_group"
  description       = "Security group which will be used by the bastion EC2 instance"
  name              = "tdr-database-bastion-security-group-${local.environment}"
  vpc_id            = data.aws_vpc.vpc.id
  common_tags       = local.common_tags
  egress_cidr_rules = [{ port = 0, cidr_blocks = ["0.0.0.0/0"], description = "Allow outbound access on all ports", protocol = "-1" }]
}

resource "aws_security_group_rule" "allow_access_to_database" {
  count                    = local.database_count
  from_port                = 5432
  protocol                 = "tcp"
  security_group_id        = data.aws_security_group.db_security_group.id
  source_security_group_id = module.bastion_ec2_security_group.security_group_id
  to_port                  = 5432
  type                     = "ingress"
}

resource "aws_security_group_rule" "allow_access_to_export_efs" {
  count                    = local.export_efs_count
  from_port                = 2049
  protocol                 = "tcp"
  security_group_id        = data.aws_security_group.efs_export_security_group.id
  source_security_group_id = module.bastion_ec2_security_group.security_group_id
  to_port                  = 2049
  type                     = "ingress"
}
