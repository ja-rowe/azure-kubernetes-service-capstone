# Credentials come from a kubeconfig prepared by the caller: for deployments, the environment
# identity's Entra login (kubelogin), which may act only inside its own namespace. The namespace
# itself is created and access-controlled by the platform/ root; deployments only use it.
provider "kubernetes" {
  config_path = var.kubeconfig
}
