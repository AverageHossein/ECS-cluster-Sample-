terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

resource "aws_ecr_repository" "ecr" {
  name = var.app_name
}

resource "aws_cloudwatch_log_group" "task_definition_log_group" {
    name = "${var.app_name}-task-log-group"
}


resource "aws_cloudwatch_log_group" "cluster_log_group" {
  name = "${var.app_name}-cluster-log-group"
}

resource "aws_ecs_cluster" "ecs_cluster" {
  name = "${var.app_name}-cluster"

  configuration {
    execute_command_configuration {
      log_configuration {
        cloud_watch_log_group_name = aws_cloudwatch_log_group.cluster_log_group.name
      }
    }
  }
}


resource "aws_ecs_task_definition" "ecs_task" {
  family = "${var.app_name}-task"

  container_definitions = <<DEFINITION
  [
    {
      "name": "${var.app_name}-container",
      "image": "${aws_ecr_repository.ecr.repository_url}:latest",
      "entryPoint": [],
      "environment": ${data.template_file.env_vars.rendered},
      "essential": true,
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "${aws_cloudwatch_log_group.task_definition_log_group.id}",
          "awslogs-region": "${data.aws_region.current}",
          "awslogs-stream-prefix": "${var.app_name}"
        }
      },
      "portMappings": [
        {
          "containerPort": 8080,
          "hostPort": 8080
        }
      ],
      "cpu": 256,
      "memory": 512,
      "networkMode": "awsvpc"
    }
  ]
  DEFINITION

  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  memory                   = "512"
  cpu                      = "256"
  execution_role_arn       = aws_iam_role.ecsTaskExecutionRole.arn
  task_role_arn            = aws_iam_role.ecsTaskExecutionRole.arn
}



resource "aws_ecs_service" "ecs_service" {
  name                 = "${var.app_name}-ecs-service"
  cluster              = aws_ecs_cluster.ecs_cluster.id
  task_definition      = aws_ecs_task_definition.ecs_task.arn
  launch_type          = "FARGATE"
  scheduling_strategy  = "REPLICA"
  desired_count        = 1
  force_new_deployment = true

  network_configuration {
    subnets          = data.aws_subnets.private.ids
    assign_public_ip = false
    security_groups = [
      aws_security_group.service_security_group.id,
      aws_security_group.load_balancer_security_group.id
    ]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.target_group.arn
    container_name   = "${var.app_name}-container"
    container_port   = 8080
  }

  depends_on = [aws_lb_listener.listener]
}

resource "aws_security_group" "service_security_group" {
  vpc_id = data.aws_vpc.selected.id

  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.load_balancer_security_group.id]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name        = "${var.app_name}-service-sg"
  }
}

resource "aws_alb" "application_load_balancer" {
  name               = "${var.app_name}-alb"
  internal           = false
  load_balancer_type = "application"
  subnets            = data.aws_subnets.public.ids
  security_groups    = [aws_security_group.load_balancer_security_group.id]

  tags = {
    Name        = "${var.app_name}-alb"
  }
}

resource "aws_security_group" "load_balancer_security_group" {
  vpc_id = data.aws_vpc.selected.id

  ingress {
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  tags = {
    Name        = "${var.app_name}-sg"
  }
}

resource "aws_lb_target_group" "target_group" {
  name        = "${var.app_name}-target-group"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = data.aws_vpc.selected.id

  health_check {
    healthy_threshold   = "3"
    interval            = "300"
    protocol            = "HTTP"
    matcher             = "200"
    timeout             = "3"
    path                = "/v1/status"
    unhealthy_threshold = "2"
  }

  tags = {
    Name        = "${var.app_name}-lb-tg"
  }
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_alb.application_load_balancer.id
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_group.id
  }
}
