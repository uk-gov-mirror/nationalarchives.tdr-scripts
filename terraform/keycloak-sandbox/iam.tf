resource "aws_iam_role" "keycloak_ecs_execution" {
  name               = "keycloak_ecs_execution_role_${var.environment}"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role.json

  tags = merge(
    local.common_tags,
    map(
      "Name", "api-ecs-execution-iam-role-${var.environment}",
    )
  )
}

resource "aws_iam_role" "keycloak_ecs_task" {
  name               = "keycloak_ecs_task_role_${var.environment}"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role.json

  tags = merge(
    local.common_tags,
    map(
      "Name", "api-ecs-task-iam-role-${var.environment}",
    )
  )
}

data "aws_iam_policy_document" "ecs_assume_role" {
  version = "2012-10-17"

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "keycloak_ecs_execution_ssm" {
  role       = aws_iam_role.keycloak_ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMReadOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "keycloak_ecs_execution" {
  role       = aws_iam_role.keycloak_ecs_execution.name
  policy_arn = aws_iam_policy.keycloak_ecs_execution.arn
}

resource "aws_iam_policy" "keycloak_ecs_execution" {
  name   = "keycloak_ecs_execution_policy_${var.environment}"
  path   = "/"
  policy = data.aws_iam_policy_document.keycloak_ecs_execution.json
}

data "aws_iam_policy_document" "keycloak_ecs_execution" {
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["arn:aws:logs:*"]
  }
  statement {
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }
}
