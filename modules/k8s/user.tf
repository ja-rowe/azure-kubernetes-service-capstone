resource "kubernetes_deployment" "user" {
  metadata {
    name      = "user"
    namespace = kubernetes_namespace.sock_shop.metadata.0.name
    labels = {
      name = "user"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        name = "user"
      }
    }

    template {
      metadata {
        labels = {
          name = "user"
        }
      }

      spec {
        container {
          name  = "user"
          image = var.USER_IMG

          resources {
            limits = {
              cpu    = "300m"
              memory = "200Mi"
            }

            requests = {
              cpu    = "100m"
              memory = "100Mi"
            }
          }

          port {
            container_port = 8084
          }

          env {
            name  = "mongo"
            value = "user-db:27017"
          }

          security_context {
            run_as_non_root = true
            run_as_user     = 10001

            capabilities {
              drop = ["all"]
              add  = ["NET_BIND_SERVICE"]
            }

            read_only_root_filesystem = true
          }

          liveness_probe {
            http_get {
              path = "/health"
              port = 8084
            }

            initial_delay_seconds = 300
            period_seconds        = 3
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = 8084
            }

            initial_delay_seconds = 180
            period_seconds        = 3
          }
        }

        node_selector = {
          "beta.kubernetes.io/os" = "linux"
        }
      }
    }
  }
}

resource "kubernetes_service" "user" {
  metadata {
    name      = "user"
    namespace = kubernetes_namespace.sock_shop.metadata.0.name
    labels = {
      name = "user"
    }
    annotations = {
      "prometheus.io/scrape" = "true"
    }
  }

  spec {
    port {
      port        = 8084
      target_port = 8084
    }

    selector = {
      name = "user"
    }
  }
}
