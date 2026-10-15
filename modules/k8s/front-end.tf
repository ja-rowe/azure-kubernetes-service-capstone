resource "kubernetes_deployment" "front_end" {
  metadata {
    name      = "front-end"
    namespace = var.namespace
  }

  spec {
    replicas = var.replicas

    # A rollout that does not become ready within 5 minutes is reported as failed by Kubernetes;
    # the old pods keep serving until new ones are ready.
    progress_deadline_seconds = 300

    strategy {
      type = "RollingUpdate"

      rolling_update {
        max_surge       = 1
        max_unavailable = 0
      }
    }

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
          "kubernetes.io/os" = "linux"
        }
      }
    }
  }
}

resource "kubernetes_service" "front_end" {
  metadata {
    name      = "front-end"
    namespace = var.namespace
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
