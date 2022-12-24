/*==================================================================================
              1. Create and configure a VPC to launch the db-instance in it
==================================================================================*/

data "aws_region" "current" {}

# Fetch AZs in the current region
data "aws_availability_zones" "available" {}

resource "aws_vpc" "db-vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
}

# Create private subnets, each in a different AZ
resource "aws_subnet" "db-private_subnet" {
   count                   = var.az_count 
   vpc_id                  = aws_vpc.db-vpc.id
   cidr_block              = cidrsubnet(aws_vpc.db-vpc.cidr_block, 8, count.index)
   map_public_ip_on_launch = false
   availability_zone       = data.aws_availability_zones.available.names[count.index]
   tags                    = var.tags
}

# Create public subnets, each in a different AZ
resource "aws_subnet" "db-public_subnet" {
  count                   = var.az_count
  cidr_block              = cidrsubnet(aws_vpc.db-vpc.cidr_block, 8, var.az_count + count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  vpc_id                  = aws_vpc.db-vpc.id
  map_public_ip_on_launch = true
  tags                    = var.tags
}

# Internet Gateway for the public subnet
resource "aws_internet_gateway" "db-igw" {
  vpc_id = aws_vpc.db-vpc.id
  tags   = var.tags
}

# Route the public subnet traffic through the IGW
resource "aws_route" "db-internet_access" {
  route_table_id         = aws_vpc.db-vpc.main_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.db-igw.id
}

# NAT gateway with an Elastic IP for each private subnet to get internet connectivity
resource "aws_eip" "db-eip" {
  count      = var.az_count
  vpc        = true
  depends_on = [aws_internet_gateway.db-igw]
  tags       = var.tags
}

resource "aws_nat_gateway" "db-natgw" {
  count         = var.az_count
  subnet_id     = element(aws_subnet.db-public_subnet.*.id, count.index)
  allocation_id = element(aws_eip.db-eip.*.id, count.index)
  tags          = var.tags
}

# Create a new route table for the private subnets, make it route non-local traffic through the NAT gateway to the internet
resource "aws_route_table" "db-private_rt" {
  count  = var.az_count
  vpc_id = aws_vpc.db-vpc.id
  tags   = var.tags

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = element(aws_nat_gateway.db-natgw.*.id, count.index)
  }
}

# Explicitly associate the newly created route tables to the private subnets (so they don't default to the main route table)
resource "aws_route_table_association" "db-private_rt_assgn" {
  count          = var.az_count
  subnet_id      = element(aws_subnet.db-private_subnet.*.id, count.index)
  route_table_id = element(aws_route_table.db-private_rt.*.id, count.index)
}

# Provides an RDS DB subnet group resource
resource "aws_db_subnet_group" "db-group" {
  name       = "db-group"
  subnet_ids = aws_subnet.db-private_subnet.*.id
}

/*==================================================================================
                       2. Security group for database
==================================================================================*/

# Dynamically add the rule for inbound traffic from ecs-sg to db-sg
resource "aws_security_group" "db-sg" {
  name        = "${var.app_name}-db"
  vpc_id      =  aws_vpc.db-vpc.id
  description = "rds security group for ${var.app_name}"
}

/*==================================================================================
                       3. Create database instance
==================================================================================*/

resource "aws_db_instance" "db-instance" {
identifier             = "${var.app_name}-db"
engine                 = var.db_engine
engine_version         = var.db_version
storage_type           = var.storage_type
allocated_storage      = var.storage_allocated_size
max_allocated_storage  = var.storage_max_allocated_size
instance_class         = var.instance_class
db_subnet_group_name   = aws_db_subnet_group.db-group.name
vpc_security_group_ids = ["${aws_security_group.db-sg.id}"]
publicly_accessible    = false
db_name                = var.db_name
username               = var.db_user
password               = var.db_password
skip_final_snapshot    = true
tags                   = var.tags
}

