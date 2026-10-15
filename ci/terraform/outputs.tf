output "acr_service_connection" {
  value = azuredevops_serviceendpoint_azurecr.acr.service_endpoint_name
}

output "environments" {
  value = { for k, e in azuredevops_environment.env : k => e.id }
}

output "environment_connections" {
  value = { for env, sc in azuredevops_serviceendpoint_azurerm.environment : env => sc.service_endpoint_name }
}
