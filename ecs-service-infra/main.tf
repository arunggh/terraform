/*==================================================================================
  1. Create a load balancer that will receive traffic and redirect to application.
==================================================================================*/

resource "aws_alb" "ecsinfra-alb" {
  count = var.create_load_balancer ? 1 : 0
  name           = "${var.app_name}-${var.service_name}-load-balancer"
  subnets        = var.subnets
  security_groups = [var.alb_sg]
  tags           = var.tags
}

# Create target group on which the alb will forward traffic
resource "aws_alb_target_group" "ecsinfra-tg-blue" {
  count = var.create_load_balancer ? 1 : 0
  name        = "${var.app_name}-${var.service_name}-tg-blue"
  port        = var.app_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id
  deregistration_delay = "30"
  tags        = var.tags

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    protocol            = "HTTP"
    matcher             = "200"
    path                = "/"
    interval            = 30
  }
  lifecycle {
    create_before_destroy = true
  }
}

# Create target group on which the alb will forward traffic
resource "aws_alb_target_group" "ecsinfra-tg-green" {
  count = var.create_load_balancer ? 1 : 0
  name        = "${var.app_name}-${var.service_name}-tg-green"
  port        = var.app_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id
  deregistration_delay = "30"
  tags        = var.tags

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    protocol            = "HTTP"
    matcher             = "200"
    path                = "/"
    interval            = 30
  }
  lifecycle {
    create_before_destroy = true
  }
}


#Redirecting all incoming traffic from ALB to the target group
resource "aws_alb_listener" "ecsinfra-listner" {
  count = var.create_load_balancer ? 1 : 0
  load_balancer_arn = "${aws_alb.ecsinfra-alb[0].arn}"
  port              = 80
  protocol          = "HTTP"
  tags              = var.tags
  default_action {
    type = "redirect"


    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_alb_listener_rule" "ecsinfra-listner-rule" {
  count = var.create_load_balancer ? 1 : 0
  listener_arn = "${aws_alb_listener.ecsinfra-listner[0].arn}"
   priority    = var.listner_priority
   tags        = var.tags
   action {
    type       = "forward"
    forward {
    
       target_group {
       arn = "${aws_alb_target_group.ecsinfra-tg-green[0].arn}" 
       weight           = 0
         } 

       target_group {
       arn = "${aws_alb_target_group.ecsinfra-tg-blue[0].arn}" 
       weight           = 100
         } 
   }
   }
  condition {
    path_pattern {
      values = ["/*"]
    }
  }
}

/*==================================================================================
               2. Cloudwatch log group to redirect container logs 
==================================================================================*/

resource "aws_cloudwatch_log_group" "log-group" {
  name = "${var.app_name}-${var.service_name}"
  tags = var.tags
}

/*==================================================================================
                             3. Repository to store images 
==================================================================================*/

# creating repo for services
resource "aws_ecr_repository" "ecr-repo" {
  name = "${var.app_name}-${var.service_name}"
  tags = var.tags
}

/*==================================================================================
              4. Service discovery for services to be discovered
==================================================================================*/

resource "aws_service_discovery_service" "service_discovery" {
  name = "${var.service_name}"
  tags = var.tags
  dns_config {
    namespace_id = var.service_discovery_namespace_id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

/*==================================================================================
           5. ECS Task Definition to provision the application container
==================================================================================*/

resource "aws_ecs_task_definition" "ecs-taskdef" {
  family                   = "${var.app_name}-${var.service_name}"
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.fargate_cpu
  memory                   = var.fargate_memory
  tags                     = var.tags
  container_definitions    = jsonencode(
  [
   {
    name         = "${var.service_name}"
    image        = "${aws_ecr_repository.ecr-repo.repository_url}"
    cpu          = "${var.container_cpu}"
    memory       = "${var.container_memory}"
    environment  = var.task_environment_variables == [] ? null : var.task_environment_variables
    portMappings = var.port_mapping == [] ? null : var.port_mapping
    networkMode  = "awsvpc"
    logConfiguration: {
          logDriver: "awslogs",
          options: {
            awslogs-group: "${aws_cloudwatch_log_group.log-group.name}",
            awslogs-region: "${var.aws_region}",
            awslogs-stream-prefix: "ecs-${var.app_name}"
          }
      }
   }  
      ])
}

/*==================================================================================
                 6. ECS service to launch the container in cluster
==================================================================================*/

resource "aws_ecs_service" "ecsinfra-service" {
  name            = "${var.service_name}"
  cluster         = var.cluster_id
  task_definition = aws_ecs_task_definition.ecs-taskdef.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  tags            = var.tags

  deployment_controller {
    type = "${var.deployment_controller}"
  }

  dynamic "network_configuration" {
    for_each = var.service_type == "backend" ? [1] : []
    content {
    security_groups  = ["${var.ecs_sg}", var.db_security_group ]
    subnets          = var.private_subnet
    assign_public_ip = true
    }
  }

  dynamic "network_configuration" {
    for_each = var.service_type == "frontend" ? [1] : []
    content {
    security_groups  = [var.ecs_sg]
    subnets          = var.private_subnet
    assign_public_ip = true
    }
  }
  dynamic "load_balancer" {
    for_each = var.deployment_controller == "CODE_DEPLOY" ? [1] : []
    content {
      target_group_arn = "${aws_alb_target_group.ecsinfra-tg-blue[0].arn}"
      container_name   = var.service_name
      container_port   = var.container_port
    }
  }

  service_registries {
    registry_arn = aws_service_discovery_service.service_discovery.arn
  } 
}


/*==================================================================================
                       7. CodeBuild for build the image for app
==================================================================================*/

resource "aws_codebuild_project" "codebuild" {
  name          = "${var.app_name}-${var.service_name}"
  description   = "${var.app_name}-${var.service_name}-docker build"
  build_timeout = var.build_timeout
  service_role  = "${var.codebuild_service_arn}"
  tags          = var.tags
  artifacts {
    type = "CODEPIPELINE"
  }
  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/docker:18.09.0"
    type            = "LINUX_CONTAINER"
    privileged_mode = true

    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = var.aws_region
    }
    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = var.account_id
    }
    environment_variable {
      name  = "IMAGE_REPO_NAME"
      value = aws_ecr_repository.ecr-repo.name
    }
    dynamic environment_variable {
      for_each = var.frontend_url == "yes" ? [1] : []
    content {
       name  = "REACT_APP_EXTERNAL_API_URL"
       value = "http://${aws_alb.ecsinfra-alb[0].dns_name}/apiv1"
      }
  }
  }
  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec.yml"
  }
}


/*==================================================================================
                       8. CodeDeploy to deploy the image to ECS
==================================================================================*/

resource "aws_codedeploy_app" "codedeploy" {
  compute_platform = "ECS"
  name             = "${var.app_name}-${var.service_name}"
  tags             = var.tags
}

/*==================================================================================
             9. CodeDeploy deployment group for blue-green deployment
==================================================================================*/

resource "aws_codedeploy_deployment_group" "deploymentgroup" {
  count = var.create_load_balancer ? 1 : 0
  app_name               = "${aws_codedeploy_app.codedeploy.name}"
  deployment_config_name = "CodeDeployDefault.ECSAllAtOnce"
  deployment_group_name  = "${var.app_name}-${var.service_name}"
  service_role_arn       = "${var.codedeploy_service_arn}"
  tags                   = var.tags

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }

  blue_green_deployment_config {
    deployment_ready_option {
      action_on_timeout = "CONTINUE_DEPLOYMENT"
    }

    terminate_blue_instances_on_deployment_success {
      action                           = "TERMINATE"
      termination_wait_time_in_minutes = 5
    }
  }

  deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type   = "BLUE_GREEN"
  }

  ecs_service {
    cluster_name = "${var.cluster_name}"
    service_name = "${aws_ecs_service.ecsinfra-service.name}"
  }
  load_balancer_info {
    target_group_pair_info {
      prod_traffic_route {
        listener_arns = [ "${aws_alb_listener.ecsinfra-listner[0].arn}"]
      }

      target_group {
        name = "${aws_alb_target_group.ecsinfra-tg-blue[0].name}"
      }

      target_group {
        name = "${aws_alb_target_group.ecsinfra-tg-green[0].name}"
      }
    }
  }
}

/*==================================================================================
                     10. CodePipeline for CICD operations
==================================================================================*/

resource "aws_codepipeline" "codepipeline" {
  name     = "${var.app_name}-${var.service_name}"
  role_arn = "${var.codepipeline_arn}"
  tags     = var.tags

  artifact_store {
    location = "${var.bucket_location}"
    type     = "S3"
      encryption_key {
         id   = "${var.kms_alias_arn}"
         type = "KMS"
    }
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "ThirdParty"
      provider         = "GitHub"
      version          = "1"
      output_artifacts = ["${var.app_name}-${var.service_name}-source"]

      configuration = {
        Owner      = var.repo_owner
        Repo       = var.repo_name
        Branch     = var.branch_name
        OAuthToken = var.github_token
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["${var.app_name}-${var.service_name}-source"]
      output_artifacts = ["${var.app_name}-${var.service_name}-build"]
      version          = "1"

      configuration = {
        ProjectName = "${var.app_name}-${var.service_name}"
      }
    }
  }

  dynamic "stage" {
    for_each = var.deployment_controller == "CODE_DEPLOY" ? [1] : []
    content {
    name = "Deploy"
    action {
       name            = "DeployToECS"
       category        = "Deploy"
       owner           = "AWS"
       provider        = "CodeDeployToECS"
       input_artifacts = ["${var.app_name}-${var.service_name}-build"]
       version         = "1"
       configuration   = {
          ApplicationName                = aws_codedeploy_app.codedeploy.name
          DeploymentGroupName            = aws_codedeploy_deployment_group.deploymentgroup[0].deployment_group_name
          TaskDefinitionTemplateArtifact = "${var.app_name}-${var.service_name}-build"
          AppSpecTemplateArtifact        = "${var.app_name}-${var.service_name}-build"   
      }
      }
    }
  }
 dynamic "stage" {
    for_each = var.deployment_controller == "ECS" ? [1] : []
    content {
    name = "Deploy"
    action {
       name            = "DeployToECS"
       category        = "Deploy"
       owner           = "AWS"
       provider        = "ECS"
       input_artifacts = ["${var.app_name}-${var.service_name}-build"]
       version         = "1"


       configuration   = {
          ClusterName = "${var.cluster_name}"
          ServiceName = "${aws_ecs_service.ecsinfra-service.name}"
       }
      }
    }
  } 
}
