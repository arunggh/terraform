terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.15.0"
    }
    github = {
      source  = "integrations/github"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region     = var.aws_region
  access_key = ""
  secret_key = ""
}

provider "github" {
  token = var.github_token
}

module "database_infra" {
  count                      = var.dbmodule_active ? 1 : 0
  source                     = "./ecs-db-infra"
  app_name                   = var.app_name
  db_engine                  = "postgres"
  db_version                 = "13.7"
  storage_type               = "gp2"
  storage_allocated_size     = "5"
  storage_max_allocated_size = "50"
  instance_class             = "db.t3.medium"
  db_name                    = "${var.app_name}db"
  db_user                    = "${var.app_name}admin"
  db_password                = "NieXoo4Ae*ke"
}

module "base_infra" {
  source          = "./ecs-base-infra"
  dbmodule_active = var.dbmodule_active
  db_vpc_id       = var.dbmodule_active ? module.database_infra[0].db_vpc_id : null
  db-sg-id        = var.dbmodule_active ? module.database_infra[0].db-sg-id : null
  aws_region      = var.aws_region
  app_name        = var.app_name
  app_port        = var.app_port
}

module "service_backend" {
  source                         = "./ecs-service-infra"
  service_name                   = "backend"
  service_type                   = "backend"
  aws_region                     = var.aws_region
  app_name                       = var.app_name
  app_port                       = 3000
  subnets                        = var.dbmodule_active ? module.database_infra[0].public_subnet_id : module.base_infra.public_subnet_id
  alb_sg                         = module.base_infra.alb_sg_id
  vpc_id                         = var.dbmodule_active ? module.database_infra[0].db_vpc_id : module.base_infra.vpc_id
  tags                           = local.tags
  create_load_balancer           = false
  service_discovery_namespace_id = module.base_infra.service_discovery_namespace_id
  fargate_cpu                    = var.fargate_cpu
  fargate_memory                 = var.fargate_memory
  execution_role_arn             = module.base_infra.execution_role_arn
  task_role_arn                  = module.base_infra.task_role_arn
  container_cpu                  = var.container_cpu
  container_memory               = var.container_memory
  container_port                 = 3000
  cluster_id                     = module.base_infra.cluster_id
  deployment_controller          = "ECS"
  ecs_sg                         = module.base_infra.ecs_sg_id
  private_subnet                 = var.dbmodule_active ? module.database_infra[0].private_subnet_id : module.base_infra.private_subnet_id
  db_security_group              = var.dbmodule_active ? module.database_infra[0].db-sg-id : var.db_security_group
  build_timeout                  = 60
  listner_priority               = 101
  codebuild_service_arn          = module.base_infra.codebuild_arn
  account_id                     = module.base_infra.account_id
  codedeploy_service_arn         = module.base_infra.codedeploy_arn
  cluster_name                   = module.base_infra.cluster_name
  codepipeline_arn               = module.base_infra.codepipeline_arn
  bucket_location                = module.base_infra.bucket_location
  kms_alias_arn                  = module.base_infra.kms_alias_arn
  repo_owner                     = "arunggh"
  repo_name                      = "back-end-express-bookshelf-realworld"
  branch_name                    = "main"
  github_token                   = var.Git_Token
  task_environment_variables = [
    {
      "name" : "DATABASE_URL",
      "value" : "postgresql://${module.database_infra[0].db_user}:${module.database_infra[0].db_password}@${module.database_infra[0].db_address}:5432/${module.database_infra[0].db_name}?schema=public"
    },
    {
      "name" : "DB_HOST",
      "value" : "${module.database_infra[0].db_address}"

    },
    {
      "name" : "DB_PASSWORD",
      "value" : "${module.database_infra[0].db_password}"

    },
    {
      "name" : "DB_USER",
      "value" : "${module.database_infra[0].db_user}"

    },

    {
      "name" : "SECRET",
      "value" : "thisissecarte"
    },
    {
      "name" : "DB_NAME",
      "value" : "${var.app_name}db"
    }


  ]
  port_mapping = [
    {
      "containerPort" : 3000,
      "hostPort" : 3000
    }
  ]
}


module "service_frontend" {
  source                         = "./ecs-service-infra"
  service_name                   = "frontend"
  service_type                   = "frontend"
  aws_region                     = var.aws_region
  app_name                       = var.app_name
  app_port                       = var.app_port
  subnets                        = var.dbmodule_active ? module.database_infra[0].public_subnet_id : module.base_infra.public_subnet_id
  alb_sg                         = module.base_infra.alb_sg_id
  vpc_id                         = var.dbmodule_active ? module.database_infra[0].db_vpc_id : module.base_infra.vpc_id
  tags                           = local.tags
  create_load_balancer           = true
  service_discovery_namespace_id = module.base_infra.service_discovery_namespace_id
  fargate_cpu                    = var.fargate_cpu
  fargate_memory                 = var.fargate_memory
  execution_role_arn             = module.base_infra.execution_role_arn
  task_role_arn                  = module.base_infra.task_role_arn
  container_cpu                  = var.container_cpu
  container_memory               = var.container_memory
  container_port                 = var.container_port
  cluster_id                     = module.base_infra.cluster_id
  deployment_controller          = "CODE_DEPLOY"
  ecs_sg                         = module.base_infra.ecs_sg_id
  private_subnet                 = var.dbmodule_active ? module.database_infra[0].private_subnet_id : module.base_infra.private_subnet_id
  db_security_group              = var.dbmodule_active ? module.database_infra[0].db-sg-id : var.db_security_group
  listner_priority               = 101
  build_timeout                  = 60
  codebuild_service_arn          = module.base_infra.codebuild_arn
  frontend_url                   = "yes"
  account_id                     = module.base_infra.account_id
  codedeploy_service_arn         = module.base_infra.codedeploy_arn
  cluster_name                   = module.base_infra.cluster_name
  codepipeline_arn               = module.base_infra.codepipeline_arn
  bucket_location                = module.base_infra.bucket_location
  kms_alias_arn                  = module.base_infra.kms_alias_arn
  repo_owner                     = "arunggh"
  repo_name                      = "front-end-angular-realworld"
  branch_name                    = "main"
  github_token                   = var.Git_Token
  task_environment_variables = [
    {
      "name" : "backend",
      "value" : "${module.service_backend.service_discovery_name}.${module.base_infra.service_discovery_namespace_name}"
    }
  ]
  port_mapping = [
    {
      "containerPort" : 80,
      "hostPort" : 80
    }
  ]
}
