output "db-sg-id" {
  value = aws_security_group.db-sg.id
}

output "db_vpc_id" {
  value = aws_vpc.db-vpc.id
}

output "public_subnet_id" {
  value = aws_subnet.db-public_subnet.*.id
}

output "private_subnet_id" {
  value = aws_subnet.db-private_subnet.*.id
}

output "db_address" {
  value = aws_db_instance.db-instance.address
}

output "db_name" {
  value = nonsensitive(aws_db_instance.db-instance.db_name)
}

output "db_user" {
  value = nonsensitive(aws_db_instance.db-instance.username)
}

output "db_password" {
  value = nonsensitive(aws_db_instance.db-instance.password)
}

output "ec2_public_subnet_id" {
  value = aws_subnet.db-public_subnet[0].id
}