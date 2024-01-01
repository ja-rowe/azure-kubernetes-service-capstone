resource "kubernetes_deployment" "carts_db" {
  metadata {
    name      = "carts-db"
    namespace = kubernetes_namespace.sock_shop.metadata.0.name
    labels = {
      name = "carts-db"
    }
  }

  spec {
    replicas = 1

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
          image = "mongo"

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
          "beta.kubernetes.io/os" = "linux"
        }
      }
    }
  }
}

resource "kubernetes_service" "carts_db" {
  metadata {
    name      = "carts-db"
    namespace = kubernetes_namespace.sock_shop.metadata.0.name
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
