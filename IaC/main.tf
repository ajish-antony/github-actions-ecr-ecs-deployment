resource "aws_ecr_repository" "project01" {
  name    = "${var.project}-ecr"
  image_scanning_configuration {
    scan_on_push = true
  }
}
resource "aws_ecs_cluster" "project01" {
  name = ""${var.project}-ecs"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}
resource "aws_ecs_task_definition" "project01_task" {
  family                   = "project-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"  
  memory                   = "512" 
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  container_definitions = jsonencode([
    {
      name  = "project-container"
      image = aws_ecr_repository.project01.repository_url
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
        }
      ]
    }
  ])
}
resource "aws_ecs_service" "project01_service" {
  name            = "${var.project}-service"
  cluster         = aws_ecs_cluster.project01.id
  task_definition = aws_ecs_task_definition.project01_task.arn
  launch_type     = "FARGATE"
  desired_count = 2
  deployment_maximum_percent = 200
  network_configuration {
    subnets = [aws_subnet.public1.id,aws_subnet.public2.id]
    security_groups = [aws_security_group.my_security_group.id]
    assign_public_ip = "true"
  }

  depends_on = [aws_ecs_task_definition.project01_task]
}
resource "aws_security_group" "my_security_group" {
  name        = "${var.project}-sg"
  description = "My Security Group Description"
  vpc_id      = aws_vpc.main.id

  // Allow all incoming traffic
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"  # Indicates all protocols
    cidr_blocks = ["0.0.0.0/0"]
  }

  // Allow all outgoing traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"  # Indicates all protocols
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "aws_iam_role" "ecs_execution_role" {
  name = "${var.project}-ecs_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com",
        },
      },
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "events.amazonaws.com",
        },
      },
    ],
  })

  // Attach a policy granting ECR permissions
  inline_policy {
    name = "ecr_permissions"

    policy = jsonencode({
      Version = "2012-10-17",
      Statement = [
        {
          Effect = "Allow",
          Action = [
            "ecr:GetAuthorizationToken",
            "ecr:BatchCheckLayerAvailability",
            "ecr:BatchGetImage",
          ],
          Resource = "*",
        },
      ],
    })
  }
}
resource "aws_iam_role_policy_attachment" "ecs_execution_role_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"  # AmazonECSTaskExecutionRolePolicy grants permissions to pull images from ECR
  role       = aws_iam_role.ecs_execution_role.name
}