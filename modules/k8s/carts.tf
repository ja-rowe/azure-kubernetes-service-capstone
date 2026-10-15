resource "kubernetes_deployment" "carts" {
  metadata {
    name      = "carts"
    namespace = data.kubernetes_namespace.sock_shop.metadata.0.name
    labels = {
      name = "carts"
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
        name = "carts"
      }
    }

    template {
      metadata {
        labels = {
          name = "carts"
        }
      }

      spec {
        container {
          name  = "carts"
          image = var.CARTS_IMG

          env {
            name  = "JAVA_OPTS"
            value = "-Xms64m -Xmx128m -XX:+UseG1GC -Djava.security.egd=file:/dev/urandom -Dspring.zipkin.enabled=false"
          }

          resources {
            limits = {
              cpu    = "300m"
              memory = "500Mi"
            }

            requests = {
              cpu    = "100m"
              memory = "200Mi"
            }
          }

          port {
            container_port = 80
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = 80
            }

            initial_delay_seconds = 60
            period_seconds        = 10
            failure_threshold     = 12
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

resource "kubernetes_service" "carts" {
  metadata {
    name      = "carts"
    namespace = data.kubernetes_namespace.sock_shop.metadata.0.name
    labels = {
      name = "carts"
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
      name = "carts"
    }
  }
}

