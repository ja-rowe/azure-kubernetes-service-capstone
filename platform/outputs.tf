output "namespaces" {
  value = { for env, ns in kubernetes_namespace.environment : env => ns.metadata[0].name }
}

output "namespace_writers" {
  value = { for env, ra in azurerm_role_assignment.namespace_writer : env => ra.principal_id }
}
