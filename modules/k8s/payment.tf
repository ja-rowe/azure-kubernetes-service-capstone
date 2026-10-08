resource "kubernetes_deployment" "payment" {
  metadata {
    name      = "payment"
    namespace = kubernetes_namespace.sock_shop.metadata.0.name
    labels = {
      name = "payment"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        name = "payment"
      }
    }

    template {
      metadata {
        labels = {
          name = "payment"
        }
      }

      spec {
        container {
          name  = "payment"
          image = var.PAYMENT_IMG

          resources {
            limits = {
              cpu    = "200m"
              memory = "200Mi"
            }

            requests = {
              cpu    = "99m"
              memory = "100Mi"
            }
          }

          port {
            container_port = 80
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
              port = 80
            }

            initial_delay_seconds = 300
            period_seconds        = 3
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = 80
            }

            initial_delay_seconds = 180
            period_seconds        = 3
          }
        }

        node_selector = {
          "kubernetes.io/os" = "linux"
        }
      }
    }
  }
}

resource "kubernetes_service" "payment" {
  metadata {
    name      = "payment"
    namespace = kubernetes_namespace.sock_shop.metadata.0.name
    labels = {
      name = "payment"
    }
    annotations = {
      "prometheus.io/scrape" = "true"
    }
  }

  spec {
    port {
      port        = 80
      target_port = 80
    }

    selector = {
      name = "payment"
    }
  }
}
