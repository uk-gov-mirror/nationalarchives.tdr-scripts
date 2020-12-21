locals {
  environment = var.environment
  aws_region  = "eu-west-2"
  common_tags = map(
    "Environment", var.environment,
    "Owner", "TDR",
    "Terraform", true,
    "CostCentre", data.aws_ssm_parameter.cost_centre.value
  )
}
