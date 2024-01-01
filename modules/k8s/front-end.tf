resource "kubernetes_deployment" "front_end" {
  metadata {
    name      = "front-end"
    namespace = kubernetes_namespace.sock_shop.metadata.0.name
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        name = "front-end"
      }
    }

    template {
      metadata {
        labels = {
          name = "front-end"
        }
      }

      spec {
        container {
          name  = "front-end"
          image = var.FRONTEND_IMG

          resources {
            limits = {
              cpu    = "300m"
              memory = "1000Mi"
            }

            requests = {
              cpu    = "100m"
              memory = "300Mi"
            }
          }

          port {
            container_port = 8079
          }

          env {
            name  = "SESSION_REDIS"
            value = "true"
          }

          security_context {
            run_as_non_root = true
            run_as_user     = 10001

            capabilities {
              drop = ["all"]
            }

            read_only_root_filesystem = true
          }

          liveness_probe {
            http_get {
              path = "/"
              port = 8079
            }

            initial_delay_seconds = 300
            period_seconds        = 3
          }

          readiness_probe {
            http_get {
              path = "/"
              port = 8079
            }

            initial_delay_seconds = 30
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

resource "kubernetes_service" "front_end" {
  metadata {
    name      = "front-end"
    namespace = kubernetes_namespace.sock_shop.metadata.0.name
    labels = {
      name = "front-end"
    }
    annotations = {
      "prometheus.io/scrape" = "true"
    }
  }

  spec {
    type = "LoadBalancer"

    port {
      port        = 80
      target_port = 8079
    }

    selector = {
      name = "front-end"
    }
  }
}
