resource "kubernetes_deployment" "catalogue" {
  metadata {
    name      = "catalogue"
    namespace = data.kubernetes_namespace.sock_shop.metadata.0.name
    labels = {
      name = "catalogue"
    }
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
        name = "catalogue"
      }
    }

    template {
      metadata {
        labels = {
          name = "catalogue"
        }
      }

      spec {
        container {
          name  = "catalogue"
          image = var.CATALOGUE_IMG

          command = ["/app"]
          args    = ["-port=8080"]

          resources {
            limits = {
              cpu    = "200m"
              memory = "200Mi"
            }

            requests = {
              cpu    = "100m"
              memory = "100Mi"
            }
          }

          port {
            container_port = 8080
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
              port = 8080
            }

            initial_delay_seconds = 300
            period_seconds        = 3
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = 8080
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

resource "kubernetes_service" "catalogue" {
  metadata {
    name      = "catalogue"
    namespace = data.kubernetes_namespace.sock_shop.metadata.0.name
    labels = {
      name = "catalogue"
    }
    annotations = {
      "prometheus.io/scrape" = "true"
    }
  }

  spec {
    port {
      port        = 80
      target_port = 8080
    }

    selector = {
      name = "catalogue"
    }
  }
}
