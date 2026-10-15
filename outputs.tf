# Values other parts of the platform consume (environment deployments, access grants, release
# evidence). The registry is created by the pipeline's bootstrap stage, so it is read, not managed.

data "azurerm_container_registry" "acr" {
  name                = "sockshop1"
  resource_group_name = "aks-terraform"
}

output "cluster_id" {
  value = module.cluster.id
}

output "cluster_name" {
  value = module.cluster.name
}

output "cluster_resource_group" {
  value = module.cluster.resource_group_name
}

output "acr_id" {
  value = data.azurerm_container_registry.acr.id
}

output "acr_login_server" {
  value = data.azurerm_container_registry.acr.login_server
}

output "log_analytics_workspace_id" {
  value = module.cluster.log_analytics_workspace_id
}

# Container Insights for the cluster (monitoring link for release evidence).
output "monitoring_url" {
  value = "https://portal.azure.com/#@/resource${module.cluster.id}/insights"
}

output "kubelet_identity_object_id" {
  value = module.cluster.kubelet_identity_object_id
}

output "environment_identities" {
  value = {
    for env, id in azurerm_user_assigned_identity.environment : env => {
      id           = id.id
      client_id    = id.client_id
      principal_id = id.principal_id
    }
  }
}

output "tenant_id" {
  value = data.azurerm_client_config.current.tenant_id
}

output "oidc_issuer_url" {
  value = module.cluster.oidc_issuer_url
}

output "key_vaults" {
  value = {
    for env, kv in azurerm_key_vault.environment : env => {
      name = kv.name
      uri  = kv.vault_uri
    }
  }
}
