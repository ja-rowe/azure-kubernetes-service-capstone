# Secrets come from the environment's Key Vault through the Secrets Store CSI driver. Pods that
# use the sock-shop-secrets ServiceAccount authenticate as the environment's identity (workload
# identity); that identity can read only its own environment's vault. Values never pass through
# Terraform state, the pipeline or the source.

locals {
  secret_provider_class_name = "sock-shop-keyvault"
  catalogue_db_secret_name   = "catalogue-db"
}

resource "kubernetes_service_account" "secrets" {
  metadata {
    name      = "sock-shop-secrets"
    namespace = data.kubernetes_namespace.sock_shop.metadata.0.name
    annotations = {
      "azure.workload.identity/client-id" = var.workload_identity_client_id
    }
  }
}

resource "kubernetes_manifest" "secret_provider_class" {
  manifest = {
    apiVersion = "secrets-store.csi.x-k8s.io/v1"
    kind       = "SecretProviderClass"
    metadata = {
      name      = local.secret_provider_class_name
      namespace = data.kubernetes_namespace.sock_shop.metadata.0.name
    }
    spec = {
      provider = "azure"
      parameters = {
        usePodIdentity = "false"
        clientID       = var.workload_identity_client_id
        keyvaultName   = var.key_vault_name
        tenantId       = var.tenant_id
        objects        = <<-EOT
          array:
            - |
              objectName: catalogue-db-root-password
              objectType: secret
        EOT
      }
      # Also expose the value as a namespace Secret so it can be used as an environment variable.
      secretObjects = [{
        secretName = local.catalogue_db_secret_name
        type       = "Opaque"
        data = [{
          objectName = "catalogue-db-root-password"
          key        = "MYSQL_ROOT_PASSWORD"
        }]
      }]
    }
  }
}
