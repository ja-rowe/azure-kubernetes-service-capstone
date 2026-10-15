variable "host" {

}

variable "client_certificate" {

}

variable "client_key" {

}

variable "cluster_ca_certificate" {

}

variable "CARTS_IMG" {
}

variable "CATALOGUE_IMG" {
}

variable "CATALOGUE_DB_IMG" {
}

variable "ORDERS_IMG" {
}

variable "PAYMENT_IMG" {
}

variable "QUEUE_MASTER_IMG" {
}

variable "SHIPPING_IMG" {
}

variable "USER_IMG" {
}

variable "USER_DB_IMG" {
}

variable "FRONTEND_IMG" {
}

variable "namespace" {
  description = "Kubernetes namespace the Sock Shop is deployed into"
  default     = "sock-shop"
}

variable "replicas" {
  description = "Replicas of each stateless service (databases and the message broker always run one)"
  type        = number
  default     = 1
}

variable "key_vault_name" {
  description = "The environment's Key Vault"
  type        = string
}

variable "tenant_id" {
  type = string
}

variable "workload_identity_client_id" {
  description = "Client id of the environment's managed identity used by pods to read the Key Vault"
  type        = string
}

