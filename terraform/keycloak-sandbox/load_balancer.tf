resource "aws_alb" "keycloak" {
  name            = "keycloak-${var.environment}"
  subnets         = local.subnet_ids
  security_groups = [aws_security_group.load_balancer.id]

  tags = merge(
    local.common_tags,
    map("Name", "keycloak-${var.environment}")
  )
}

resource "aws_alb_target_group" "keycloak" {
  name        = "keycloak-${var.environment}"
  port        = 8080
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = local.vpc_id

  health_check {
    healthy_threshold   = "3"
    interval            = "30"
    protocol            = "HTTP"
    matcher             = "200,303"
    timeout             = "3"
    path                = "/"
    unhealthy_threshold = 2
  }
  tags = merge(
    local.common_tags,
    map("Name", "keycloak-${var.environment}")
  )
  depends_on = [aws_alb.keycloak]
}

resource "aws_security_group" "load_balancer" {
  name        = "keycloak-load-balancer-security-group"
  description = "Controls access to the keycloak load balancer"
  vpc_id      = local.vpc_id

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    local.common_tags,
    map("Name", "keycloak-load-balancer-security-group-${var.environment}")
  )
}

# Use HTTP so we don't have to create a certificate in the Sandbox environment.
# This is not ideal, but this Sandbox ALB will not be used for real data.
resource "aws_alb_listener" "keycloak_http" {
  load_balancer_arn = aws_alb.keycloak.id
  port              = 80

  default_action {
    target_group_arn = aws_alb_target_group.keycloak.id
    type             = "forward"
  }
}
