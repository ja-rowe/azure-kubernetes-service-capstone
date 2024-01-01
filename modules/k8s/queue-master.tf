resource "kubernetes_deployment" "queue_master" {
  metadata {
    name      = "queue-master"
    namespace = kubernetes_namespace.sock_shop.metadata.0.name
    labels = {
      name = "queue-master"
    }
  }

  spec {
    replicas = 1

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
            container_port = 8080
          }
        }

        node_selector = {
          "beta.kubernetes.io/os" = "linux"
        }
      }
    }
  }
}

resource "kubernetes_service" "queue_master" {
  metadata {
    name      = "queue-master"
    namespace = kubernetes_namespace.sock_shop.metadata.0.name
    labels = {
      name = "queue-master"
    }
    annotations = {
      "prometheus.io/scrape" = "true"
    }
  }

  spec {
    port {
      port        = 8080
      target_port = 8080
    }

    selector = {
      name = "queue-master"
    }
  }
}
