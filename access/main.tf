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
  }

  required_version = ">= 1.5.0"

  backend "azurerm" {}
}

provider "azurerm" {
  features {}
}

locals {
  environments = ["dev", "staging", "prod"]
}

# The account applying this root (the operator).
data "azurerm_client_config" "current" {}

data "azurerm_kubernetes_cluster" "cluster" {
  name                = var.cluster_name
  resource_group_name = var.cluster_resource_group
}

data "azurerm_container_registry" "acr" {
  name                = var.acr_name
  resource_group_name = var.acr_resource_group
}

data "azurerm_user_assigned_identity" "environment" {
  for_each            = toset(local.environments)
  name                = "id-sockshop-${each.key}"
  resource_group_name = var.cluster_resource_group
}

# Image pulls: the cluster runs with a managed identity, and its kubelet identity pulls images.
resource "azurerm_role_assignment" "kubelet_acr_pull" {
  scope                = data.azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = data.azurerm_kubernetes_cluster.cluster.kubelet_identity[0].object_id
}

# Each environment identity may fetch the (Entra) cluster credentials. What it may do inside the
# cluster is granted per namespace separately (Azure RBAC for Kubernetes).
resource "azurerm_role_assignment" "environment_cluster_user" {
  for_each             = data.azurerm_user_assigned_identity.environment
  scope                = data.azurerm_kubernetes_cluster.cluster.id
  role_definition_name = "Azure Kubernetes Service Cluster User Role"
  principal_id         = each.value.principal_id
}

# The operator administers the cluster through Entra ID (kubectl with Azure RBAC).
resource "azurerm_role_assignment" "operator_cluster_admin" {
  scope                = data.azurerm_kubernetes_cluster.cluster.id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  principal_id         = data.azurerm_client_config.current.object_id
}
