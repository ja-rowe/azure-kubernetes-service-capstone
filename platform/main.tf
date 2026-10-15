# Kubernetes platform shared by the environments: the namespaces and who may deploy into them.
#
# Namespaces are owned here, not by the environment deployments, because each environment's
# identity only has access inside its own namespace and therefore cannot create one. Access is
# granted with Azure role assignments scoped to the namespace (Azure RBAC for Kubernetes).
#
# Applied by an operator (role assignments need User Access Administrator or Owner):
#
#   export ARM_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
#   export ARM_ACCESS_KEY=$(az storage account keys list -g t3-capstone-tfstate-rg -n t3capstonetfstate --query '[0].value' -o tsv)
#   terraform init -backend-config=resource_group_name=t3-capstone-tfstate-rg \
#     -backend-config=storage_account_name=t3capstonetfstate -backend-config=container_name=tfstate \
#     -backend-config=key=platform.tfstate
#   terraform apply

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.8.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.24.0"
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

data "azurerm_kubernetes_cluster" "cluster" {
  name                = var.cluster_name
  resource_group_name = var.cluster_resource_group
}

# Operator path: the local admin credentials (local accounts are still enabled on the cluster).
provider "kubernetes" {
  host                   = data.azurerm_kubernetes_cluster.cluster.kube_admin_config.0.host
  client_certificate     = base64decode(data.azurerm_kubernetes_cluster.cluster.kube_admin_config.0.client_certificate)
  client_key             = base64decode(data.azurerm_kubernetes_cluster.cluster.kube_admin_config.0.client_key)
  cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.cluster.kube_admin_config.0.cluster_ca_certificate)
}

data "azurerm_user_assigned_identity" "environment" {
  for_each            = toset(local.environments)
  name                = "id-sockshop-${each.key}"
  resource_group_name = var.cluster_resource_group
}

resource "kubernetes_namespace" "environment" {
  for_each = toset(local.environments)

  metadata {
    name = "sock-shop-${each.key}"
    labels = {
      environment = each.key
      app         = "sock-shop"
    }
  }
}

# sock-shop-dev was created by the dev deployment before namespaces moved here.
import {
  to = kubernetes_namespace.environment["dev"]
  id = "sock-shop-dev"
}

# Each environment's identity may read and write workloads, services, config maps and secrets in
# its own namespace only: no roles or role bindings, nothing cluster-scoped, no other namespace.
resource "azurerm_role_assignment" "namespace_writer" {
  for_each             = toset(local.environments)
  scope                = "${data.azurerm_kubernetes_cluster.cluster.id}/namespaces/${kubernetes_namespace.environment[each.key].metadata[0].name}"
  role_definition_name = "Azure Kubernetes Service RBAC Writer"
  principal_id         = data.azurerm_user_assigned_identity.environment[each.key].principal_id
}
