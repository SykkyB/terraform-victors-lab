############################################################
# ECS CLUSTER
############################################################

resource "aws_ecs_cluster" "exchange_cluster" {
  name = "exchange-rate-cluster"
}

############################################################
# ECS TASK EXECUTION ROLE
############################################################

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "ecs-tasks.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

############################################################
# SECURITY GROUP FOR ECS TASKS
############################################################

resource "aws_security_group" "sg_ecs_updater" {
  name   = "ecs-updater-sg"
  vpc_id = aws_vpc.victors_lab_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

############################################################
# RDS ACCESS FROM ECS
############################################################
resource "aws_security_group_rule" "ecs_allow_rds" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.sg_ecs_updater.id
  security_group_id        = aws_security_group.sg_rds.id
}

############################################################
# ECS TASK DEFINITION
############################################################

resource "aws_ecs_task_definition" "exchange_task" {
  family                   = "exchange-updater"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  depends_on               = [aws_cloudwatch_log_group.exchange_updater]

  container_definitions = jsonencode([
    {
      name      = "exchange-updater"
      image     = var.exchange_updater_container_image
      essential = true

      environment = [
        { name = "DB_HOST", value = aws_db_instance.postgres.address },
        { name = "DB_NAME", value = var.db_name },
        { name = "DB_USER", value = var.db_user },
        { name = "DB_PASS", value = var.db_password }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/exchange-updater"
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

############################################################
# ECS SERVICE (NO LOAD BALANCER, RUN IN SCHEDULED MODE)
############################################################

resource "aws_ecs_service" "exchange_service" {
  name            = "exchange-updater-service"
  cluster         = aws_ecs_cluster.exchange_cluster.id
  task_definition = aws_ecs_task_definition.exchange_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    security_groups  = [aws_security_group.sg_ecs_updater.id]
    subnets          = [aws_subnet.private.id, aws_subnet.private_2.id]
    assign_public_ip = false
  }
}

############################################################
# SCHEDULE TASK TO RUN EVERY 5 MINUTES (REPLACE LAMBDA CRON)
############################################################

resource "aws_cloudwatch_event_rule" "ecs_schedule" {
  name                = "ecs-exchange-updater-5min"
  schedule_expression = "rate(5 minutes)"
}

resource "aws_cloudwatch_event_target" "ecs_schedule_target" {
  rule     = aws_cloudwatch_event_rule.ecs_schedule.name
  arn      = aws_ecs_cluster.exchange_cluster.arn
  role_arn = aws_iam_role.ecs_task_execution_role.arn

  ecs_target {
    task_definition_arn = aws_ecs_task_definition.exchange_task.arn
    launch_type         = "FARGATE"
    task_count          = 1

    network_configuration {
      subnets          = [aws_subnet.private.id, aws_subnet.private_2.id]
      security_groups  = [aws_security_group.sg_ecs_updater.id]
      assign_public_ip = false
    }
  }
}

resource "aws_cloudwatch_log_group" "exchange_updater" {
  name              = "/ecs/exchange-updater"
  retention_in_days = 14
}

