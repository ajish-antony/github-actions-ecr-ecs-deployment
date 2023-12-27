# AWS CloudWatch Event Rule for ECR Image Push

resource "aws_cloudwatch_event_rule" "ecr_image_push" {
  name        = "${var.project}-ecr-image-push"
  description = "Triggers ECS service update on ECR image push"

  event_pattern = <<PATTERN
{
  "source": [
    "aws.ecr"
  ],
  "detail-type": [
    "ECR Image Action"
  ],
  "detail": {
    "action-type": [
      "PUSH"
    ],
    "repository-name": [
      "${aws_ecr_repository.project01.name}" 
    ]
  }
}
PATTERN
}

# AWS CloudWatch Event Target for ECS Service Update

resource "aws_cloudwatch_event_target" "ecs_service_update" {
  rule      = aws_cloudwatch_event_rule.ecr_image_push.name
  target_id = "ecs-service-update"
  arn       = aws_ecs_cluster.project01.arn
  role_arn = aws_iam_role.ecs_execution_role.arn

  ecs_target {
    task_definition_arn = aws_ecs_task_definition.project01_task.arn
    launch_type         = "FARGATE"
    platform_version    = "LATEST"
    network_configuration {
      subnets         = [aws_subnet.public1.id, aws_subnet.public2.id]
      security_groups = [aws_security_group.my_security_group.id]
      assign_public_ip = "true"
    }
  }
}