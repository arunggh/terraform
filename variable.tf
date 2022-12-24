locals {
  tags = {
    Name        = "${var.app_name}-ecs"
    Department  = "Production"
    ManagedBy   = "Terraform"
    Environment = "ECS-Infrastructure"
    Region      = "${var.aws_region}"
  }
}

variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "Region where infrastructure to deploy"
}

variable "access_key" {
  type        = string
  default     = "access"
  description = "Region where infrastructure to deploy"
}

variable "secret_key" {
  type        = string
  default     = "secret"
  description = "Region where infrastructure to deploy"
}

variable "app_name" {
  type        = string
  default     = "test"
  description = "Application name for which you want to setup the infra"
}

variable "app_port" {
  type        = string
  default     = "80"
  description = "port exposed on the docker image"
}

variable "fargate_cpu" {
  type        = string
  default     = "1024"
  description = "CPU for fargate instance"
}

variable "fargate_memory" {
  type        = string
  default     = "2048"
  description = "Memory for fargate instance"
}

variable "container_cpu" {
  type        = number
  default     = 1024
  description = "CPU for container instance"
}

variable "container_memory" {
  type        = number
  default     = 2048
  description = "Memory for container instance"
}

variable "container_port" {
  type        = number
  default     = 80
  description = "port exposed to load balancer"
}

variable "Git_Token" {
  type        = string
  default     = ""
  description = "owner of the github"
}

variable "dbmodule_active" {
  type    = bool
  default = true
}

variable "db_security_group" {
  type    = string
  default = "sg-id"
}