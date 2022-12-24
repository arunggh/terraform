output "cloudwatch_log_group_name" {
  value = aws_cloudwatch_log_group.log-group.name
}

output "repository_url" {
  value = aws_ecr_repository.ecr-repo.repository_url
}

output "repository_name" {
  value = aws_ecr_repository.ecr-repo.name
}

output "service_discovery_arn" {
  value = aws_service_discovery_service.service_discovery.arn
}

output "service_discovery_name" {
  value = aws_service_discovery_service.service_discovery.name
}

output "task_definition_arn" {
  value = aws_ecs_task_definition.ecs-taskdef.arn
}

output "service_name" {
  value = aws_ecs_service.ecsinfra-service.name
}

output "code_deploy_name" {
  value = aws_codedeploy_app.codedeploy.name
}

output "deployment_group_name" {
  value = aws_codedeploy_deployment_group.deploymentgroup[*].deployment_group_name
}

output "lb_dns" {
  value = var.create_load_balancer ? aws_alb.ecsinfra-alb[0].dns_name : null
}
