locals {
  target_groups = [
    "blue",
    "green",
  ]
} 

variable "tags" {
  type = map(any)
  default = {
    Department = "Engineering"
  }
  description = "Common tags for identify the resource easily"
}

variable "app_name" {
  type = string
  default = "app"
  description = "Application name for which you want to setup the infra"
}

variable "subnets" {
  type = list(string)
  description = "Public subnet where alb will spin up"
}

variable "alb_sg" {
  type = string
  default = "alb security group"
  description = "Security group for load balancer"
}

variable "vpc_id" {
  type = string
  default = "VPC ID"
  description = "VPC ID where the security group will be created"
}

variable "app_port" {
  type = string  
  default     = "80"
  description = "port exposed on the docker image"
}

variable "create_load_balancer" {
  type = bool
  default = true
  description = "whether or not create load balancer"
}

variable "service_name" {
  type = string
  default = "service"
  description = "name of the service to spin up"
}

variable "aws_region" {
  type = string
  default = "us-west-2"
  description = "Region where infrastructure to deploy"
}

variable "service_discovery_namespace_id" {
  type = string
  default = "service discovery private namespace id"
}

variable "task_environment_variables" {
  type = list(map(string))
  default = []
}

variable "port_mapping" {
  type = list(object({
    containerPort = number
    hostPort      = number
  }))
  description = "The port mappings to configure for the container. This is a list of maps. Each map should contain \"containerPort\", \"hostPort\", and \"protocol\", where \"protocol\" is one of \"tcp\" or \"udp\". If using containers in a task with the awsvpc or host network mode, the hostPort can either be left blank or set to the same value as the containerPort"
  default = []
}

variable "execution_role_arn" {
  type = string
  default = "execution role arn"
  description = "task execution role"
}

variable "task_role_arn" {
  type = string
  default = "task role arn"
  description = "task role"
}

variable "fargate_cpu" {
  type = string   
  default     = "1024"
  description = "fargate instance CPU units to provision"
}

variable "fargate_memory" {
  type = string   
  default     = "2048"
  description = "fargate instance memory units to provision"
}

variable "ecr_repository_url" {
  type = string   
  default     = "repository url"
  description = "repository url to pull the image from"
}

variable "container_cpu" {
  type = number   
  default     = 1024
  description = "container CPU units to provision"
}

variable "container_memory" {
  type = number   
  default     = 2048
  description = "container memory units to provision"
}

variable "container_port" {
  type = number   
  default = 80
  description = "port exposed to load balancer"
}

variable "cluster_id" {
  type = string
  default = "cluster id"
  description = "cluster id of the ecs"
}

variable "deploy_controller" {
  type = string
  default = "deployment controller"
  description = "Deployment controller type for the service"
}

variable "ecs_sg" {
  type = string
  default = "security group"
  description = "ECS security group id to associate with"
}

variable "private_subnet" {
  type = list(string)
  description = "Private subnet where alb will spin up"
}

variable "service_registry_arn" {
  type = string
  default = "service registry arn"
  description = "service registry arn bound to the service"
}

variable "build_timeout" {
  type        = number 
  description = "build timeout in seconds"
  default     = 60
}

variable "codebuild_service_arn" {
  type = string
  default = "arn"
  description = "code build service arn"
}

variable "account_id" {
  type = string
  default = "account id"
  description = "account id for the account"
}

variable "codedeploy_service_arn" {
  type = string
  default = "arn"
  description = "code deploy service arn"
}

variable "cluster_name" {
  type = string
  default = "cluster"
  description = "ECS cluster name"
}

variable "codepipeline_arn" {
  type = string
  default = "code pipeline arn"
  description = "code pipeline role arn"
}

variable "bucket_location" {
  type = string
  default = "bucket"
  description = "s3 bucket location to store artifacts"
}

variable "kms_alias_arn" {
  type = string
  default = "kms"
  description = "kms_alias_arn"
}

variable "repo_owner" {
  type = string
  default = "repo"
  description = "github repo owner name"
}

variable "repo_name" {
  type = string
  default = "repo"
  description = "github repo name"
}

variable "branch_name" {
  type = string
  default = "branch"
  description = "github repo branch name"
}

variable "github_token" {
  type = string
  default = "token"
  description = "git token for authentication"
}

variable "deployment_controller" {
  type = string
  default = "controller"
  description = "deployment type"
}

variable "listner_priority" {
  type  = number
  default = 101
  description = "listner rule priority"
}

variable "frontend_url" {
  type  = string
  default = "url status"
  description = "url available yes or no"
}

variable "service_type" {
  type  = string
  default = "frontend"
  description = "url available yes or no"
}

variable "db_security_group" {
  type        = string 
  description = "Additional security group to ecs service"
}



# variable "fargate_microservices" {
#   description = "Map of variables to define a Fargate microservice."
#   type = map(object({
#     common_name                      = string

#     create_log_group                 = bool
#     create_ecr_repo                  = bool
#     create_service_discovery_service = bool
#     create_task_definition           = bool
#     create_ecs_service               = bool
#     create_code_deploy               = bool
#     create_deployment_group          = bool
#     create_code_pipeline             = bool
#     create_load_balancer             = bool
#     fargate_cpu                      = number
#     fargate_memory                   = number
#     container_cpu                    = number
#     container_memory                 = number
#     container_port                   = number

#     deployment_controller            = string
#     repo_owner                       = string
#     repo_name                        = string
#     branch_name                      = string

#     task_environment_variables       = list(map(string))
#     port_mapping                     = list(object({
#         containerPort = number
#         hostPort      = number
#         }))  

#     task_definition        = string
#     desired_count          = string
#     launch_type            = string
#     security_group_mapping = string
#   }))
# }