resource "kubernetes_deployment" "catalogue_db" {
  metadata {
    name      = "catalogue-db"
    namespace = kubernetes_namespace.sock_shop.metadata.0.name
    labels = {
      name = "catalogue-db"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        name = "catalogue-db"
      }
    }

    template {
      metadata {
        labels = {
          name = "catalogue-db"
        }
      }

      spec {
        container {
          name  = "catalogue-db"
          image = var.CATALOGUE_DB_IMG
        ## fetch from keyvault
          env {
            name  = "MYSQL_ROOT_PASSWORD"
            value = "fake_password"
          }

          env {
            name  = "MYSQL_DATABASE"
            value = "socksdb"
          }

          port {
            name           = "mysql"
            container_port = 3306
          }
        }

        node_selector = {
          "beta.kubernetes.io/os" = "linux"
        }
      }
    }
  }
}

resource "kubernetes_service" "catalogue_db" {
  metadata {
    name      = "catalogue-db"
    namespace = kubernetes_namespace.sock_shop.metadata.0.name
    labels = {
      name = "catalogue-db"
    }
  }

  spec {
    port {
      port        = 3306
      target_port = 3306
    }

    selector = {
      name = "catalogue-db"
    }
  }
}
