# One Sock Shop deployment per environment (dev, staging, prod) in its own namespace on the shared
# AKS cluster created by the root module. The Terraform state is per environment
# (key `env-<environment>.tfstate`); the pipelines pass the key with -backend-config.
#
# What is deployed is fully described by `var.images`, and `output "images"` returns it, so
# promoting an environment means applying the source environment's `images` output to the target.

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

# Credentials of the existing cluster. With Entra ID integration only the local admin config
# carries a client certificate; this is temporary until deployments authenticate with the
# environment's Entra identity.
# No depends_on: the cluster is managed by the root module,
# and a depends_on here would defer the read and leave the kubernetes provider unconfigured.
data "azurerm_kubernetes_cluster" "cluster" {
  name                = var.cluster_name
  resource_group_name = var.cluster_resource_group
}

# Environment-specific settings (replicas, ...) live in config/<environment>.yaml.
locals {
  config = yamldecode(file("${path.module}/config/${var.environment}.yaml"))
}

# Outputs of the infrastructure root (Key Vault names, tenant).
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
  name                = "id-sockshop-${var.environment}"
  resource_group_name = var.cluster_resource_group
}

module "k8s" {
  source = "../modules/k8s"

  namespace                   = "sock-shop-${var.environment}"
  replicas                    = local.config.replicas
  key_vault_name              = data.terraform_remote_state.infra.outputs.key_vaults[var.environment].name
  tenant_id                   = data.terraform_remote_state.infra.outputs.tenant_id
  workload_identity_client_id = data.azurerm_user_assigned_identity.environment.client_id

  host                   = data.azurerm_kubernetes_cluster.cluster.kube_admin_config.0.host
  client_certificate     = base64decode(data.azurerm_kubernetes_cluster.cluster.kube_admin_config.0.client_certificate)
  client_key             = base64decode(data.azurerm_kubernetes_cluster.cluster.kube_admin_config.0.client_key)
  cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.cluster.kube_admin_config.0.cluster_ca_certificate)

  CARTS_IMG        = var.images["carts"]
  CATALOGUE_IMG    = var.images["catalogue"]
  CATALOGUE_DB_IMG = var.images["catalogue-db"]
  ORDERS_IMG       = var.images["orders"]
  PAYMENT_IMG      = var.images["payment"]
  QUEUE_MASTER_IMG = var.images["queue-master"]
  SHIPPING_IMG     = var.images["shipping"]
  USER_IMG         = var.images["user"]
  USER_DB_IMG      = var.images["user-db"]
  FRONTEND_IMG     = var.images["front-end"]
}

# The namespace moved to the platform/ root. Forget it here without deleting it.
removed {
  from = module.k8s.kubernetes_namespace.sock_shop

  lifecycle {
    destroy = false
  }
}
