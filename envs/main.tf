# One Sock Shop deployment per environment (dev, staging, prod) in its own namespace on the shared
# AKS cluster created by the root module. The Terraform state is per environment
# (container `env-<environment>`, key `env-<environment>.tfstate`); the pipelines pass both with
# -backend-config.
#
# What is deployed is fully described by `var.images`, and `output "images"` returns it, so
# promoting an environment means applying the source environment's `images` output to the target.

terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.24.0"
    }
  }

  required_version = ">= 1.7.0"

  # State per environment in its own container (env-<environment>), which only that
  # environment's identity may read and write; the pipelines pass it with -backend-config.
  backend "azurerm" {}
}

# Environment-specific settings (replicas, ...) live in config/<environment>.yaml.
locals {
  config = yamldecode(file("${path.module}/config/${var.environment}.yaml"))
}

# Runs with the environment identity's own access only: its namespace on the cluster (through
# var.kubeconfig) and its state container. Nothing here reads other environments or the
# infrastructure state.
module "k8s" {
  source = "../modules/k8s"

  kubeconfig = var.kubeconfig
  namespace  = "sock-shop-${var.environment}"
  replicas   = local.config.replicas

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

# Moved to the platform/ root (namespace, and the ServiceAccount and SecretProviderClass that bind
# it to the environment's identity and Key Vault). Forget them here without deleting them.
removed {
  from = module.k8s.kubernetes_namespace.sock_shop

  lifecycle {
    destroy = false
  }
}

removed {
  from = module.k8s.kubernetes_service_account.secrets

  lifecycle {
    destroy = false
  }
}

removed {
  from = module.k8s.kubernetes_manifest.secret_provider_class

  lifecycle {
    destroy = false
  }
}
