resource "kubernetes_deployment" "queue_master" {
  metadata {
    name      = "queue-master"
    namespace = data.kubernetes_namespace.sock_shop.metadata.0.name
    labels = {
      name = "queue-master"
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
        name = "queue-master"
      }
    }

    template {
      metadata {
        labels = {
          name = "queue-master"
        }
      }

      spec {
        container {
          name  = "queue-master"
          image = var.QUEUE_MASTER_IMG

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
              memory = "300Mi"
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
        }

        node_selector = {
          "kubernetes.io/os" = "linux"
        }
      }
    }
  }
}

resource "kubernetes_service" "queue_master" {
  metadata {
    name      = "queue-master"
    namespace = data.kubernetes_namespace.sock_shop.metadata.0.name
    labels = {
      name = "queue-master"
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
      name = "queue-master"
    }
  }
}
