variable "tags" {
  type = map(any)
  default = {
    Department = "Engineering"
  }
  description = "Common tags for identify the resource easily"
}

variable "aws_region" {
  type = string
  default = "us-west-2"
  description = "Region where infrastructure to deploy"
}

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

variable "app_port" {
  type = string  
  default     = "80"
  description = "port exposed on the docker image"
}

variable "dbmodule_active" {
  type = bool  
  default     = true
  description = "dbmodule status"
}

variable "db_vpc_id" {
  type = string  
  default     = "vpc-id"
  description = "vpc id from the db-structure"
}

variable "db-sg-id" {
  type = string  
  default     = "sg-id"
  description = "sg id from the db-sg"
}