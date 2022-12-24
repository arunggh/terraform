variable "tags" {
  type = map(any)
  default = {
    Department = "Engineering"
  }
  description = "Common tags for identify the resource easily"
}

# variable "aws_region" {
#   type = string
#   default = "us-west-2"
#   description = "Region where infrastructure to deploy"
# }

variable "az_count" {
  type = string  
  default     = "2"
  description = "number of availability zones in above region"
}

variable "app_name" {
  type = string
  default = "app"
  description = "Application name for which you want to setup the infra"
}

variable "db_engine" {
  type = string
  default = "engine"
}

variable "db_version" {
  type = string
  default = "version"
}

variable "storage_type" {
  type = string
  default = "gp2"
}

variable "storage_allocated_size" {
  type = string
  default = "min"
}

variable "storage_max_allocated_size" {
  type = string
  default = "max"
}

variable "instance_class" {
  type = string
  default = "instance_class"
}

variable "db_name" {
  type = string
  default = "test"
  sensitive   = true
}

variable "db_user" {
  type = string
  default = "test"
  sensitive   = true
}

variable "db_password" {
  type = string
  default = "test#!%123"  #Use ASCII characters besides '/', '@', '"',
  sensitive   = true
}
