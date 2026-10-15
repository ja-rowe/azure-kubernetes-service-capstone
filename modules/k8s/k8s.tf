provider "kubernetes" {
  host = var.host
  client_certificate = var.client_certificate
  client_key = var.client_key
  cluster_ca_certificate = var.cluster_ca_certificate
}

# The namespace is created and access-controlled by the platform/ root; deployments only use it.
data "kubernetes_namespace" "sock_shop" {
  metadata {
    name = var.namespace
  }
}
