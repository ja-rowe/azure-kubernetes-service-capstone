resource "kubernetes_deployment" "session_db" {
  metadata {
    name      = "session-db"
    namespace = var.namespace
    labels = {
      name = "session-db"
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
        name = "session-db"
      }
    }

    template {
      metadata {
        labels = {
          name = "session-db"
        }
        annotations = {
          "prometheus.io/scrape" = "false"
        }
      }

      spec {
        container {
          name  = "session-db"
          image = "redis:alpine"

          port {
            name           = "redis"
            container_port = 6379
          }

          security_context {
            capabilities {
              drop = ["all"]
              add  = ["CHOWN", "SETGID", "SETUID"]
            }

            read_only_root_filesystem = true
          }
        }

        node_selector = {
          "kubernetes.io/os" = "linux"
        }
      }
    }
  }
}

resource "kubernetes_service" "session_db" {
  metadata {
    name      = "session-db"
    namespace = var.namespace
    labels = {
      name = "session-db"
    }
  }

  spec {
    port {
      port        = 6379
      target_port = 6379
    }

    selector = {
      name = "session-db"
    }
  }
}
