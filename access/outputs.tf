output "kubelet_identity_object_id" {
  value = data.azurerm_kubernetes_cluster.cluster.kubelet_identity[0].object_id
}

output "environment_identity_principals" {
  value = { for env, id in data.azurerm_user_assigned_identity.environment : env => id.principal_id }
}

output "environment_state_containers" {
  value = { for env, c in azurerm_storage_container.environment_state : env => c.name }
}
