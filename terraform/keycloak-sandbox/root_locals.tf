locals {
  environment = var.environment
  tag_prefix  = "test-keycloak"
  aws_region  = "eu-west-2"
  # The default VPC in the Sandbox environment
  vpc_id = "vpc-04f38e6c"
  # Public subnets in the default VPC
  subnet_ids = ["subnet-7706850d", "subnet-a4d706e8"]
  # We don't normally need to connect this Keycloak server to any other
  # services, so it's fine to use a placeholder URL
  frontend_url = "https://example.com"
  common_tags = map(
    "Environment", var.environment,
    "Owner", "TDR",
    "Terraform", true,
    "CostCentre", data.aws_ssm_parameter.cost_centre.value
  )
}
