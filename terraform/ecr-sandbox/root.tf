resource "aws_ecr_repository" "sandbox_ecr_repository" {
  name = "sandbox_ecr_repository"

  image_scanning_configuration {
    scan_on_push = true
  }
}
