resource "aws_ecr_repository" "ecr_repository" {
  name = "keycloak_sandbox"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = local.common_tags
}

resource "aws_ecr_repository_policy" "ecr" {
  policy = templatefile(
    "./templates/ecr_policy.json.tpl",
    { ecs_execution_role = aws_iam_role.keycloak_ecs_execution.arn }
  )
  repository = aws_ecr_repository.ecr_repository.name
}
