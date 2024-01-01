provider "kubernetes" {
  host = var.host
  client_certificate = var.client_certificate
  client_key = var.client_key
  cluster_ca_certificate = var.cluster_ca_certificate
}

resource "kubernetes_namespace" "sock_shop" {
  metadata {
    name = "sock-shop"
  }
}