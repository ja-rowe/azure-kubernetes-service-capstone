variable "environment" {
  description = "dev, staging or prod"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging or prod."
  }
}

variable "kubeconfig" {
  description = "Path to a kubeconfig signed in as the environment's identity (Entra ID, kubelogin)"
  type        = string
  default     = "~/.kube/config"
}

# Image reference per service. Deployed by digest (registry/repo@sha256:...) so an environment
# runs exactly the bytes that were tested and promoted; the public Docker Hub images are used
# for services that have not been built into ACR yet.
variable "images" {
  description = "Image reference for each service"
  type        = map(string)

  validation {
    condition = alltrue([
      for k in ["carts", "catalogue", "catalogue-db", "orders", "payment", "queue-master", "shipping", "user", "user-db", "front-end"] :
      contains(keys(var.images), k)
    ])
    error_message = "images must contain carts, catalogue, catalogue-db, orders, payment, queue-master, shipping, user, user-db and front-end."
  }
}
