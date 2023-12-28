# ECR-ECS Deployment 
## GitHub Actions as CI/CD for the ECR-ECS Deployment via Terraform as IaC

[![Docker Build and Push](https://github.com/ajish-antony/github-actions-ecr-ecs-deployment/actions/workflows/main.yml/badge.svg)](https://github.com/ajish-antony/github-actions-ecr-ecs-deployment/actions/workflows/main.yml)

## Description

This project is initiated with a basic structure that automates the deployment procedures, including ECR,ECS and GitHub Actions as CI/CD. All AWS resources are created via Infrastructure as Code (IaC) using Terraform

The basic overview of the project is as follows: it has a GitHub repository where developers usually make changes and push them via MR. Once the Merge Requests are reviewed and approved, they are merged into the main branch. Upon merging into the main branch, the GitHub Actions pipeline is triggered. It builds && tags the image, and then pushes it to the ECR.

Once the image is received in the Elastic Container Registry,a CloudWatch Event Rule is established to trigger the ECS (Elastic Container Service) service, ensuring seamless deployment of the updated containerized application.  The below-created environment has basic infrastructure and can be used for testing purposes. If planning to use it in production, update it with necessary security practices. 

## Features

- Automated Image Build && Push where images on code changes and push them to the specified ECR repository.
- Dynamically provision AWS resources such as ECR repository, ECS cluster, task definition, service, security group, and IAM role using Terraform.
- Structure Terraform code in a reusable manner for better maintainability and scalability.
- Fargate launch type is used as the launch type for ECS services to abstract infrastructure management and scale applications easily.
- Event-Driven Deployment as the CloudWatch Event Rule is used here to trigger ECS service based on ECR image push events, enabling event-driven deployments.

## Architecture

![35](https://github.com/ajish-antony/github-actions-ecr-ecs-deployment/assets/48723128/6dd31135-8241-4e08-ade1-c78e20b2753b)

## Resources created via Terraform as IaC

- ECR Repository
- ECS Cluster
- ECS Task Definition
- ECS Service
- IAM Roles
- Security Groups
- CloudWatch Event Rules
- VPC with 2 public subnets


## Pre-Requests

- Basic knolwdge in AWS resources and Terrform 
- IAM User with Access Key ID and Secret Access Key with the necessary permissions for creating and managing resources.
> [IAM User Creation Steps](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_users_create.html)
- Secure the Credintilas in the GitHub Actions secrets
> [Creating secrets for a repository](https://docs.github.com/en/actions/security-guides/using-secrets-in-github-actions#creating-secrets-for-a-repository)

## Steps For The Creation & Configuration
### AWS Resources

Initially, created AWS resources, which include the following:
 - Creation of an Amazon Elastic Container Registry (ECR) repository and an Amazon ECS (Elastic Container Service) cluster.
 - Task Definition of an ECS task for running containers within the cluster. This involves specifying container configuration, networking mode, and resource requirements. The task utilizes the container image from the ECR repository.
 - Setup of an ECS service, configuring it to use the Fargate launch type. This includes specifying the task definition and defining the network configuration, including subnets, security groups, and public IP assignment.
 - Establishment of a security group for the ECS service.
 - Creation of an IAM role for ECS tasks and events, equipped with policies allowing ECS task execution and the necessary ECR permissions.
```
# AWS ECR Repository

resource "aws_ecr_repository" "project01" {
  name    = "project01"
  image_scanning_configuration {
    scan_on_push = true
  }
}

# AWS ECS Cluster

resource "aws_ecs_cluster" "project01" {
  name = "project01"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

# AWS ECS Task Definition

resource "aws_ecs_task_definition" "project01_task" {
  family                   = "project-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"  
  memory                   = "512" 
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn

  # ECS Container Definition
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

# AWS ECS Service

resource "aws_ecs_service" "project01_service" {
  name            = "project-service"
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

# AWS Security Group

resource "aws_security_group" "my_security_group" {
  name        = "my-security-group"
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
# AWS IAM Role for ECS Execution
resource "aws_iam_role" "ecs_execution_role" {
  name = "ecs_execution_role"

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

# AWS IAM Role Policy Attachment
resource "aws_iam_role_policy_attachment" "ecs_execution_role_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"  # AmazonECSTaskExecutionRolePolicy grants permissions to pull images from ECR
  role       = aws_iam_role.ecs_execution_role.name
}
```
- Next, creates the CloudWatch Event rules, and this rule is triggered when there is a push action on the specified ECR repository.
- The CloudWatch Event Target is set to update the ECS service with the specified ECS cluster, IAM role, and ECS task definition.

```
# AWS CloudWatch Event Rule for ECR Image Push

resource "aws_cloudwatch_event_rule" "ecr_image_push" {
  name        = "ecr-image-push"
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
```
- A VPC is created with 2 public subnets, and please refer to the file as it contains the basics of VPC, which are easy to understand.

### Github Actions Explanation

-  Github actions automates the process of building and pushing a Docker image to an Amazon Elastic Container Registry (ECR) 
-  The job named ```build-and-push``` which runs on an Ubuntu latest virtual machine.
- Here ```actions/checkout``` action, fetches the contents of the repository.
- In the next step sets up AWS CLI with access key, secret key, and region stored in GitHub Secrets. It then uses the aws ```ecr get-login-password``` command to obtain a Docker login token for the specified ECR registry.
- The workflow is named ```Docker Build and Push``` and it is triggered whenever there is a push event to the main branch. It builds the Docker image using the Dockerfile in the repository and tags it. It then pushes the image to the specified ECR repository with the latest tag.

## Basic WorkFlow

- Once Infrastructure as Code (IAC) code for the AWS resources is applied, it will create the VPC, ECR, IAM roles, CloudWatch event rules, ECS, and task definitions.

> ![7](https://github.com/ajish-antony/github-actions-ecr-ecs-deployment/assets/48723128/fb5412d8-341f-495b-814a-a8b1ed2ba15b)

- Updating the image with new changes and merging with the ```main``` branch triggers the GitHub Actions. Here, a sample Nginx Dockerfile is provided, which will be updated to the Elastic Container Registry (ECR) with the latest tag.

> ![8](https://github.com/ajish-antony/github-actions-ecr-ecs-deployment/assets/48723128/a8a93b49-1e4d-489f-b76a-a6e1641d4d86)

- The image is uploaded into the Elastic Container Registry.

> ![1](https://github.com/ajish-antony/github-actions-ecr-ecs-deployment/assets/48723128/d28091de-64b3-49f9-8f1a-afbd211290f1)

- The update in the ECR triggers the Amazon CloudWatch Event Rule

> ![2](https://github.com/ajish-antony/github-actions-ecr-ecs-deployment/assets/48723128/7229f372-524d-46f4-97d7-1798c9f791e0)
> ![3](https://github.com/ajish-antony/github-actions-ecr-ecs-deployment/assets/48723128/0f5f2067-809e-4965-b2f3-ec2e2a8f79b8)

- As part of the rule, it updates the cluster service with the new image change, which triggers the creation of a new task.

> ![4](https://github.com/ajish-antony/github-actions-ecr-ecs-deployment/assets/48723128/90857a36-8a98-455e-aa6c-7cd64c908e57)
> ![5](https://github.com/ajish-antony/github-actions-ecr-ecs-deployment/assets/48723128/00c03d73-3778-4f53-a3f5-7aade878bc4f)

- Once the task is in the running state, assess it via the provided public IP

> ![6](https://github.com/ajish-antony/github-actions-ecr-ecs-deployment/assets/48723128/783f7576-4302-4587-ac40-f170e39d7659)

## Reference
- [Terraform Documents](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

## Conlusion
Here, I have created a sample CI/CD deployment to ECS via ECR using GitHub Actions as the CI/CD. This can be used for testing environments or by those who wish to learn these deployment procedures. 

### ⚙️ Connect with Me

<p align="center">
<a href="mailto:ajishantony95@gmail.com"><img src="https://img.shields.io/badge/Gmail-D14836?style=for-the-badge&logo=gmail&logoColor=white"/></a>
<a href="https://www.linkedin.com/in/ajish-antony/"><img src="https://img.shields.io/badge/LinkedIn-0077B5?style=for-the-badge&logo=linkedin&logoColor=white"/></a>
