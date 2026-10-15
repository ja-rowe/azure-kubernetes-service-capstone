output "kube_config" {
  value = azurerm_kubernetes_cluster.aks-terraform.kube_config_raw
}

output "cluster_ca_certificate" {
  value = azurerm_kubernetes_cluster.aks-terraform.kube_config.0.cluster_ca_certificate
}

output "client_certificate" {
  value = azurerm_kubernetes_cluster.aks-terraform.kube_config.0.client_certificate
}

output "client_key" {
  value = azurerm_kubernetes_cluster.aks-terraform.kube_config.0.client_key
}

output "host" {
  value = azurerm_kubernetes_cluster.aks-terraform.kube_config.0.host
}

output "id" {
  value = azurerm_kubernetes_cluster.aks-terraform.id
}

output "name" {
  value = azurerm_kubernetes_cluster.aks-terraform.name
}

output "resource_group_name" {
  value = azurerm_kubernetes_cluster.aks-terraform.resource_group_name
}

output "log_analytics_workspace_id" {
  value = azurerm_log_analytics_workspace.logws.id
}

# Identity the kubelet uses to pull images (needs AcrPull on the registry).
output "kubelet_identity_object_id" {
  value = azurerm_kubernetes_cluster.aks-terraform.kubelet_identity[0].object_id
}

# The cluster's own (control plane) managed identity.
output "principal_id" {
  value = azurerm_kubernetes_cluster.aks-terraform.identity[0].principal_id
}
