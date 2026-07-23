terraform {
  backend "s3" {
    bucket       = "tdr-terraform-state-scripts"
    key          = "terraform.state"
    region       = "eu-west-2"
    encrypt      = true
    use_lockfile = true
  }
}
