resource "azurerm_kubernetes_cluster" "aks-terraform" {
  name = "aks-terraform"
  location = "eastus"
  resource_group_name = "aks-terraform"
  dns_prefix = "aks-terraform"

  default_node_pool {
    name = "default"
    node_count = 2
    vm_size = "Standard_E4_v4"
  }
  service_principal {
    client_id = var.client_id
    client_secret = var.client_secret
  }
  network_profile {
    network_plugin = "kubenet"
    load_balancer_sku = "standard"
  }
  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.logws.id
  }
}

resource "azurerm_log_analytics_workspace" "logws" {
  resource_group_name = "aks-terraform"
  location = "eastus"
  name = "aks-terraform-log-w"
}

resource "azurerm_log_analytics_solution" "logsoln" {
  solution_name         = "ContainerInsights"
  location              = "eastus"
  resource_group_name   = "aks-terraform"
  workspace_resource_id = azurerm_log_analytics_workspace.logws.id
  workspace_name        = azurerm_log_analytics_workspace.logws.name

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/ContainerInsights"
  }
}