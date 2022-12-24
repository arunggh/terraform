output "vpc_id" {
  value = var.dbmodule_active ? null : aws_vpc.ecsinfra-vpc[0].id
}

output "public_subnet_id" {
  value = var.dbmodule_active ? null : aws_subnet.ecsinfra-public_subnet.*.id
}

output "private_subnet_id" {
  value = var.dbmodule_active ? null : aws_subnet.ecsinfra-private_subnet.*.id
}

output "alb_sg_id" {
  value = aws_security_group.ecsinfra-alb_sg.id
}

output "ecs_sg_id" {
  value = aws_security_group.ecsinfra-ecs_sg.id
}

output "cluster_arn" {
  value = aws_ecs_cluster.ecsinfra-cluster.arn
}

output "cluster_id" {
  value = aws_ecs_cluster.ecsinfra-cluster.id
}

output "cluster_name" {
  value = aws_ecs_cluster.ecsinfra-cluster.name
}

output "execution_role_arn" {
  value = aws_iam_role.execution_role.arn
}

output "task_role_arn" {
  value = aws_iam_role.task_role.arn
}

output "service_discovery_namespace_id" {
  value = aws_service_discovery_private_dns_namespace.service_discovery_ns.id
}

output "service_discovery_namespace_name" {
  value = aws_service_discovery_private_dns_namespace.service_discovery_ns.name
}

output "account_id" {
  value = data.aws_caller_identity.current.account_id
}

output "kms_alias_arn" {
  value = aws_kms_alias.kms_alias.arn
}

output "bucket_location" {
  value = aws_s3_bucket.artifacts.bucket
}

output "codebuild_arn" {
  value = aws_iam_role.codebuild.arn
}

output "codedeploy_arn" {
  value = aws_iam_role.codedeploy.arn
}

output "codepipeline_arn" {
  value = aws_iam_role.codepipeline.arn
}

output "ec2_public_subnet_id" {
  value = var.dbmodule_active ? null : aws_subnet.ecsinfra-public_subnet[0].id
}