provider "aws" {
  region = "eu-west-2"

  assume_role {
    role_arn     = local.assume_role
    session_name = "terraform"
    external_id  = module.global_parameters.external_ids.terraform_scripts
  }
}
