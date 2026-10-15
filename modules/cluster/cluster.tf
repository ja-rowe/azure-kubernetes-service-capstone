data "azurerm_client_config" "current" {}

resource "azurerm_kubernetes_cluster" "aks-terraform" {
  name                = "aks-terraform"
  location            = "centralus"
  resource_group_name = "aks-terraform"
  dns_prefix          = "aks-terraform"

  default_node_pool {
    name       = "default"
    node_count = 4
    vm_size    = "Standard_B2s"
  }
  node_provisioning_profile {
    mode               = "Manual"
    default_node_pools = "None"
  }
  # Managed identity instead of a service principal: no client secret to store or rotate.
  # AKS also creates a kubelet identity in the node resource group, used for image pulls.
  identity {
    type = "SystemAssigned"
  }

  # Entra ID authentication with Azure RBAC for Kubernetes authorization, so access can be
  # granted per namespace with Azure role assignments. Local accounts stay enabled until the
  # environment deployments authenticate with Entra identities.
  azure_active_directory_role_based_access_control {
    azure_rbac_enabled = true
    tenant_id          = data.azurerm_client_config.current.tenant_id
  }
  local_account_disabled = false

  # Workload identity: pods can authenticate as a managed identity through a federated
  # ServiceAccount, and the Key Vault CSI driver mounts secrets with that identity.
  oidc_issuer_enabled       = true
  workload_identity_enabled = true
  key_vault_secrets_provider {
    secret_rotation_enabled = true
  }

  network_profile {
    network_plugin    = "kubenet"
    load_balancer_sku = "standard"
  }
  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.logws.id
  }
}

resource "azurerm_log_analytics_workspace" "logws" {
  resource_group_name = "aks-terraform"
  location            = "centralus"
  name                = "aks-terraform-log-w"
}

resource "azurerm_log_analytics_solution" "logsoln" {
  solution_name         = "ContainerInsights"
  location              = "centralus"
  resource_group_name   = "aks-terraform"
  workspace_resource_id = azurerm_log_analytics_workspace.logws.id
  workspace_name        = azurerm_log_analytics_workspace.logws.name

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/ContainerInsights"
  }
}