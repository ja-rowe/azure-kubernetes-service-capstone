resource "kubernetes_deployment" "carts_db" {
  metadata {
    name      = "carts-db"
    namespace = var.namespace
    labels = {
      name = "carts-db"
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
        name = "carts-db"
      }
    }

    template {
      metadata {
        labels = {
          name = "carts-db"
        }
      }

      spec {
        container {
          name  = "carts-db"
          image = "mongo:3.4"

          port {
            name           = "mongo"
            container_port = 27017
          }

          security_context {
            capabilities {
              drop = ["all"]
              add  = ["CHOWN", "SETGID", "SETUID"]
            }

            read_only_root_filesystem = true
          }

          volume_mount {
            mount_path = "/tmp"
            name       = "tmp-volume"
          }
        }

        volume {
          name = "tmp-volume"

          empty_dir {
            medium = "Memory"
          }
        }

        node_selector = {
          "kubernetes.io/os" = "linux"
        }
      }
    }
  }
}

resource "kubernetes_service" "carts_db" {
  metadata {
    name      = "carts-db"
    namespace = var.namespace
    labels = {
      name = "carts-db"
    }
  }

  spec {
    port {
      port        = 27017
      target_port = 27017
    }

    selector = {
      name = "carts-db"
    }
  }
}
