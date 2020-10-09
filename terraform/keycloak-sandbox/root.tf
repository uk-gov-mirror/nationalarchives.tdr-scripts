resource "aws_ecs_cluster" "keycloak_ecs" {
  name = "keycloak_${var.environment}"

  tags = merge(
    local.common_tags,
    map("Name", "keycloak_${var.environment}")
  )
}

resource "aws_ecs_task_definition" "keycloak_task" {
  family                   = "keycloak-${var.environment}"
  execution_role_arn       = aws_iam_role.keycloak_ecs_execution.arn
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 1024
  memory                   = 3072
  container_definitions    = data.template_file.app.rendered
  task_role_arn            = aws_iam_role.keycloak_ecs_task.arn

  tags = merge(
    local.common_tags,
    map("Name", "keycloak-task-definition")
  )
}

resource "aws_ecs_service" "keycloak_service" {
  name                              = "keycloak_service_${var.environment}"
  cluster                           = aws_ecs_cluster.keycloak_ecs.id
  task_definition                   = aws_ecs_task_definition.keycloak_task.arn
  desired_count                     = 1
  launch_type                       = "FARGATE"
  health_check_grace_period_seconds = "360"

  network_configuration {
    security_groups  = [aws_security_group.ecs_tasks.id]
    subnets          = local.subnet_ids
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_alb_target_group.keycloak.arn
    container_name   = "keycloak"
    container_port   = 8080
  }

  depends_on = [aws_alb_target_group.keycloak]
}

data "template_file" "app" {
  template = file("templates/keycloak.json.tpl")

  vars = {
    # Deploy the latest integration image
    app_image                         = "nationalarchives/tdr-auth-server:intg"
    app_port                          = 8080
    app_environment                   = var.environment
    aws_region                        = local.aws_region
    url_path                          = aws_ssm_parameter.database_url.name
    username_path                     = aws_ssm_parameter.database_username.name
    password_path                     = aws_ssm_parameter.database_password.name
    admin_user_path                   = aws_ssm_parameter.keycloak_admin_user.name
    admin_password_path               = aws_ssm_parameter.keycloak_admin_password.name
    client_secret_path                = aws_ssm_parameter.keycloak_client_secret.name
    backend_checks_client_secret_path = aws_ssm_parameter.keycloak_backend_checks_client_secret.name
    realm_admin_client_secret_path    = aws_ssm_parameter.keycloak_realm_admin_client_secret.name
    frontend_url                      = local.frontend_url
    configuration_properties_path     = aws_ssm_parameter.keycloak_configuration_properties.name
    user_admin_client_secret_path     = aws_ssm_parameter.keycloak_user_admin_client_secret.name
  }
}

# Traffic to the ECS cluster should only come from the application load balancer
resource "aws_security_group" "ecs_tasks" {
  name        = "keycloak-ecs-tasks-security-group-${var.environment}"
  description = "Allow inbound access from the keycloak load balancer only"
  vpc_id      = local.vpc_id

  ingress {
    protocol        = "tcp"
    from_port       = 8080
    to_port         = 8080
    security_groups = [aws_security_group.load_balancer.id]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    local.common_tags,
    map("Name", "keycloak-ecs-task-security-group-${var.environment}")
  )
}

resource "aws_cloudwatch_log_group" "keycloak_log_group" {
  name              = "/ecs/keycloak-${var.environment}"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_stream" "tdr_application_log_stream" {
  name           = "tdr-keycloak-stream-${var.environment}"
  log_group_name = aws_cloudwatch_log_group.keycloak_log_group.name
}
