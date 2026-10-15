# Role assignments the infrastructure pipeline cannot make itself.
#
# The pipeline's service principal has no permission to create role assignments, so this root is
# applied by an operator (an account with User Access Administrator or Owner on the subscription)
# after the cluster exists:
#
#   export ARM_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
#   export ARM_ACCESS_KEY=$(az storage account keys list -g t3-capstone-tfstate-rg -n t3capstonetfstate --query '[0].value' -o tsv)
#   terraform init -backend-config=resource_group_name=t3-capstone-tfstate-rg \
#     -backend-config=storage_account_name=t3capstonetfstate -backend-config=container_name=tfstate \
#     -backend-config=key=access.tfstate
#   terraform apply

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.8.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.10.0"
    }
  }

  required_version = ">= 1.5.0"

  backend "azurerm" {}
}

provider "azurerm" {
  features {}
}

provider "azuread" {}

data "azurerm_kubernetes_cluster" "cluster" {
  name                = var.cluster_name
  resource_group_name = var.cluster_resource_group
}

data "azurerm_container_registry" "acr" {
  name                = var.acr_name
  resource_group_name = var.acr_resource_group
}

# The cluster runs with a service principal; its kubelet pulls images with that identity.
data "azuread_service_principal" "cluster" {
  client_id = data.azurerm_kubernetes_cluster.cluster.service_principal[0].client_id
}

resource "azurerm_role_assignment" "cluster_acr_pull" {
  scope                = data.azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = data.azuread_service_principal.cluster.object_id
}

# The grant was first made by hand; adopt it instead of creating a duplicate.
import {
  to = azurerm_role_assignment.cluster_acr_pull
  id = "/subscriptions/ce33f549-c7bf-44f7-b22b-7036ae957695/resourceGroups/aks-terraform/providers/Microsoft.ContainerRegistry/registries/sockshop1/providers/Microsoft.Authorization/roleAssignments/912529fa-df6c-4b5f-9b98-79ea71c64da4"
}
