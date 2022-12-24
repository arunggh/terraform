output "database_address" {
  value = var.dbmodule_active ? module.database_infra[0].db_address : null
}

output "database_name" {
  value = var.dbmodule_active ? module.database_infra[0].db_name : null
}

output "database_user" {
  value = var.dbmodule_active ? module.database_infra[0].db_user : null
}

output "database_password" {
  value = var.dbmodule_active ? module.database_infra[0].db_password : null
}

output "lb_dns_frontend" {
  value = module.service_frontend.lb_dns
}