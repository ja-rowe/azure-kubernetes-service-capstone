# Kubernetes platform shared by the environments: the namespaces and who may deploy into them.
#
# Namespaces are owned here, not by the environment deployments, because each environment's
# identity only has access inside its own namespace and therefore cannot create one. Access is
# granted with Azure role assignments scoped to the namespace (Azure RBAC for Kubernetes).
#
# Applied by an operator (role assignments need User Access Administrator or Owner) who reaches the
# cluster through Entra ID (Azure Kubernetes Service RBAC Cluster Admin, granted in access/; local
# accounts are disabled):
#
#   az aks get-credentials -g aks-terraform -n aks-terraform --file ~/.kube/aks-terraform --overwrite-existing
#   kubelogin convert-kubeconfig -l azurecli --kubeconfig ~/.kube/aks-terraform
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

  required_version = ">= 1.7.0"

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

# The operator's own Entra login (kubeconfig converted with kubelogin, see above).
provider "kubernetes" {
  config_path = var.kubeconfig
}

data "azurerm_client_config" "current" {}

# Key Vault names per environment (outputs of the infrastructure root).
data "terraform_remote_state" "infra" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.state_resource_group
    storage_account_name = var.state_storage_account
    container_name       = var.state_container
    key                  = "aks.terraform.tfstate"
  }
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

# ------------------------------------------------- secrets wiring per namespace

# Binds each namespace to its environment's identity and Key Vault. Owned here rather than by the
# deployments, so a deployment cannot point its namespace at another environment's identity or
# vault (and the namespace-scoped deploy role has no access to SecretProviderClasses anyway).
# Pods using this ServiceAccount authenticate as id-sockshop-<env> (workload identity; the
# federated credential is in the infrastructure root).
resource "kubernetes_service_account" "secrets" {
  for_each = kubernetes_namespace.environment

  metadata {
    name      = "sock-shop-secrets"
    namespace = each.value.metadata[0].name
    annotations = {
      "azure.workload.identity/client-id" = data.azurerm_user_assigned_identity.environment[each.key].client_id
    }
  }
}

# Syncs catalogue-db-root-password from the environment's vault into the namespace Secret
# catalogue-db (key MYSQL_ROOT_PASSWORD) while a pod mounts it.
resource "kubernetes_manifest" "secret_provider_class" {
  for_each = kubernetes_namespace.environment

  manifest = {
    apiVersion = "secrets-store.csi.x-k8s.io/v1"
    kind       = "SecretProviderClass"
    metadata = {
      name      = "sock-shop-keyvault"
      namespace = each.value.metadata[0].name
    }
    spec = {
      provider = "azure"
      parameters = {
        usePodIdentity = "false"
        clientID       = data.azurerm_user_assigned_identity.environment[each.key].client_id
        keyvaultName   = data.terraform_remote_state.infra.outputs.key_vaults[each.key].name
        tenantId       = data.azurerm_client_config.current.tenant_id
        objects        = <<-EOT
          array:
            - |
              objectName: catalogue-db-root-password
              objectType: secret
        EOT
      }
      secretObjects = [{
        secretName = "catalogue-db"
        type       = "Opaque"
        data = [{
          objectName = "catalogue-db-root-password"
          key        = "MYSQL_ROOT_PASSWORD"
        }]
      }]
    }
  }
}

# Created by the dev deployment before they moved here.
import {
  to = kubernetes_service_account.secrets["dev"]
  id = "sock-shop-dev/sock-shop-secrets"
}

import {
  to = kubernetes_manifest.secret_provider_class["dev"]
  id = "apiVersion=secrets-store.csi.x-k8s.io/v1,kind=SecretProviderClass,namespace=sock-shop-dev,name=sock-shop-keyvault"
}
