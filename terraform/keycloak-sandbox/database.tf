resource "random_password" "password" {
  length  = 16
  special = false
}

resource "random_string" "snapshot_prefix" {
  length  = 4
  upper   = false
  special = false
}

resource "aws_rds_cluster" "keycloak_database" {
  cluster_identifier_prefix       = "keycloak-db-postgres-${var.environment}"
  engine                          = "aurora-postgresql"
  engine_version                  = "11.6"
  availability_zones              = ["eu-west-2a", "eu-west-2b"]
  database_name                   = "keycloak"
  master_username                 = "keycloak_admin"
  final_snapshot_identifier       = "keycloak-db-final-snapshot-${random_string.snapshot_prefix.result}-${var.environment}"
  master_password                 = random_password.password.result
  vpc_security_group_ids          = aws_security_group.database.*.id
  db_subnet_group_name            = aws_db_subnet_group.user_subnet_group.name
  enabled_cloudwatch_logs_exports = ["postgresql"]
  tags = merge(
    local.common_tags,
    map(
      "Name", "keycloak-db-cluster-${var.environment}"
    )
  )

  lifecycle {
    ignore_changes = [
      # Ignore changes to availability zones because AWS automatically adds the
      # extra availability zone "eu-west-2c", which is rejected by the API as
      # unavailable if specified directly.
      availability_zones,
    ]
  }
}

resource "aws_rds_cluster_instance" "user_database_instance" {
  count                = 1
  identifier_prefix    = "keycloak-db-postgres-instance-${var.environment}"
  cluster_identifier   = aws_rds_cluster.keycloak_database.id
  engine               = "aurora-postgresql"
  engine_version       = "11.6"
  instance_class       = "db.t3.medium"
  publicly_accessible  = true
  db_subnet_group_name = aws_db_subnet_group.user_subnet_group.name
}

resource "aws_db_subnet_group" "user_subnet_group" {
  name       = "main-${var.environment}"
  subnet_ids = local.subnet_ids

  tags = merge(
    local.common_tags,
    map(
      "Name", "user-db-subnet-group-${var.environment}"
    )
  )
}

resource "aws_security_group" "database" {
  name        = "keycloak-database-security-group-${var.environment}"
  description = "Allow inbound access from the keycloak load balancer only"
  vpc_id      = local.vpc_id

  ingress {
    protocol        = "tcp"
    from_port       = 5432
    to_port         = 5432
    security_groups = [aws_security_group.ecs_tasks.id]
  }

  egress {
    protocol        = "-1"
    from_port       = 0
    to_port         = 0
    security_groups = [aws_security_group.ecs_tasks.id]
  }

  tags = merge(
    local.common_tags,
    map("Name", "keycloak-database-security-group-${var.environment}")
  )
}
