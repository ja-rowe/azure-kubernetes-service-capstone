resource "kubernetes_deployment" "rabbitmq" {
  metadata {
    name      = "rabbitmq"
    namespace = kubernetes_namespace.sock_shop.metadata.0.name
    labels = {
      name = "rabbitmq"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        name = "rabbitmq"
      }
    }

    template {
      metadata {
        labels = {
          name = "rabbitmq"
        }
        annotations = {
          "prometheus.io/scrape" = "false"
        }
      }

      spec {
        container {
          name  = "rabbitmq"
          image = "rabbitmq:3.6.8-management"
          port {
            container_port = 15672
            name           = "management"
          }

          port {
            container_port = 5672
            name           = "rabbitmq"
          }

          security_context {
            capabilities {
              drop = ["all"]
              add  = ["CHOWN", "SETGID", "SETUID", "DAC_OVERRIDE"]
            }

            read_only_root_filesystem = true
          }
        }

        container {
          name  = "rabbitmq-exporter"
          image = "kbudde/rabbitmq-exporter"

          port {
            container_port = 9090
            name           = "exporter"
          }
        }

        node_selector = {
          "beta.kubernetes.io/os" = "linux"
        }
      }
    }
  }
}

resource "kubernetes_service" "rabbitmq" {
  metadata {
    name      = "rabbitmq"
    namespace = kubernetes_namespace.sock_shop.metadata.0.name
    labels = {
      name = "rabbitmq"
    }
    annotations = {
      "prometheus.io/scrape" = "true"
      "prometheus.io/port"   = "9090"
    }
  }

  spec {
    port {
      port        = 5672
      target_port = 5672
      name        = "rabbitmq"
    }

    port {
      port        = 9090
      target_port = "exporter"
      name        = "exporter"
      protocol    = "TCP"
    }

    selector = {
      name = "rabbitmq"
    }
  }
}
