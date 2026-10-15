resource "kubernetes_deployment" "catalogue_db" {
  metadata {
    name      = "catalogue-db"
    namespace = var.namespace
    labels = {
      name = "catalogue-db"
    }
  }

  spec {
    replicas = 1

    # Single-instance state without a shared volume: never run two copies at once.
    strategy {
      type = "Recreate"
    }

    selector {
      match_labels = {
        name = "catalogue-db"
      }
    }

    template {
      metadata {
        labels = {
          name                          = "catalogue-db"
          "azure.workload.identity/use" = "true"
        }
      }

      spec {
        # Runs as the environment's identity (workload identity) to read its Key Vault.
        service_account_name = local.service_account_name

        container {
          name  = "catalogue-db"
          image = var.CATALOGUE_DB_IMG
          # From the environment's Key Vault, synced by the CSI driver (see secrets.tf).
          env {
            name = "MYSQL_ROOT_PASSWORD"
            value_from {
              secret_key_ref {
                name = local.catalogue_db_secret_name
                key  = "MYSQL_ROOT_PASSWORD"
              }
            }
          }

          env {
            name  = "MYSQL_DATABASE"
            value = "socksdb"
          }

          port {
            name           = "mysql"
            container_port = 3306
          }

          volume_mount {
            name       = "secrets-store"
            mount_path = "/mnt/secrets-store"
            read_only  = true
          }
        }

        volume {
          name = "secrets-store"

          csi {
            driver    = "secrets-store.csi.k8s.io"
            read_only = true
            volume_attributes = {
              secretProviderClass = local.secret_provider_class_name
            }
          }
        }

        node_selector = {
          "kubernetes.io/os" = "linux"
        }
      }
    }
  }
}

resource "kubernetes_service" "catalogue_db" {
  metadata {
    name      = "catalogue-db"
    namespace = var.namespace
    labels = {
      name = "catalogue-db"
    }
  }

  spec {
    port {
      port        = 3306
      target_port = 3306
    }

    selector = {
      name = "catalogue-db"
    }
  }
}
